# Runbook del VPS `isthmus-n8n` (5.78.214.136) — Brief 01

<!-- Brief 01 — 02-oct-2026. Operación diaria del VPS que aloja mp-app, Cotizador, Max Motors, n8n y Gotenberg. -->

## 1. Acceso

- **SSH:** `ssh deploy@5.78.214.136` con la llave de Gianclaudio (`gianj@GLoPolito`). Hardening en dos fases, drop-in `/etc/ssh/sshd_config.d/00-hardening.conf` (fuente: `ops/ssh/00-hardening.conf`; se lee antes que `50-cloud-init.conf` y gana):
  - **Fase 1 — aplicada el 02-oct-2026 17:42 UTC (Gianclaudio; `sshd -t` + `systemctl reload ssh`):** `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin prohibit-password`, `MaxAuthTries 4`, `LoginGraceTime 30`, `X11Forwarding no`. Verificado con `sshd -T` (los siete valores) y desde fuera: root sin llave → `Permission denied (publickey)`; root con llave y `deploy` → entran. Nadie entra con contraseña; `root` **sigue entrando por llave** porque Cotizador y Max Motors aún se operan como root.
  - **Fase 2 (pendiente):** `PermitRootLogin no` + `AllowUsers deploy`, cuando `deploy` sea dueño y operador de `/opt/cotizador-isthmus` y `/home/maxmotors` (plan del Brief 01, Task 3b). Desde entonces root solo por `sudo -i` desde `deploy` o por consola Hetzner.
  - Verificar lo vigente: `sudo sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|allowusers) '`.
- **sudo:** `deploy` tiene la allowlist `MP_OPS` sin contraseña (reload/estado de Caddy, backups, journal, estados de ufw/fail2ban/iptables, `restic snapshots`) y sudo completo **con contraseña** para todo lo demás. La contraseña de `deploy` solo sirve para `sudo`, nunca para SSH; vive en el gestor de contraseñas de Gianclaudio. Claude Code (no interactivo) solo puede usar la allowlist.
- **Recuperación si se pierde la llave:** Hetzner Cloud Console → servidor → *Console* (acceso como root por consola, no por SSH). Desde ahí: `nano /etc/ssh/sshd_config.d/00-hardening.conf` o añadir una llave a `/home/deploy/.ssh/authorized_keys`.
- **Claude Code** corre como `deploy`; su configuración y la memoria del proyecto están en `/home/deploy/.claude` (copiadas de root el 02-oct-2026).

## 2. Servicios

| Puerto host | Contenedor | Compose | Dominio (Caddy) | Administra |
|---|---|---|---|---|
| 127.0.0.1:3003 | `mp-app` (producción, Brief 02+) | `/opt/mp-app/docker-compose.yml` | `mp.isthmuscap.com` | Claude Code / Gianclaudio |
| 127.0.0.1:3013 | `mp-app-staging` | `/opt/mp-app/docker-compose.yml` | `staging-mp.isthmuscap.com` | Claude Code / Gianclaudio |
| 3001 | `cotizador-app` | `/opt/cotizador-isthmus/docker-compose.yml` | `cotizador.isthmuscap.com` | Gianclaudio |
| 3002 | `maxmotors-app` | `/home/maxmotors/docker-compose.yml` | `precios.maxmotorspa.com` | Gianclaudio |
| 5678 | `n8n-n8n-1` (+ `n8n-postgres-1`) | `/opt/n8n/docker-compose.yml` | `automation.isthmuscap.com` | **Solo Gianclaudio** (Claude Code nunca toca n8n en el VPS) |
| 3000 | `gotenberg` | sin compose (contenedor suelto) | interno (PDF y capturas) | Gianclaudio |

Caddy corre en el host (systemd, usuario `caddy`), config en `/etc/caddy/Caddyfile`. Los puertos 3000/3001/3002/5678 los publica Docker en `0.0.0.0`, pero la regla `DOCKER-USER` (sección 5) los hace inalcanzables desde Internet; solo Caddy llega por loopback.

Verificación rápida de todo: `/opt/mp-app/scripts/ops/check-services.sh <etiqueta>` (log en `/var/log/mp-ops/check-services.log`).

## 3. Desplegar mp-app

```bash
cd /opt/mp-app && git pull
docker compose up -d --build mp-app-staging          # staging (127.0.0.1:3013, /etc/mp-app/staging.env)
docker compose logs -f --tail 100 mp-app-staging
docker compose up -d --build mp-app                  # producción (127.0.0.1:3003) — solo con aprobación
```

Rollback: antes de construir, etiquetar la imagen vigente (`docker tag mp-app:staging mp-app:staging-prev`); para volver: `docker tag mp-app:staging-prev mp-app:staging && docker compose up -d --no-build mp-app-staging`.
Secretos: `/etc/mp-app/staging.env` y `/etc/mp-app/production.env` (640 `root:deploy`); editar con `sudo nano`, luego `docker compose up -d <servicio>` para que el contenedor los relea. `BG_AMBIENTE=qa` siempre, salvo aprobación explícita de Gianclaudio y Diego para `prod`.

## 4. Caddy

1. Respaldar antes: `sudo cp -a /etc/caddy/Caddyfile /root/backups/Caddyfile.$(date -u +%Y%m%dT%H%M%SZ)`. Editar `/etc/caddy/Caddyfile` (`sudo nano`). El bloque de mp-app es `ops/caddy/Caddyfile.mp.snippet` del repo, **aplicado el 03-oct-2026 (v3)**; el bloque del servidor y el snippet del repo deben ser idénticos: `awk '/^# ===== mp-app/{f=1} f' /etc/caddy/Caddyfile | diff - ops/caddy/Caddyfile.mp.snippet`.
2. Los archivos de log del bloque deben pertenecer a `caddy`: `sudo chown caddy:caddy /var/log/caddy/mp.log /var/log/caddy/staging-mp.log`. Un `caddy validate` ejecutado como root los crea como `root:root 600` y la recarga falla con *permission denied* (ocurrió el 03-oct-2026; la reversa automática restauró el Caddyfile sin corte).
3. `sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`
4. `sudo systemctl reload caddy` (sin corte). Reversa: `sudo cp -a /root/backups/Caddyfile.<respaldo> /etc/caddy/Caddyfile && sudo systemctl reload caddy`, luego `scripts/ops/check-services.sh`.
5. Logs: `/var/log/caddy/staging-mp.log`, `/var/log/caddy/mp.log`, `sudo journalctl -u caddy -n 50`.

Página de espera (503 con marca) en `/var/www/mp-placeholder/` (fuente: `ops/caddy/placeholder/`); Caddy la sirve cuando el contenedor no responde. Dentro de `handle_errors` Caddy conserva el código del error salvo que el manejador fije otro: el logo se sirve con `file_server { status 200 }` y la página con `status 503`; las cabeceras de seguridad se importan también dentro del manejador de errores (v3 del snippet, 03-oct-2026).

## 5. Firewall y SSH

- `sudo ufw status` → 22, 80, 443 permitidos; resto denegado.
- Regla Docker: `sudo iptables -S DOCKER-USER` debe mostrar `-A DOCKER-USER -i eth0 -p tcp -m conntrack --ctstate NEW -m multiport --dports 3000,3001,3002,5678 -j DROP`. Persistida en `/etc/ufw/after.rules` (bloque `mp-app DOCKER-USER`), copia previa en `/root/backups/after.rules.pre-brief01`. Reversa: `sudo /opt/mp-app/ops/ufw/docker-user-rollback.sh`.
- **Nunca `ufw reload` ni `ufw disable` con contenedores arriba**: vacían las cadenas de Docker y tumban los servicios publicados hasta reiniciar Docker.
- fail2ban: `sudo fail2ban-client status sshd`; desbloquear una IP: `sudo fail2ban-client set sshd unbanip <ip>`. Config en `/etc/fail2ban/jail.local` (5 intentos / 10 min → 1 h).
- Comprobación externa de puertos (sin instalar nada): `https://check-host.net/check-tcp?host=5.78.214.136:5678` debe dar *Connection timed out* en todos los nodos.

## 6. Backups (Hetzner y restic)

- **Backups de Hetzner:** el VPS tiene los Backups de Hetzner activos desde el inicio (copia del servidor entero, gestionada desde el panel de Hetzner; cuestan ~20 % del precio del servidor). **Cubren el escenario de pérdida del servidor**; por eso el Storage Box externo queda **aplazado sin fecha** (decisión de Gianclaudio, 03-oct-2026) y restic sigue en el repositorio local del propio VPS. **No hace falta un snapshot manual antes de una ventana de mantenimiento.** Para cambios en una base de datos (por ejemplo la rotación de Postgres de n8n, hoy aplazada) se sigue haciendo el dump lógico previo, porque la copia del servidor no es consistente a nivel de base de datos. restic (abajo) es para restauraciones granulares: un archivo, un volumen o un dump, sin revertir el disco completo.
- **Qué:** volúmenes Docker con nombre (tar en caliente), configuración del host (`/etc/caddy`, `/etc/ssh/sshd_config.d`, `/etc/sudoers.d`, `/etc/fail2ban/jail.local`, `/etc/ufw/after.rules`, unidades `mp-*`), `/opt/mp-app`, `/etc/mp-app`, `/etc/mp-backup`, `/root/backups`, compose de Cotizador y Max Motors. Con `MP_BACKUP_INCLUDE_N8N=1`: además volúmenes `n8n_*`, `pg_dumpall` del Postgres de n8n y la carpeta del compose de n8n.
- **Cuándo:** `mp-backup.timer` diario 08:00 UTC (03:00 Panamá). Retención 14 días (`--keep-daily 14`). Cifrado y deduplicado por restic.
- **Dónde:** `RESTIC_REPOSITORY` en `/etc/mp-backup/restic.env` (600 root). Es local (`/var/backups/restic-local`). El Storage Box de Hetzner queda **aplazado sin fecha** (03-oct-2026): los Backups de Hetzner cubren la pérdida del servidor. Si algún día se contrata, se cambia a `sftp:uXXXXXX@uXXXXXX.your-storagebox.de:/restic-isthmus`, se añade a `/root/.ssh/config` un bloque `Host uXXXXXX.your-storagebox.de` / `Port 23` / `IdentityFile /root/.ssh/id_ed25519_storagebox`, y se corre `restic init` una vez. La llave pública está en `/root/.ssh/id_ed25519_storagebox.pub`.
- **Contraseña del repositorio:** `RESTIC_PASSWORD` en `restic.env`; copia en el gestor de contraseñas de Gianclaudio (`sudo grep RESTIC_PASSWORD /etc/mp-backup/restic.env`). Sin ella los backups son irrecuperables.
- **n8n (decisión D3):** `MP_BACKUP_INCLUDE_N8N` empieza en `0`. Gianclaudio ejecuta la primera corrida completa con `sudo MP_BACKUP_INCLUDE_N8N_OVERRIDE=1 /usr/local/bin/mp-backup.sh`, prueba la restauración de n8n (abajo) y después pone `MP_BACKUP_INCLUDE_N8N=1` en `restic.env`. Claude Code no ejecuta ni inspecciona esa parte.

Comandos (como `deploy`, con `sudo`):

```bash
sudo systemctl status mp-backup.timer                    # próxima ejecución
sudo systemctl start mp-backup.service                    # corrida manual
sudo journalctl -u mp-backup.service -n 30                # log
sudo cat /var/lib/mp-backup/last-success                  # último éxito (lo lee /api/health)
sudo bash -c 'set -a; . /etc/mp-backup/restic.env; restic snapshots'
sudo bash -c 'set -a; . /etc/mp-backup/restic.env; restic restore latest --target /tmp/r --include /etc/caddy/Caddyfile'
sudo /usr/local/bin/mp-restore-test.sh                    # prueba mensual: volumen de prueba + Caddyfile
```

Restaurar un volumen: restaurar `vol-<nombre>.tgz` del snapshot a `/tmp/r`, parar el contenedor, `docker run --rm -v <vol>:/data -v /tmp/r/var/backups/mp-stage:/src:ro alpine:3.20 sh -c 'rm -rf /data/* && tar xzf /src/vol-<nombre>.tgz -C /data'`, arrancar el contenedor.
Restaurar n8n (**Gianclaudio**): restaurar `n8n-pg_dumpall.sql.gz` del snapshot, `gunzip -c ... | docker exec -i n8n-postgres-1 psql -U n8n -d postgres`, y el volumen `n8n_n8n_data` como arriba; luego `docker compose -f /opt/n8n/docker-compose.yml up -d`.
Alertas: si una corrida falla, `mp-alert@backup.service` escribe en `/var/lib/mp-health/alerts.log` y en el journal (`journalctl -t mp-alert`). Supabase: los backups automáticos del proyecto `isthmus-mp` (plan Pro) se verifican en el dashboard → *Database → Backups* cuando el proyecto exista.

## 7. Actualizaciones y reinicio

- `unattended-upgrades` aplica solo parches de seguridad. Lo demás: `sudo apt-get update && sudo apt-get upgrade`. **`docker-ce` / `containerd.io` reinician el daemon de Docker y todos los contenedores**: hacerlo solo en ventana (ver `docs/ops/VENTANA_MANTENIMIENTO_FINDE.md`).
- `ls /var/run/reboot-required` indica si hace falta reiniciar. Procedimiento completo (pre-chequeo, upgrade, reinicio, post-reboot y verificaciones) en `docs/ops/VENTANA_MANTENIMIENTO_FINDE.md`; la rotación de Postgres de n8n quedó fuera de la ventana, aplazada sin fecha (`docs/ops/ROTACION_N8N_POSTGRES.md`, R40); versión corta del reinicio: `check-services.sh pre-reboot` → `sudo systemctl reboot` → 2 min → `check-services.sh post-reboot` → `sudo iptables -S DOCKER-USER`.

## 8. Salud y alertas

- `/api/health`: contrato en `docs/ops/HEALTH.md` (ruta en Brief 02).
- Sonda externa: `mp-healthcheck.timer` (cada 5 min; `sudo systemctl enable --now mp-healthcheck.timer` en el Brief 02). Estado en `/var/lib/mp-health/` (`last-code`, `failures`, `last-success`).
- Alertas: `/var/lib/mp-health/alerts.log` y `journalctl -t mp-alert`. Canal WhatsApp/correo: Brief 13.
- Unidades fallidas: `systemctl --failed`.

## 9. Secretos

| Qué | Dónde | Permisos |
|---|---|---|
| Variables de mp-app (WhatsApp, Supabase, N8N, Zoho, LoanDisk…) | `/etc/mp-app/staging.env`, `/etc/mp-app/production.env` | 640 `root:deploy` |
| Repositorio restic | `/etc/mp-backup/restic.env` | 600 root |
| Llave SFTP del Storage Box (sin uso: Storage Box aplazado sin fecha) | `/root/.ssh/id_ed25519_storagebox` | 600 root |
| Token de GitHub (git push) | `/home/deploy/.git-credentials` | 600 deploy |
| Credenciales de N8N y Zoho | dentro de n8n (credenciales) | Gianclaudio |

Nunca en el repo, briefs, logs ni chat. Rotación del token de WhatsApp: Brief 04. Rotación de la contraseña de Postgres de n8n: aplazada sin fecha (R40 aceptado temporalmente, 03-oct-2026); procedimiento en `docs/ops/ROTACION_N8N_POSTGRES.md`.

## 10. Escalamiento

1. **Gianclaudio** (infra, n8n, DNS en GoDaddy, Hetzner, GitHub).
2. **Diego Méndez** (decisiones de negocio, aprobación de producción y de `BG_AMBIENTE=prod`).
3. **Gisela** (LoanDisk, operación de préstamos).
4. Hetzner Support (hardware/red del VPS), GoDaddy (DNS).
