# Ventana de mantenimiento del fin de semana — checklist único (Brief 01)

<!-- Brief 01 — 02-oct-2026. Fusiona VENTANA_REINICIO_2026-10-02.md y ROTACION_N8N_POSTGRES.md (ambos retirados). Claude Code no ejecuta ningún paso ni abre archivos de n8n. -->

**Orden:** dump previo → rotación de Postgres de n8n → `apt upgrade` (incluye `docker-ce`) → reinicio de kernel → post-reboot → verificación externa de puertos (check-host.net) → verificación HTTPS de n8n, Cotizador y Max Motors.

**Quién:** Gianclaudio, desde su terminal, como `root` (o `deploy` con `sudo -i`). Los comandos van en tu terminal, nunca en el chat.
**Fecha y hora:** fin de semana, la fijas tú. Evita 08:00 UTC ± 10 min (03:00 Panamá), cuando corre `mp-backup.timer`.
**Corte esperado:** n8n ~1 min (paso 2), todos los contenedores ~1 min (paso 3) y todo el VPS 2–3 min (paso 4). Cotizador, Max Motors, n8n y Gotenberg quedan sin servicio en esos tramos.
**Snapshot manual:** no hace falta. El VPS tiene Backups de Hetzner activos desde el inicio (ver `RUNBOOK_VPS.md` §6). El dump del paso 1 se hace igual porque un backup del servidor entero no es consistente a nivel de base de datos y la reversa de la rotación depende de él.

**Motivo de la rotación.** El 02-oct-2026 la contraseña vigente del Postgres de n8n apareció en la salida de una herramienta de la sesión de Claude Code (lectura indebida del compose de n8n). No se copió a ningún archivo, documento ni memoria, pero se trata como expuesta (R40). En esa misma salida se mostraron `AUTOPAL_COMPANY` y `AUTOPAL_USER` (no `AUTOPAL_KEY`, que quedó enmascarada): evalúa si son secretos de esa integración y, si lo son, rótalos con el proveedor. `N8N_ENCRYPTION_KEY` y `N8N_BASIC_AUTH_PASSWORD` quedaron enmascaradas y no requieren rotación por este motivo.

## 0. Antes de empezar (5 min)

- [ ] **Restart policies** (las verificas tú; Claude Code no inspecciona los contenedores de n8n). Ninguno puede estar en `no`:

```bash
docker inspect -f '{{.Name}} -> {{.HostConfig.RestartPolicy.Name}}' $(docker ps -q)
```

Al 02-oct, `cotizador-app` y `maxmotors-app` están en `unless-stopped` y `gotenberg` en `always` (verificado); `n8n-n8n-1` y `n8n-postgres-1` los confirmas tú. Si alguno está en `no`: `docker update --restart unless-stopped <nombre>`.

- [ ] **n8n sin ejecuciones en curso:** UI → *Executions* → ninguna en *Running*.
- [ ] **Línea base y regla de firewall:**

```bash
/opt/mp-app/scripts/ops/check-services.sh pre-ventana; echo rc=$?      # rc=0
iptables -S DOCKER-USER | grep -c DROP                                  # 1
uname -r; ls /var/run/reboot-required                                   # kernel actual y reinicio pendiente
```

- [ ] **Segunda terminal SSH abierta** durante toda la ventana. Con la fase 1 del hardening, `root` sigue entrando por llave; tras la fase 2 (`PermitRootLogin no`) solo `deploy` + `sudo -i`. El `apt upgrade` puede actualizar `openssh-server`; la sesión abierta sobrevive, pero la segunda es el seguro.

## 1. Dump previo (2 min)

El dump queda en `/root/backups`, que el backup diario también respalda.

```bash
docker exec n8n-postgres-1 pg_dump -U n8n -Fc n8n > /root/backups/n8n-pre-rotacion-$(date +%F).dump
ls -lh /root/backups/n8n-pre-rotacion-$(date +%F).dump
cp -a /opt/n8n/docker-compose.yml /root/backups/docker-compose.n8n.pre-rotacion-$(date +%F).yml
```

- [ ] Dump con tamaño razonable (comparable a los de ago/sep en `/root/backups`) y copia del compose hecha.

## 2. Rotación de la contraseña de Postgres de n8n (5 min)

- [ ] **2.1 Generar la nueva** (32 caracteres alfanuméricos, para no romper el parseo del compose ni URLs). Guárdala en tu gestor **antes** de seguir:

```bash
NEWPW="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-32)"; echo "$NEWPW"
```

- [ ] **2.2 Actualizar el compose.** Dos valores: `POSTGRES_PASSWORD` (solo se usa al inicializar el volumen; por coherencia) y `DB_POSTGRESDB_PASSWORD` (la que usa n8n):

```bash
sed -i -E "s|^(\s*POSTGRES_PASSWORD:\s*).*|\1${NEWPW}|; s|^(\s*- DB_POSTGRESDB_PASSWORD=).*|\1${NEWPW}|" /opt/n8n/docker-compose.yml
grep -nE "POSTGRES_PASSWORD|DB_POSTGRESDB_PASSWORD" /opt/n8n/docker-compose.yml
```

Esperado: dos líneas que terminan en la nueva contraseña. Si el formato difiere del que espera el `sed` (por ejemplo `POSTGRES_PASSWORD=` en lista en vez de `POSTGRES_PASSWORD:` en mapa), edita a mano con `nano` y repite el `grep`.

- [ ] **2.3 Cambiarla en Postgres.** La conexión local por socket no pide contraseña (`trust` de la imagen oficial), así que no necesitas la anterior. Aplica a conexiones nuevas; n8n sigue con su pool hasta el 2.4, por eso van seguidos:

```bash
docker exec -i n8n-postgres-1 psql -U n8n -d n8n -v ON_ERROR_STOP=1 -c "ALTER USER n8n WITH PASSWORD '${NEWPW}';"
```

Esperado: `ALTER ROLE`.

- [ ] **2.4 Recrear solo n8n** (`--no-deps` no toca `postgres`; ~30–60 s):

```bash
docker compose -f /opt/n8n/docker-compose.yml up -d --no-deps --force-recreate n8n
```

- [ ] **2.5 Verificar:**

```bash
docker compose -f /opt/n8n/docker-compose.yml ps
docker logs --since 3m n8n-n8n-1 2>&1 | grep -iE "error|ECONNREFUSED|password authentication failed" || echo "sin errores de conexión en el log"
curl -s -o /dev/null -w "healthz %{http_code}\n" https://automation.isthmuscap.com/healthz
docker exec -e PGPASSWORD="$NEWPW" -i n8n-postgres-1 psql -h 127.0.0.1 -U n8n -d n8n -tAc "select 1"
```

Esperado: ambos contenedores `Up`, `sin errores de conexión en el log`, `healthz 200` y `1` (la nueva contraseña autentica por red, no por socket). En la UI: abrir *Executions* y un workflow cualquiera (lectura real de la base). Opcional: pídeme confirmar con `search_workflows` (solo lectura, por el MCP).

- [ ] **2.6 Limpiar:** `unset NEWPW; history -c`
- [ ] **2.7 (opcional) Cerrar la deriva de `postgres`.** Su contenedor sigue con la variable antigua en el entorno (no afecta: la contraseña real ya cambió). El reinicio del paso 4 **no** lo corrige, porque restaura el contenedor existente sin recrearlo. Si quieres cerrarlo ahora, `docker compose -f /opt/n8n/docker-compose.yml up -d` recrea `postgres` (datos en volumen, sin pérdida) y n8n por `depends_on` (~1 min); repite 2.5. Si no, se cierra en el próximo `up -d`.

**No avances al paso 3 si 2.5 no dio `healthz 200` y `1`.** Si falla, ver Reversa.

## 3. Actualización de paquetes, incluido `docker-ce` (10 min)

`docker-ce`, `containerd.io` y los plugins de Compose reinician el daemon de Docker y con él todos los contenedores (~1 min). Al 02-oct hay 26 paquetes pendientes (kernel `7.0.0-34` ya instalado).

```bash
/opt/mp-app/scripts/ops/check-services.sh pre-upgrade; echo rc=$?
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade && apt-get -y autoremove --purge
docker ps --format '{{.Names}} {{.Status}}'          # los 5 contenedores deben volver solos (restart policies)
/opt/mp-app/scripts/ops/check-services.sh post-upgrade; echo rc=$?
iptables -S DOCKER-USER | grep -c DROP               # debe seguir en 1
apt list --upgradable 2>/dev/null | wc -l            # 1 (solo la cabecera)
cat /var/run/reboot-required.pkgs
```

- [ ] `post-upgrade` con `rc=0` y 5 contenedores `Up`; `DOCKER-USER` en `1`; sin paquetes pendientes.
- [ ] Si la regla `DOCKER-USER` no está: `iptables -I DOCKER-USER 1 -i eth0 -p tcp -m conntrack --ctstate NEW -m multiport --dports 3000,3001,3002,5678 -j DROP`. **Nunca `ufw reload` con contenedores arriba.**
- [ ] Si un contenedor no volvió: `docker start <nombre>`; n8n: `docker compose -f /opt/n8n/docker-compose.yml up -d`.

## 4. Reinicio de kernel (3 min)

```bash
/opt/mp-app/scripts/ops/check-services.sh pre-reboot && systemctl reboot
```

Espera ~2 minutos y reconecta.

## 5. Post-reboot (5 min)

```bash
uptime; uname -r                                     # 7.0.0-34-generic o superior
ls /var/run/reboot-required 2>&1                     # No such file or directory
/opt/mp-app/scripts/ops/check-services.sh post-reboot; echo rc=$?    # rc=0 y 5 contenedores Up
iptables -S DOCKER-USER | grep -c DROP               # 1 (regla persistida desde /etc/ufw/after.rules)
systemctl is-active caddy fail2ban docker ufw mp-backup.timer        # active ×5
fail2ban-client status sshd | head -3
ufw status | head -1                                 # Status: active
docker compose -f /opt/n8n/docker-compose.yml ps     # n8n y postgres Up
```

- [ ] Todo coincide. Si la regla `DOCKER-USER` no está tras el reinicio, aplicar el comando del paso 3 y avisarme para revisar `/etc/ufw/after.rules`.

## 6. Verificación externa de puertos (check-host.net, 5 min)

Desde tu navegador, no desde el VPS (la IP del VPS no es "externa"). Revisa que cada comprobación responda en **varios nodos** (≥ 8):

| Puerto | URL | Esperado |
|---|---|---|
| 5678 (n8n) | `https://check-host.net/check-tcp?host=5.78.214.136:5678` | *Connection timed out* en todos |
| 3000 (Gotenberg) | `https://check-host.net/check-tcp?host=5.78.214.136:3000` | *Connection timed out* en todos |
| 3001 (Cotizador) | `https://check-host.net/check-tcp?host=5.78.214.136:3001` | *Connection timed out* en todos |
| 3002 (Max Motors) | `https://check-host.net/check-tcp?host=5.78.214.136:3002` | *Connection timed out* en todos |
| 443 | `https://check-host.net/check-tcp?host=5.78.214.136:443` | Conecta |
| 80 | `https://check-host.net/check-tcp?host=5.78.214.136:80` | Conecta |
| 22 | `https://check-host.net/check-tcp?host=5.78.214.136:22` | Conecta |

- [ ] Los cuatro puertos de Docker en timeout y 22/80/443 abiertos. Si un puerto de Docker responde, aplicar la regla del paso 3 y repetir.

## 7. Verificación por HTTPS de n8n, Cotizador y Max Motors (5 min)

Desde tu laptop (o con `https://check-host.net/check-http?host=<URL>`):

```bash
for u in https://automation.isthmuscap.com/healthz https://cotizador.isthmuscap.com/ https://precios.maxmotorspa.com/; do
  curl -s -o /dev/null -m 15 -w "$u -> %{http_code}\n" "$u"; done
```

- [ ] n8n `200`; Cotizador `200/301/302/307/308`; Max Motors `200/301/302/307/308` (línea base del 02-oct: 307 y 307).
- [ ] Prueba funcional, no solo código HTTP: abrir el Cotizador y Max Motors en el navegador y cargar una cotización; en n8n, *Executions* debe mostrar actividad normal y los webhooks de las ejecuciones nuevas deben llegar.
- [ ] Pega en el chat la salida de `post-reboot`, el conteo de `DOCKER-USER` y las líneas de este paso (sin la contraseña). Con eso cierro el criterio de aceptación 2 del Brief 01 y lo anoto en el inventario.

## 8. Registro

Anota en `docs/INVENTARIO_ACTUAL.md` §0.1 (bitácora v1): fecha, "rotación de contraseña Postgres n8n", "actualización de paquetes" y "reinicio de kernel", quién lo ejecutó y el resultado de 2.5, `post-upgrade` y `post-reboot`. Esa anotación la hago yo si me pegas las salidas. Marca R40 como cerrado en `docs/RIESGOS.md` cuando 2.5 haya pasado.

## Si algo falla

| Síntoma | Acción |
|---|---|
| n8n no levanta tras el paso 2 | **Reversa** (abajo). |
| Un contenedor no está `Up` | `docker start <nombre>`. Cotizador: `docker compose -f /opt/cotizador-isthmus/docker-compose.yml up -d`; Max Motors: `docker compose -f /home/maxmotors/docker-compose.yml up -d`; n8n: `docker compose -f /opt/n8n/docker-compose.yml up -d`. |
| `DOCKER-USER` sin la regla DROP | `iptables -I DOCKER-USER 1 -i eth0 -p tcp -m conntrack --ctstate NEW -m multiport --dports 3000,3001,3002,5678 -j DROP` y avísame. **Nunca `ufw reload` con contenedores arriba.** |
| Caddy no responde en 443 | `systemctl status caddy`; `journalctl -u caddy -n 50`; `systemctl restart caddy`. |
| Un sitio da 502 | El contenedor detrás aún arranca; repetir `check-services.sh` en 1 min. |
| No entra por SSH | Consola Hetzner (Cloud Console → *Console*) con root; revisar `systemctl status ssh` y `/etc/ssh/sshd_config.d/`. |
| El kernel nuevo no arranca | El anterior sigue instalado: en GRUB (consola Hetzner) elegir `7.0.0-31`. |
| Daño que no se arregla con lo anterior | Restaurar el backup del servidor desde el panel de Hetzner (Backups) es el último recurso: revierte **todo** el disco al punto del backup. |

### Reversa de la rotación de Postgres

```bash
cp -a /root/backups/docker-compose.n8n.pre-rotacion-$(date +%F).yml /opt/n8n/docker-compose.yml
docker exec -i n8n-postgres-1 psql -U n8n -d n8n -c "ALTER USER n8n WITH PASSWORD '<contraseña anterior, de tu gestor>';"
docker compose -f /opt/n8n/docker-compose.yml up -d --no-deps --force-recreate n8n
```

Y repetir 2.5. Si el problema es otro (por ejemplo, la base no arranca), el último recurso es restaurar el dump del paso 1: `docker exec -i n8n-postgres-1 pg_restore -U n8n -d n8n --clean --if-exists < /root/backups/n8n-pre-rotacion-<fecha>.dump`.
