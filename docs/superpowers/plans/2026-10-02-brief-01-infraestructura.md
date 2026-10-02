# Brief 01 — Infraestructura y hardening del VPS: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dejar el VPS endurecido (usuario `deploy`, SSH sin root ni contraseñas, fail2ban, firewall real sobre Docker), con backups diarios cifrados y restauración probada, `staging-mp.isthmuscap.com` y `mp.isthmuscap.com` sirviendo por TLS con cabeceras de seguridad, el `docker-compose.yml` de `mp-app` con sus `.env` fuera del repo, la sonda de salud preparada, el runbook escrito y las 5 pantallas clave en HTML con tokens FIC listas para revisarlas en celular.

**Architecture:** Todo es configuración del host (usuarios, sshd, ufw, fail2ban, Caddy, systemd timers) más tres scripts bash de operación (`mp-backup.sh`, `mp-restore-test.sh`, `mp-healthcheck.sh`) y archivos de proyecto (`docker-compose.yml`, `ops/`, `docs/ops/`, `docs/design/pantallas/`). No hay código de aplicación todavía (lo crea el Brief 02): `/api/health` queda definido por contrato y su sonda externa instalada pero desactivada hasta que exista la app. Ningún contenedor existente se reinicia salvo en la ventana de reinicio acordada.

**Tech Stack:** Ubuntu 26.04, OpenSSH, ufw + iptables (`DOCKER-USER`), fail2ban 1.1 (backend systemd), restic 0.18 (SFTP a Hetzner Storage Box), Caddy 2.11 (host, systemd), Docker 29 + Compose v5, systemd timers, Gotenberg (capturas), HTML/CSS estático con `styles/tokens.css`.

**Spec:** `docs/briefs/BRIEF_01_infraestructura.md` + `docs/00_PROMPT_MAESTRO.md` §2, §10, §13.9, §15, §19 + `CLAUDE.md` (Prohibido, Calidad de UI) + estado real del VPS leído el 02-oct-2026 (más abajo).

## Estado real del VPS (02-oct-2026, solo lectura)

| Punto | Hoy | Objetivo del brief |
|---|---|---|
| Acceso | `root` por llave (`gianj@GLoPolito`); `PermitRootLogin yes`; `PasswordAuthentication yes` (drop-in `50-cloud-init.conf`) | `deploy` por llave; root y contraseñas rechazados |
| Usuario `deploy` | No existe. Sudoers solo `root NOPASSWD:ALL` | Existe, grupo `docker`, sudo con allowlist sin contraseña y resto con contraseña |
| ufw | Activo: 22, 80, 443 permitidos, resto denegado | Igual, **más** bloqueo de los puertos que Docker publica saltándose ufw |
| Docker publica en `0.0.0.0` | 3000 (gotenberg), 3001 (cotizador), 3002 (maxmotors), 5678 (n8n) alcanzables desde Internet (cadena `DOCKER-USER` vacía) | Solo alcanzables por Caddy (loopback); `mp-app` se publica en `127.0.0.1` |
| fail2ban | No instalado | Activo, jail `sshd` |
| Actualizaciones | `unattended-upgrades` activo (solo seguridad); 26 paquetes pendientes; **reinicio pendiente** (kernel 7.0.0-34 instalado, corre 7.0.0-31) | Al día; reinicio en ventana coordinada |
| Caddy | Host, systemd, usuario `caddy`, 3 sitios, sin cabeceras de seguridad | + `mp.` y `staging-mp.` con TLS, HSTS, CSP base, página de espera 503 con marca |
| DNS | GoDaddy (`ns33/ns34.domaincontrol.com`); `mp.` y `staging-mp.` **sin registro A** | Registros A → `5.78.214.136` (los crea Gianclaudio) |
| Backups | Ninguno automático; `/root/backups` con copias manuales de compose y dumps SQL de n8n (ago/sep) | restic diario cifrado a almacenamiento externo, retención 14 días, restauración probada |
| Servicios que no se pueden interrumpir | `cotizador-app` :3001 (`/opt/cotizador-isthmus`), `maxmotors-app` :3002 (`/home/maxmotors`), `n8n` :5678, `gotenberg` :3000 | Verificados antes y después de cada paso disruptivo |
| Recursos | 4 vCPU, 7.6 GiB RAM, 150 GB (26 % usado), TZ UTC, interfaz `eth0` | — |

## Decisiones que necesito de Gianclaudio (defaults marcados)

| # | Decisión | Default (si dices "aprobado con los defaults") | Alternativa |
|---|---|---|---|
| D1 | Modelo de sudo de `deploy` | Allowlist **sin contraseña** para operaciones rutinarias (reload Caddy, backups, journal, estados) y **sudo completo con contraseña** para todo lo demás. Claude Code (no interactivo) solo puede usar la allowlist; tú pones la contraseña con `passwd deploy`. | Allowlist estricta y nada más; cualquier administración va por consola Hetzner como root. |
| D2 | Destino del backup externo | **Hetzner Storage Box** (BX11, ~€4/mes) por SFTP con restic (cifrado, dedup, retención). Lo creas tú en Hetzner y me das host + usuario; yo genero la llave SSH en el VPS y te doy la pública para registrarla en el Storage Box. Hasta que exista, el pipeline se valida contra un repositorio local `/var/backups/restic-local` y se cambia el destino con una línea. | Bucket S3 (Hetzner Object Storage o Backblaze B2) con claves de acceso. |
| D3 | n8n dentro del backup | **Sí**: el script (ejecutado por systemd como root, no por mí) incluye los volúmenes `n8n_n8n_data`/`n8n_postgres_data`, un `pg_dumpall` del Postgres de n8n y `/opt/n8n`. Yo escribo el script, tú lo revisas y **tú ejecutas la primera corrida y la restauración de prueba de n8n**; yo no abro ni inspecciono esos archivos (regla CLAUDE.md). Un backup del VPS sin n8n no sirve para recuperar el servidor. | Excluir n8n (`MP_BACKUP_INCLUDE_N8N=0`); sigues haciendo los dumps manuales como en ago/sep. |
| D4 | Ventana de reinicio | La fijas tú (propongo esta noche 22:00 Panamá = 03:00 UTC, con todos los contenedores en `restart: unless-stopped/always`). El reinicio lo ejecutas tú desde tu terminal con el script de verificación antes y después. | Posponer el reinicio; el resto del brief no lo necesita. |
| D5 | Bloqueo de los puertos Docker expuestos (3000/3001/3002/5678) | **Sí**, regla en `DOCKER-USER` aplicada en vivo y persistida en `/etc/ufw/after.rules`; sin reiniciar contenedores ni tocar archivos de n8n. Tú verificas desde tu laptop que `http://5.78.214.136:5678` deja de responder y que `https://automation.isthmuscap.com` sigue igual. | Dejarlo como está y anotarlo en RIESGOS. |
| D6 | `/api/health` y alerta WhatsApp | La **ruta** se implementa en el Brief 02 (scaffold); el chequeo de DB en el 03, Zoho/LoanDisk en el 05 (adaptadores). El Brief 01 deja el **contrato** (`docs/ops/HEALTH.md`), la sonda externa (`mp-healthcheck.timer`, instalada, no activada) y el hook `mp-alert.sh`. El canal de alerta (plantilla UTILITY de WhatsApp o correo desde gestionprestamos@) depende del Brief 13; hasta entonces las alertas quedan en el journal y en `/var/lib/mp-health/alerts.log`. | — (no hay app ni plantilla UTILITY todavía). |
| D7 | Host `mp.isthmuscap.com` ahora | **Sí**, junto con `staging-mp.`: Caddy emite el certificado ya y muestra la página de espera 503 con marca hasta que haya producción. | Solo `staging-mp.` ahora. |
| D8 | Revisión de las 5 pantallas en celular | Archivos en `docs/design/pantallas/` **más un Artifact privado** (URL de claude.ai) con las 5 pantallas navegables para abrir en el teléfono. | Publicarlas en `https://staging-mp.isthmuscap.com/design/` detrás de usuario/contraseña de Caddy. |
| D9 | Configuración de Claude Code al pasar a `deploy` | Copio `/root/.claude`, `/root/.claude.json` y `/root/.git-credentials` a `/home/deploy` (memoria del proyecto, plugins, sesión y acceso a GitHub). Si algo falla, vuelves a iniciar sesión en `claude` como `deploy`. | Empezar limpio como `deploy` (se pierde la memoria persistente del proyecto). |

## Checkpoints manuales (modo aprobación manual)

- **A — antes de endurecer sshd (Task 3):** Gianclaudio entra por VS Code Remote-SSH como `deploy@5.78.214.136`, confirma `docker ps` y `sudo -n systemctl status caddy`, y pone la contraseña con `sudo passwd deploy` desde una sesión root. Sin este OK no se toca sshd.
- **B — reinicio (Task 11):** ventana acordada (D4).
- **C — DNS (Task 6):** registros A creados en GoDaddy.
- **D — destino del backup (Task 7):** Storage Box creado y llave registrada (D2).
- **E — n8n en el backup (Task 7):** decisión D3 y primera corrida ejecutada por Gianclaudio.
- **F — Supabase Pro (03-oct):** verificación de backups automáticos de `isthmus-mp`; queda pendiente si el brief cierra antes.

## Global Constraints

- Ningún contenedor existente se detiene ni se reinicia fuera de la ventana B. Nunca `ufw reload`, `ufw disable` ni `systemctl restart docker` mientras corren los contenedores (vacían las reglas de Docker).
- N8N solo por el MCP y solo lectura; prohibido acceder a su base de datos, contenedor o archivos desde esta sesión. Lo que el script de backup haga con n8n lo ejecuta systemd/Gianclaudio (D3).
- Nunca imprimir ni copiar a docs/commits valores de `.env`, `restic.env`, `.git-credentials` ni llaves privadas. Los secretos viven en `/etc/mp-app/*.env` (640 `root:deploy`) y `/etc/mp-backup/restic.env` (600 root).
- `BG_AMBIENTE=qa` en todos los `.env`; `prod` solo con aprobación explícita de Gianclaudio y Diego.
- Docs en español (Panamá), commits en inglés, cada commit seguido de `git push`.
- Puertos de `mp-app`: `127.0.0.1:3003` (producción) y `127.0.0.1:3013` (staging); nunca `0.0.0.0`.
- Páginas visibles al público: sin errores técnicos, textos revisados con `design:ux-copy`; pantallas con captura 390 px y 1440 px y `design:accessibility-review` antes de cerrar (CLAUDE.md, Calidad de UI). En este VPS las capturas se hacen con Gotenberg (Playwright no tiene Chromium nativo en Ubuntu 26.04; Brief 02 lo monta en Docker).
- Orden de sshd: los drop-ins se leen antes del archivo principal y **gana el primer valor**; el drop-in de hardening se llama `00-hardening.conf` para preceder a `50-cloud-init.conf`.

## Review Focus

1. Bloqueo por SSH: si `00-hardening.conf` se aplica antes de probar el login de `deploy`, nadie entra salvo por consola Hetzner. Test: Task 3 Step 1 exige el Checkpoint A y `sshd -t` antes de `reload`; la sesión actual permanece abierta.
2. `ufw reload` vacía las cadenas de Docker y tumba los 4 servicios publicados hasta reiniciar Docker. Test: Task 4 aplica la regla con `iptables -I` en vivo y solo escribe `after.rules` para el próximo arranque; Task 11 verifica tras el reinicio que `iptables -S DOCKER-USER` conserva la regla y los servicios responden.
3. Backup que "funciona" pero no restaura: Task 7 Step 7 crea un volumen con contenido conocido, lo respalda, lo borra, lo restaura y compara SHA-256; además restaura `/etc/caddy/Caddyfile` y hace `diff`.
4. Secretos que se cuelan en el repo o en la salida: Task 5 copia los `WHATSAPP_*` con `grep` → archivo, verifica con `diff` (salida vacía) y `git status --porcelain | grep -c env` = 0 antes de cada commit; `restic.env` nunca se `cat`.
5. Página de espera que responde 200 y engaña al monitoreo: Task 6 usa `file_server { status 503 }` + `Retry-After`; test `curl -sI https://staging-mp.isthmuscap.com | head -1` → `HTTP/2 503` y el cuerpo muestra la marca.

---

### Task 1: Línea base y script de verificación de servicios

**Files:**
- Create: `scripts/ops/check-services.sh`
- Create: `/var/log/mp-ops/` (host)

**Interfaces:**
- Produces: `scripts/ops/check-services.sh [etiqueta]` → imprime código HTTP de cotizador, maxmotors, n8n (`/healthz`) y gotenberg (`/health`) más `docker ps`; sale 0 si todos responden. Lo usan las Tasks 4, 6, 11 y 12.

- [ ] **Step 1: Escribir el script**

```bash
mkdir -p /opt/mp-app/scripts/ops
cat > /opt/mp-app/scripts/ops/check-services.sh <<'EOF'
#!/usr/bin/env bash
# Verifica que los servicios existentes del VPS respondan (Brief 01). Uso: check-services.sh [etiqueta]
set -u
label="${1:-check}"; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
out="/var/log/mp-ops/check-services.log"; mkdir -p "$(dirname "$out")"
check() { # nombre url codigos_aceptados
  local code; code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$2" || echo 000)"
  printf '%s %s %-10s %s -> %s (esperado %s)\n' "$ts" "$label" "$1" "$2" "$code" "$3" | tee -a "$out"
  [[ " $3 " == *" $code "* ]]
}
rc=0
check cotizador https://cotizador.isthmuscap.com/         "200 301 302 307 308" || rc=1
check maxmotors https://precios.maxmotorspa.com/          "200 301 302 307 308" || rc=1
check n8n       https://automation.isthmuscap.com/healthz "200" || rc=1
check gotenberg http://127.0.0.1:3000/health              "200" || rc=1
docker ps --format '{{.Names}} {{.Status}}' | sed "s/^/$ts $label /" | tee -a "$out"
exit $rc
EOF
chmod +x /opt/mp-app/scripts/ops/check-services.sh
```

- [ ] **Step 2: Ejecutar la línea base**

Run: `/opt/mp-app/scripts/ops/check-services.sh baseline; echo rc=$?`
Expected: cuatro líneas con código aceptado, cinco contenedores `Up`, `rc=0`. Si n8n devuelve otro código en `/healthz`, anotar el código real y ajustar la lista aceptada (no se toca n8n).

- [ ] **Step 3: Commit**

```bash
cd /opt/mp-app && git add scripts/ops/check-services.sh && git commit -m "ops(brief-01): service baseline check script" && git push origin main
```

---

### Task 2: Usuario `deploy` (sin tocar sshd todavía)

**Files:**
- Create (host): `/home/deploy/.ssh/authorized_keys`, `/etc/sudoers.d/deploy`
- Create: `ops/sudoers.d/deploy` (copia versionada, sin secretos)

**Interfaces:**
- Produces: usuario `deploy` (grupo `docker`), dueño de `/opt/mp-app`; `Cmnd_Alias MP_OPS` que usan las Tasks 6–9.

- [ ] **Step 1: Crear el usuario y copiar la llave de Gianclaudio**

```bash
adduser --disabled-password --gecos "FIC deploy" deploy
usermod -aG docker deploy
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
install -m 600 -o deploy -g deploy /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
id deploy && cut -d' ' -f3 /home/deploy/.ssh/authorized_keys
```
Expected: `uid=1001(deploy) gid=1001(deploy) groups=1001(deploy),988(docker)` (números pueden variar) y `gianj@GLoPolito`.

- [ ] **Step 2: Sudoers (D1): allowlist sin contraseña, resto con contraseña**

```bash
mkdir -p /opt/mp-app/ops/sudoers.d
cat > /opt/mp-app/ops/sudoers.d/deploy <<'EOF'
# deploy: operaciones rutinarias sin contraseña (MP_OPS); todo lo demás pide contraseña.
# El orden importa: la línea NOPASSWD va al final para que prevalezca sobre la general.
Cmnd_Alias MP_OPS = /usr/bin/systemctl reload caddy, /usr/bin/systemctl restart caddy, /usr/bin/systemctl status caddy, \
  /usr/bin/caddy validate --config /etc/caddy/Caddyfile, \
  /usr/bin/systemctl start mp-backup.service, /usr/bin/systemctl status mp-backup.service, /usr/bin/systemctl status mp-backup.timer, \
  /usr/bin/systemctl start mp-healthcheck.service, /usr/bin/systemctl status mp-healthcheck.service, /usr/bin/systemctl status mp-healthcheck.timer, \
  /usr/bin/journalctl -u caddy *, /usr/bin/journalctl -u mp-backup.service *, /usr/bin/journalctl -u mp-healthcheck.service *, /usr/bin/journalctl -u fail2ban *, \
  /usr/sbin/ufw status *, /usr/sbin/iptables -S DOCKER-USER, /usr/bin/fail2ban-client status, /usr/bin/fail2ban-client status sshd, \
  /usr/local/bin/mp-restore-test.sh, /usr/bin/restic snapshots *, /usr/bin/restic stats *
deploy ALL=(ALL) ALL
deploy ALL=(ALL) NOPASSWD: MP_OPS
EOF
install -m 440 -o root -g root /opt/mp-app/ops/sudoers.d/deploy /etc/sudoers.d/deploy
visudo -cf /etc/sudoers.d/deploy
```
Expected: `/etc/sudoers.d/deploy: parsed OK`.

- [ ] **Step 3: Verificar la allowlist como `deploy`**

Run: `sudo -u deploy sudo -n systemctl status caddy | head -3; sudo -u deploy sudo -n apt-get update 2>&1 | head -1`
Expected: estado de Caddy (`active (running)`), y para `apt-get` el mensaje `sudo: a password is required`.

- [ ] **Step 4: Traspasar el repo y la configuración de Claude Code / git (D9)**

```bash
chown -R deploy:deploy /opt/mp-app
cp -a /root/.claude/. /home/deploy/.claude/
install -m 600 -o deploy -g deploy /root/.claude.json /home/deploy/.claude.json
install -m 600 -o deploy -g deploy /root/.git-credentials /home/deploy/.git-credentials
chown -R deploy:deploy /home/deploy/.claude
sudo -u deploy git config --global user.name "Gianclaudio"
sudo -u deploy git config --global user.email "gianclaudio.lopolito@gmail.com"
sudo -u deploy git config --global credential.helper store
sudo -u deploy git -C /opt/mp-app status -sb | head -1
sudo -u deploy git -C /opt/mp-app ls-remote --heads origin main | cut -c1-12
```
Expected: `## main...origin/main` y el hash corto de `main` en GitHub (prueba de acceso al remoto como `deploy`, sin imprimir credenciales).

- [ ] **Step 5: Checkpoint A (manual, Gianclaudio)**

1. En VS Code Remote-SSH conectar a `deploy@5.78.214.136` con la misma llave.
2. En esa terminal: `docker ps` (lista los 5 contenedores) y `sudo -n systemctl status caddy` (sin pedir contraseña).
3. En una sesión root: `passwd deploy` (contraseña fuerte guardada en tu gestor; solo sirve para `sudo`, nunca para SSH).
4. Confirmar por chat: "Checkpoint A OK".

- [ ] **Step 6: Commit**

```bash
cd /opt/mp-app && git add ops/sudoers.d/deploy && git commit -m "ops(brief-01): deploy user sudoers allowlist" && git push origin main
```

---

### Task 3: Hardening de SSH en dos fases (solo tras el Checkpoint A)

**Cambio de plan (Gianclaudio, 02-oct-2026, tras revisar los logs de SSH):** las 814 entradas con llave usaron su única llave (`gianj@GLoPolito`); las líneas `signature ssh-rsa` son rechazos por `PubkeyAcceptedAlgorithms`; hubo **una** entrada de root con contraseña desde `5.78.214.136` el 04-sep (origen no identificado; no se repitió). Cotizador (`/opt/cotizador-isthmus`) y Max Motors (`/home/maxmotors`) son `root:root` y hoy se operan como root, así que cerrar root de golpe dejaría esos despliegues sin operador. Por eso:

- **Fase 1 (hoy):** fuera contraseñas y teclado interactivo; root sigue entrando **solo por llave** (`PermitRootLogin prohibit-password`). Sin `AllowUsers`.
- **Fase 2 (después):** `PermitRootLogin no` + `AllowUsers deploy`, solo cuando `deploy` pueda operar Cotizador y Max Motors (Task 3b).

**Lectura previa (02-oct, solo lectura):** n8n no tiene credenciales SSH de ningún tipo (14 credenciales listadas por el MCP: OAuth, SMTP, Header Auth, SSL), así que ningún workflow puede entrar al VPS por SSH; sus llamadas al Cotizador y a Max Motors son HTTP vía Caddy y no dependen de sshd. Ni cotizador ni maxmotors usan bind mounts (imágenes construidas con `build`), no hay cron, hooks ni units que hagan `ssh` al propio host.

**Files:**
- Create: `ops/ssh/00-hardening.conf` → `/etc/ssh/sshd_config.d/00-hardening.conf` (fase 1; la fase 2 añade dos líneas al mismo archivo)

**Quién ejecuta:** el clasificador de permisos de Claude Code bloquea escribir en `/etc/ssh/sshd_config.d/` (02-oct). Los comandos de instalación los corre **Gianclaudio** desde su sesión root; Claude Code escribe el archivo del repo, verifica en solo lectura (`sshd -T`) y documenta.

- [x] **Step 1: Checkpoint A** — confirmado por Gianclaudio el 02-oct-2026 ("Checkpoint A OK"): login `deploy` por VS Code, `docker ps`, `sudo -n systemctl status caddy`, `passwd deploy`.

- [x] **Step 2: Drop-in de fase 1 escrito en el repo** (nombre `00-` para ganar a `50-cloud-init.conf`, que fija `PasswordAuthentication yes`; el `sshd_config` principal tiene `PermitRootLogin yes` en la línea 54, también por debajo del drop-in)

```
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
MaxAuthTries 4
LoginGraceTime 30
X11Forwarding no
```

- [ ] **Step 3: Instalar y recargar (Gianclaudio, sesión root; la segunda ventana como `deploy` queda abierta)**

```bash
install -m 644 -o root -g root /opt/mp-app/ops/ssh/00-hardening.conf /etc/ssh/sshd_config.d/00-hardening.conf
sshd -t && echo "sshd config OK"
systemctl reload ssh
sshd -T 2>/dev/null | grep -Ei '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|maxauthtries|logingracetime|x11forwarding) '
```
Expected: `sshd config OK`; luego `permitrootlogin prohibit-password`, `passwordauthentication no`, `kbdinteractiveauthentication no`, `pubkeyauthentication yes`, `maxauthtries 4`, `logingracetime 30`, `x11forwarding no`. Si `sshd -t` falla: `rm /etc/ssh/sshd_config.d/00-hardening.conf` y no recargar.

- [ ] **Step 4: Prueba desde fuera (Gianclaudio, laptop, sin cerrar las sesiones abiertas)**

```bash
ssh -o BatchMode=yes -o PubkeyAuthentication=no root@5.78.214.136 true; echo rc=$?   # contraseña cerrada
ssh root@5.78.214.136 hostname                                                        # root por llave sigue (fase 1)
ssh deploy@5.78.214.136 hostname
```
Expected: primera línea `Permission denied (publickey)` y `rc=255`; las otras dos `isthmus-n8n`. Pegar las salidas en el chat.

- [ ] **Step 5: Commit (tres órdenes separadas, regla de CLAUDE.md)**

`git add ops/ssh/00-hardening.conf` · `git commit -m "ops(brief-01): sshd hardening phase 1 (no passwords, root key-only)"` · `git push origin main`

---

### Task 3b: Fase 2 del hardening — `deploy` opera Cotizador y Max Motors, luego root fuera

**Estado real (02-oct, solo lectura):** `/opt/cotizador-isthmus` es repo git (`master`, **sin remoto**: el historial solo existe en el VPS), `root:root 755`, `.env.production` y `.env.local` en **644** (legibles por cualquier usuario del host). `/home/maxmotors` no es repo; `/home/maxmotors/app` sí (sin remoto), `root:root`, `.env.local` 644; no existe usuario `maxmotors`. Despliegue en ambos: editar en sitio → `docker tag <imagen>:latest <imagen>:pre-<brief>` → `docker compose up -d --build`. Ningún bind mount: cambiar dueños o editar el árbol **no afecta** al contenedor en marcha; solo un `up -d --build` explícito lo cambia.

**Propuesta (mismo modelo que `/opt/mp-app`, D9):** `deploy` pasa a ser el dueño de los dos árboles; root conserva acceso (no lo limitan los permisos) pero deja de ser el operador. `deploy` ya está en el grupo `docker`, que equivale a root sobre el host: la separación protege de **accidentes**, no de un `deploy` hostil; lo que protege producción es que no hay bind mounts y el rebuild es explícito.

- [ ] **Step 1: Traspaso de dueños y cierre de los `.env` (Gianclaudio, root; sin efecto en los contenedores)**

```bash
chown -R deploy:deploy /opt/cotizador-isthmus /home/maxmotors
chmod 600 /opt/cotizador-isthmus/.env.production /opt/cotizador-isthmus/.env.local /home/maxmotors/app/.env.local
git config --system --add safe.directory /opt/cotizador-isthmus
git config --system --add safe.directory /home/maxmotors/app
docker ps --format '{{.Names}} {{.Status}}' | grep -E 'cotizador|maxmotors'      # siguen Up, sin reinicio
```

- [ ] **Step 2: Verificar que `deploy` puede operar sin sudo**

```bash
sudo -u deploy git -C /opt/cotizador-isthmus status -sb | head -1               # ## master
sudo -u deploy git -C /home/maxmotors/app status -sb | head -1
sudo -u deploy docker compose -f /opt/cotizador-isthmus/docker-compose.yml config --quiet && echo "compose cotizador OK"
sudo -u deploy docker compose -f /home/maxmotors/docker-compose.yml config --quiet && echo "compose maxmotors OK"
```
Expected: las cuatro líneas sin error (`config` lee los `.env` como `deploy`, prueba de que los 600 bastan).

- [ ] **Step 3: Un despliegue real como `deploy`** — el siguiente brief del Cotizador o de Max Motors se despliega desde la sesión `deploy` con el procedimiento de siempre (tag `pre-<brief>` + `up -d --build`) y `sudo systemctl reload caddy` si hace falta (ya está en `MP_OPS`). Ese es el criterio de "deploy puede trabajar".

- [ ] **Step 4: Fase 2 del drop-in (Gianclaudio, con sesión `deploy` abierta y `sudo -i` probado)**

Añadir a `ops/ssh/00-hardening.conf` las líneas `PermitRootLogin no` y `AllowUsers deploy`; repetir Task 3 Steps 3–4 con expected `permitrootlogin no`, `allowusers deploy`, y desde la laptop `ssh root@5.78.214.136 hostname` → `Permission denied (publickey)`. Commit en tres órdenes.

**Recomendado, fuera del alcance del Brief 01:** dar remoto privado en GitHub a los dos repos (hoy la única copia es el VPS más los Backups de Hetzner); limpiar los archivos `sha256:*` sueltos en `/opt/cotizador-isthmus` (parecen redirecciones accidentales de `docker build`/`docker images -q`).

---

### Task 4: fail2ban y firewall real sobre Docker

**Files:**
- Create: `ops/fail2ban/jail.local` → `/etc/fail2ban/jail.local`
- Create: `ops/ufw/after.rules.docker-user` (bloque que se añade a `/etc/ufw/after.rules`)

- [ ] **Step 1: Instalar y configurar fail2ban (backend systemd: Ubuntu 26.04 no tiene auth.log)**

```bash
apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fail2ban
mkdir -p /opt/mp-app/ops/fail2ban
cat > /opt/mp-app/ops/fail2ban/jail.local <<'EOF'
[DEFAULT]
backend  = systemd
bantime  = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
mode    = aggressive
EOF
install -m 644 /opt/mp-app/ops/fail2ban/jail.local /etc/fail2ban/jail.local
systemctl enable --now fail2ban
sleep 2; fail2ban-client status sshd
```
Expected: `Status for the jail: sshd` con `Currently banned: 0` y `Jail list: sshd` en `fail2ban-client status`.

- [ ] **Step 2: Confirmar ufw (22/80/443 ya permitidos; no se recarga)**

Run: `ufw status numbered | grep -E "22|80|443"`
Expected: 6 reglas ALLOW IN (v4 y v6). No se ejecuta `ufw reload`.

- [ ] **Step 3: Bloquear en vivo los puertos publicados por Docker (D5)**

```bash
iptables -C DOCKER-USER -i eth0 -p tcp -m conntrack --ctstate NEW -m multiport --dports 3000,3001,3002,5678 -j DROP 2>/dev/null || \
iptables -I DOCKER-USER 1 -i eth0 -p tcp -m conntrack --ctstate NEW -m multiport --dports 3000,3001,3002,5678 -j DROP
iptables -S DOCKER-USER
/opt/mp-app/scripts/ops/check-services.sh post-docker-user; echo rc=$?
```
Expected: la regla `-A DOCKER-USER -i eth0 ... --dports 3000,3001,3002,5678 -j DROP` listada; `rc=0` (Caddy llega por loopback, no por `eth0`). IPv6 no necesita regla: en v6 Docker usa `docker-proxy` en espacio de usuario y ufw ya deniega por defecto.

- [ ] **Step 4: Persistir para el próximo arranque (sin recargar ufw)**

```bash
mkdir -p /opt/mp-app/ops/ufw
cat > /opt/mp-app/ops/ufw/after.rules.docker-user <<'EOF'
# BEGIN mp-app DOCKER-USER (Brief 01): los puertos que Docker publica no son alcanzables desde Internet; Caddy entra por loopback.
*filter
:DOCKER-USER - [0:0]
-A DOCKER-USER -i eth0 -p tcp -m conntrack --ctstate NEW -m multiport --dports 3000,3001,3002,5678 -j DROP
-A DOCKER-USER -j RETURN
COMMIT
# END mp-app DOCKER-USER
EOF
cp -a /etc/ufw/after.rules /root/backups/after.rules.pre-brief01
grep -q "BEGIN mp-app DOCKER-USER" /etc/ufw/after.rules || cat /opt/mp-app/ops/ufw/after.rules.docker-user >> /etc/ufw/after.rules
tail -8 /etc/ufw/after.rules
```
Expected: el bloque al final del archivo, una sola vez. La verificación real de persistencia ocurre tras el reinicio (Task 11 Step 4).

- [ ] **Step 5: Verificación externa (Gianclaudio, laptop)**

Run: `for p in 3000 3001 3002 5678; do curl -m 5 -s -o /dev/null -w "$p -> %{http_code}\n" http://5.78.214.136:$p || echo "$p -> sin respuesta"; done; curl -s -o /dev/null -w "automation -> %{http_code}\n" https://automation.isthmuscap.com/healthz`
Expected: los cuatro puertos `sin respuesta` (timeout) y `automation -> 200`.

- [ ] **Step 6: Commit**

```bash
cd /opt/mp-app && git add ops/fail2ban ops/ufw && git commit -m "ops(brief-01): fail2ban sshd jail and DOCKER-USER firewall rule" && git push origin main
```

---

### Task 5: `.env` fuera del repo y `docker-compose.yml` de `mp-app`

**Files:**
- Create (host): `/etc/mp-app/staging.env`, `/etc/mp-app/production.env` (640 `root:deploy`)
- Create: `docker-compose.yml`, `ops/env/staging.env.example`
- Modify: `CLAUDE.md` (Comandos; ubicación de secretos), `.gitignore` (sin cambios: `.env*` ya ignorado)
- Delete (host): `/opt/mp-app/.env` tras verificar la copia

**Interfaces:**
- Produces: servicios Compose `mp-app` (`127.0.0.1:3003`) y `mp-app-staging` (`127.0.0.1:3013`) con `env_file` `/etc/mp-app/{production,staging}.env`; variables `MP_ENV`, `PORT=3000`, `BG_AMBIENTE=qa`. Brief 02 añade el `Dockerfile` y despliega.

- [ ] **Step 1: Crear los archivos de entorno copiando los `WHATSAPP_*` sin imprimirlos**

```bash
install -d -m 750 -o root -g deploy /etc/mp-app
for env in staging production; do
  { printf '# mp-app %s — secretos fuera del repo (Brief 01). 640 root:deploy. Nunca commitear.\nNODE_ENV=production\nMP_ENV=%s\nPORT=3000\n# BG: staging y toda prueba = qa. prod SOLO con aprobacion explicita de Gianclaudio y Diego (CLAUDE.md).\nBG_AMBIENTE=qa\n' "$env" "$env"
    grep -E '^WHATSAPP_' /opt/mp-app/.env
    printf '# Briefs 03/04/05 anaden: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, N8N_WEBHOOK_BASE, N8N_WEBHOOK_SECRET, ZOHO_*, LOANDISK_*, IDANALYZER_*, HEALTH_TOKEN\n'
  } > /etc/mp-app/$env.env
  chown root:deploy /etc/mp-app/$env.env; chmod 640 /etc/mp-app/$env.env
done
diff <(grep -E '^WHATSAPP_' /opt/mp-app/.env | sort) <(grep -E '^WHATSAPP_' /etc/mp-app/staging.env | sort) && echo "copia verificada"
ls -l /etc/mp-app
```
Expected: `copia verificada` (diff vacío) y dos archivos `-rw-r----- root deploy`.

- [ ] **Step 2: Retirar el `.env` del árbol del repo**

```bash
rm /opt/mp-app/.env
ls /opt/mp-app/.env 2>&1 | head -1
mkdir -p /opt/mp-app/ops/env
cat > /opt/mp-app/ops/env/staging.env.example <<'EOF'
# Plantilla sin valores. El archivo real vive en /etc/mp-app/staging.env (640 root:deploy).
NODE_ENV=production
MP_ENV=staging
PORT=3000
BG_AMBIENTE=qa
WHATSAPP_TOKEN=
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_BUSINESS_ACCOUNT_ID=
WHATSAPP_APP_ID=
WHATSAPP_TEMPLATE_OTP=fic_mp_codigo_acceso
EOF
```
Expected: `No such file or directory` para `/opt/mp-app/.env`.

- [ ] **Step 3: Escribir `docker-compose.yml`**

```bash
cat > /opt/mp-app/docker-compose.yml <<'EOF'
# mp-app — Brief 01. El Dockerfile lo crea el Brief 02 (Next.js standalone, puerto interno 3000).
# Producción 127.0.0.1:3003 y staging 127.0.0.1:3013; Caddy hace el TLS. Secretos en /etc/mp-app/*.env.
x-mp-common: &mp-common
  build: .
  restart: unless-stopped
  init: true
  read_only: false
  healthcheck:
    test: ["CMD", "wget", "-qO-", "http://127.0.0.1:3000/api/health"]
    interval: 30s
    timeout: 5s
    retries: 3
    start_period: 30s
  logging:
    driver: json-file
    options: { max-size: "10m", max-file: "5" }
  networks: [n8n_default]
  security_opt: ["no-new-privileges:true"]

services:
  mp-app:
    <<: *mp-common
    image: mp-app:prod
    container_name: mp-app
    ports: ["127.0.0.1:3003:3000"]
    env_file: [/etc/mp-app/production.env]
    deploy:
      resources:
        limits: { memory: 768M }
  mp-app-staging:
    <<: *mp-common
    image: mp-app:staging
    container_name: mp-app-staging
    ports: ["127.0.0.1:3013:3000"]
    env_file: [/etc/mp-app/staging.env]
    deploy:
      resources:
        limits: { memory: 512M }

networks:
  n8n_default:
    external: true
EOF
cd /opt/mp-app && docker compose config --quiet && echo "compose OK"
```
Expected: `compose OK` (la validación no necesita el Dockerfile; `docker compose build` fallará hasta el Brief 02, y eso es esperado).

- [ ] **Step 4: Actualizar `CLAUDE.md`**

En `## Comandos` añadir la línea `docker compose up -d --build mp-app-staging  # staging (puerto 3013, /etc/mp-app/staging.env)` después de la de `mp-app`, y en `## Prohibido` cambiar `Solo \`.env\` del servidor y credenciales de N8N` por `Solo \`/etc/mp-app/*.env\` del servidor (640 root:deploy) y credenciales de N8N`.

Run: `grep -n "mp-app-staging\|/etc/mp-app" /opt/mp-app/CLAUDE.md`
Expected: dos líneas.

- [ ] **Step 5: Commit (verificando que ningún `.env` entra)**

```bash
cd /opt/mp-app && git status --porcelain | grep -c '\.env$' ; git add docker-compose.yml ops/env/staging.env.example CLAUDE.md && git commit -m "ops(brief-01): compose services for prod/staging, env files moved to /etc/mp-app" && git push origin main
```
Expected: el primer comando imprime `0`.

---

### Task 6: Caddy — `mp.` y `staging-mp.` con TLS, cabeceras y página de espera

**Files:**
- Create: `ops/caddy/Caddyfile.mp.snippet`, `ops/caddy/placeholder/index.html`
- Modify (host): `/etc/caddy/Caddyfile` (se añade el bloque; los 3 sitios existentes no se tocan)
- Create (host): `/var/www/mp-placeholder/{index.html,logo.png}`

- [ ] **Step 1: Checkpoint C — DNS (Gianclaudio en GoDaddy)**

Registros A: `mp` → `5.78.214.136` y `staging-mp` → `5.78.214.136`, TTL 600.
Run: `dig +short mp.isthmuscap.com staging-mp.isthmuscap.com @8.8.8.8`
Expected: `5.78.214.136` dos veces. No continuar hasta que resuelva (Caddy reintentaría la emisión del certificado y llenaría el log de errores).

- [ ] **Step 2: Página de espera con marca (copia revisada con `design:ux-copy`; sin texto técnico)**

```bash
mkdir -p /opt/mp-app/ops/caddy/placeholder
cat > /opt/mp-app/ops/caddy/placeholder/index.html <<'EOF'
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Isthmus Capital · Micropréstamos</title>
<style>
  :root{--fic-azul:#193A76;--fic-azul-claro:#66A5E6;--fic-gris-100:#F4F6FA;--fic-gris-600:#5B6472;--fic-texto:#16213A;--fic-blanco:#FFFFFF;--fic-radius-lg:16px}
  *{box-sizing:border-box}
  body{margin:0;min-height:100vh;display:flex;flex-direction:column;background:var(--fic-gris-100);color:var(--fic-texto);font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.5}
  header{background:var(--fic-azul);padding:14px 16px}
  header img{height:40px;width:auto;background:var(--fic-blanco);border-radius:6px;padding:4px 8px;display:block}
  main{flex:1;display:flex;align-items:center;justify-content:center;padding:24px 16px}
  .card{background:var(--fic-blanco);border-radius:var(--fic-radius-lg);padding:32px 24px;max-width:480px;width:100%;box-shadow:0 1px 2px rgba(15,38,80,.06)}
  h1{font-size:1.375rem;line-height:1.2;color:var(--fic-azul);margin:0 0 12px}
  p{margin:0 0 8px}
  .muted{color:var(--fic-gris-600);font-size:.875rem}
  footer{padding:16px;text-align:center;color:var(--fic-gris-600);font-size:.75rem}
</style>
</head>
<body>
<header><img src="/logo.png" alt="Isthmus Capital"></header>
<main>
  <section class="card" aria-labelledby="t">
    <h1 id="t">Estamos preparando la nueva plataforma de micropréstamos</h1>
    <p>Por el momento este sitio no está disponible.</p>
    <p class="muted">Vuelve a intentarlo en unos minutos.</p>
  </section>
</main>
<footer>Financiera Isthmus Capital · Panamá</footer>
</body>
</html>
EOF
install -d -m 755 -o root -g root /var/www/mp-placeholder
install -m 644 /opt/mp-app/ops/caddy/placeholder/index.html /var/www/mp-placeholder/index.html
install -m 644 /opt/mp-app/public/brand/logo.png /var/www/mp-placeholder/logo.png
sudo -u caddy cat /var/www/mp-placeholder/index.html >/dev/null && echo "caddy puede leer la página"
```
Expected: `caddy puede leer la página`.

- [ ] **Step 3: Snippet de Caddy (cabeceras, CSP base, 503 con marca)**

```bash
cat > /opt/mp-app/ops/caddy/Caddyfile.mp.snippet <<'EOF'
# ===== mp-app (Brief 01) — se añade al final de /etc/caddy/Caddyfile =====
(fic_security) {
	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		X-Content-Type-Options "nosniff"
		X-Frame-Options "DENY"
		Referrer-Policy "strict-origin-when-cross-origin"
		Permissions-Policy "camera=(self), microphone=(), geolocation=(), payment=(), usb=()"
		Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' data: blob:; connect-src 'self' https://*.supabase.co wss://*.supabase.co; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'; upgrade-insecure-requests"
		-Server
	}
}

(fic_site) {
	import fic_security
	encode zstd gzip
	reverse_proxy 127.0.0.1:{args[0]} {
		header_up X-Forwarded-Proto https
	}
	handle_errors {
		@down expression `{http.error.status_code} in [502, 503, 504]`
		handle @down {
			header Retry-After "120"
			root * /var/www/mp-placeholder
			@logo path /logo.png
			handle @logo {
				file_server
			}
			rewrite * /index.html
			file_server {
				status 503
			}
		}
	}
	log {
		output file /var/log/caddy/{args[1]}.log {
			roll_size 10mb
			roll_keep 5
		}
	}
}

staging-mp.isthmuscap.com {
	import fic_site 3013 staging-mp
}

mp.isthmuscap.com {
	import fic_site 3003 mp
}
EOF
cp -a /etc/caddy/Caddyfile /root/backups/Caddyfile.pre-brief01
grep -q "mp-app (Brief 01)" /etc/caddy/Caddyfile || { printf '\n'; cat /opt/mp-app/ops/caddy/Caddyfile.mp.snippet; } >> /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile && echo "Caddyfile OK"
```
Expected: `Caddyfile OK`. Si D7 = solo staging, omitir el bloque `mp.isthmuscap.com` antes de añadir.

- [ ] **Step 4: Recargar y verificar TLS, 503 con marca y cabeceras**

```bash
systemctl reload caddy; sleep 20
/opt/mp-app/scripts/ops/check-services.sh post-caddy; echo rc=$?
curl -sI https://staging-mp.isthmuscap.com | head -1
curl -s https://staging-mp.isthmuscap.com | grep -c "Estamos preparando"
curl -sI https://staging-mp.isthmuscap.com | grep -Ei "strict-transport|content-security|retry-after|x-frame"
echo | openssl s_client -connect staging-mp.isthmuscap.com:443 -servername staging-mp.isthmuscap.com 2>/dev/null | openssl x509 -noout -issuer -dates
```
Expected: `rc=0`; `HTTP/2 503`; `1`; cuatro cabeceras; emisor `Let's Encrypt` con fechas válidas. Repetir las tres últimas para `mp.isthmuscap.com` si D7 = sí. Criterio de aceptación 3 cumplido (responde con certificado válido; el 503 es la página de espera prevista hasta el Brief 02).

- [ ] **Step 5: Capturas de la página de espera (regla de UI) con Gotenberg**

```bash
mkdir -p /tmp/gb && cp /var/www/mp-placeholder/index.html /tmp/gb/index.html && cp /var/www/mp-placeholder/logo.png /tmp/gb/logo.png
sed -i 's#"/logo.png"#"logo.png"#' /tmp/gb/index.html
for w in 390 1440; do h=$([ $w = 390 ] && echo 844 || echo 900)
  curl -s -X POST http://127.0.0.1:3000/forms/chromium/screenshot/html -F files=@/tmp/gb/index.html -F files=@/tmp/gb/logo.png -F width=$w -F height=$h -F format=png -o /opt/mp-app/docs/design/capturas/placeholder-$w.png; done
ls -l /opt/mp-app/docs/design/capturas/placeholder-*.png
```
Expected: dos PNG > 10 KB. Revisarlos (Read) y comprobar contraste azul/blanco ≥ 4.5:1 (`#193A76` sobre `#FFFFFF` = 11.6:1).

- [ ] **Step 6: Commit**

```bash
cd /opt/mp-app && git add ops/caddy docs/design/capturas/placeholder-*.png && git commit -m "ops(brief-01): caddy hosts for mp/staging-mp with TLS, security headers and branded 503" && git push origin main
```

---

### Task 7: Backups diarios con restic y restauración probada

**Files:**
- Create: `ops/backup/mp-backup.sh`, `ops/backup/mp-restore-test.sh`, `ops/backup/mp-alert.sh`, `ops/backup/restic.env.example`, `ops/systemd/mp-backup.service`, `ops/systemd/mp-backup.timer`, `ops/systemd/mp-alert@.service`
- Create (host): `/etc/mp-backup/restic.env` (600 root), `/usr/local/bin/mp-{backup,restore-test,alert}.sh`, `/var/lib/mp-backup/`, `/var/lib/mp-health/`

**Interfaces:**
- Consumes: `MP_OPS` (Task 2) para que `deploy` pueda lanzar `mp-backup.service` y `mp-restore-test.sh`.
- Produces: `/var/lib/mp-backup/last-success` (ISO-8601 UTC) que leerá `/api/health` (Brief 02); `mp-alert.sh "<origen>"` que usan Task 8 y `OnFailure=`.

- [ ] **Step 1: Instalar restic y preparar el repositorio (D2: Storage Box; mientras no exista, repositorio local)**

```bash
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq restic
install -d -m 700 /etc/mp-backup /var/lib/mp-backup /var/lib/mp-health /var/backups/restic-local
[ -f /root/.ssh/id_ed25519_storagebox ] || ssh-keygen -t ed25519 -N '' -C "mp-backup@isthmus-n8n" -f /root/.ssh/id_ed25519_storagebox -q
echo "Llave pública para registrar en el Storage Box:"; cat /root/.ssh/id_ed25519_storagebox.pub
[ -f /etc/mp-backup/restic.env ] || { printf 'RESTIC_REPOSITORY=/var/backups/restic-local\nRESTIC_PASSWORD=%s\nMP_BACKUP_INCLUDE_N8N=1\nN8N_PG_CONTAINER=n8n-postgres-1\nN8N_PG_USER=n8n\n' "$(openssl rand -base64 32)" > /etc/mp-backup/restic.env; chmod 600 /etc/mp-backup/restic.env; }
mkdir -p /opt/mp-app/ops/backup
cat > /opt/mp-app/ops/backup/restic.env.example <<'EOF'
# Archivo real: /etc/mp-backup/restic.env (600 root). La contraseña del repositorio va al gestor de contraseñas de Gianclaudio:
# si se pierde, los backups son irrecuperables.
RESTIC_REPOSITORY=sftp:uXXXXXX@uXXXXXX.your-storagebox.de:/restic-isthmus   # hasta tener el Storage Box: /var/backups/restic-local
RESTIC_PASSWORD=
MP_BACKUP_INCLUDE_N8N=1          # D3: 0 excluye volúmenes, dump y /opt/n8n
N8N_PG_CONTAINER=n8n-postgres-1
N8N_PG_USER=n8n
EOF
set -a; . /etc/mp-backup/restic.env; set +a; restic snapshots >/dev/null 2>&1 || restic init
restic snapshots | tail -1
```
Expected: la llave pública impresa (para que Gianclaudio la registre en Robot → Storage Box → SSH keys), `created restic repository ... ` o `0 snapshots`. Cuando llegue el Storage Box (Checkpoint D): añadir a `/root/.ssh/config` el bloque `Host uXXXXXX.your-storagebox.de` / `Port 23` / `IdentityFile /root/.ssh/id_ed25519_storagebox`, cambiar `RESTIC_REPOSITORY` y repetir `restic init`. **Gianclaudio guarda `RESTIC_PASSWORD` en su gestor** (`sudo grep RESTIC_PASSWORD /etc/mp-backup/restic.env` desde su terminal, no desde el chat).

- [ ] **Step 2: Script de backup**

```bash
cat > /opt/mp-app/ops/backup/mp-backup.sh <<'EOF'
#!/usr/bin/env bash
# Backup diario del VPS a restic (Brief 01). Lo ejecuta systemd (mp-backup.service) como root. Retención 14 días.
set -euo pipefail
set -a; . /etc/mp-backup/restic.env; set +a
STAGE=/var/backups/mp-stage
log(){ printf '%s mp-backup %s\n' "$(date -u +%FT%TZ)" "$*"; }
cleanup(){ rm -rf "$STAGE"; }
trap cleanup EXIT
rm -rf "$STAGE"; install -d -m 700 "$STAGE"

# 1) Volúmenes Docker con nombre (los anónimos de 64 hex se omiten), copiados en caliente y solo lectura.
for vol in $(docker volume ls -q | grep -Ev '^[0-9a-f]{64}$'); do
  case "$vol" in n8n_*) [ "${MP_BACKUP_INCLUDE_N8N:-1}" = "1" ] || { log "omitido $vol (MP_BACKUP_INCLUDE_N8N=0)"; continue; };; esac
  docker run --rm -v "$vol":/data:ro -v "$STAGE":/backup alpine:3.20 tar czf "/backup/vol-$vol.tgz" -C /data .
  log "volumen $vol → vol-$vol.tgz ($(du -h "$STAGE/vol-$vol.tgz" | cut -f1))"
done

# 2) Dump lógico consistente del Postgres de n8n (D3). Lo ejecuta systemd/Gianclaudio, nunca la sesión de Claude Code.
N8N_PATHS=()
if [ "${MP_BACKUP_INCLUDE_N8N:-1}" = "1" ]; then
  docker exec "$N8N_PG_CONTAINER" pg_dumpall -U "$N8N_PG_USER" | gzip -1 > "$STAGE/n8n-pg_dumpall.sql.gz"
  log "dump n8n → n8n-pg_dumpall.sql.gz ($(du -h "$STAGE/n8n-pg_dumpall.sql.gz" | cut -f1))"
  N8N_PATHS=(/opt/n8n)
fi

# 3) Configuración del host y proyecto. restic cifra todo (incluye .env y compose con secretos).
#    Solo se pasan rutas existentes: una ruta ausente haría fallar restic (exit 3) y abortar el backup.
WANT=("$STAGE" /opt/mp-app /etc/mp-app /etc/mp-backup /etc/caddy /var/www/mp-placeholder
  /etc/ssh/sshd_config.d /etc/sudoers.d /etc/fail2ban/jail.local /etc/ufw/after.rules
  /etc/systemd/system/mp-backup.service /etc/systemd/system/mp-backup.timer /etc/systemd/system/mp-alert@.service
  /etc/systemd/system/mp-healthcheck.service /etc/systemd/system/mp-healthcheck.timer /usr/local/bin/mp-backup.sh
  /usr/local/bin/mp-restore-test.sh /usr/local/bin/mp-alert.sh /usr/local/bin/mp-healthcheck.sh
  /root/backups /opt/cotizador-isthmus/docker-compose.yml /opt/cotizador-isthmus/.env.production /home/maxmotors/docker-compose.yml
  "${N8N_PATHS[@]}")
PATHS=(); for p in "${WANT[@]}"; do [ -e "$p" ] && PATHS+=("$p") || log "aviso: no existe $p (omitido)"; done
restic backup --quiet --tag daily \
  --exclude /opt/mp-app/node_modules --exclude /opt/mp-app/.next --exclude '/opt/n8n/*.dump' \
  "${PATHS[@]}"
restic forget --quiet --tag daily --keep-daily 14 --prune
restic check --quiet
date -u +%FT%TZ > /var/lib/mp-backup/last-success
log "OK snapshot $(restic snapshots --json --latest 1 --tag daily | python3 -c 'import json,sys;print(json.load(sys.stdin)[0]["short_id"])')"
EOF
install -m 750 -o root -g root /opt/mp-app/ops/backup/mp-backup.sh /usr/local/bin/mp-backup.sh
bash -n /usr/local/bin/mp-backup.sh && echo "sintaxis OK"
```
Expected: `sintaxis OK`. Nota: los `.dump` antiguos de `/opt/n8n` (ya respaldados en `/root/backups` como SQL) se excluyen por tamaño.

- [ ] **Step 3: Hook de alerta y unidades systemd**

```bash
cat > /opt/mp-app/ops/backup/mp-alert.sh <<'EOF'
#!/usr/bin/env bash
# Alerta operativa (Brief 01). Canal de salida: pendiente del Brief 13 (plantilla UTILITY de WhatsApp o correo desde gestionprestamos@ vía mp_notificar).
# Hasta entonces: journal + /var/lib/mp-health/alerts.log, que /api/health (Brief 02) expone como last_alert.
set -u
src="${1:-desconocido}"; ts="$(date -u +%FT%TZ)"
mkdir -p /var/lib/mp-health
printf '%s ALERTA %s\n' "$ts" "$src" | tee -a /var/lib/mp-health/alerts.log
logger -t mp-alert -p user.err "ALERTA $src"
EOF
mkdir -p /opt/mp-app/ops/systemd
cat > /opt/mp-app/ops/systemd/mp-alert@.service <<'EOF'
[Unit]
Description=Alerta operativa mp (%i)
[Service]
Type=oneshot
ExecStart=/usr/local/bin/mp-alert.sh %i
EOF
cat > /opt/mp-app/ops/systemd/mp-backup.service <<'EOF'
[Unit]
Description=Backup diario del VPS con restic (Brief 01)
After=docker.service network-online.target
Wants=network-online.target
OnFailure=mp-alert@backup.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/mp-backup.sh
Nice=10
IOSchedulingClass=idle
EOF
cat > /opt/mp-app/ops/systemd/mp-backup.timer <<'EOF'
[Unit]
Description=Backup diario a las 03:00 Panamá (08:00 UTC)
[Timer]
OnCalendar=*-*-* 08:00:00 UTC
RandomizedDelaySec=10m
Persistent=true
[Install]
WantedBy=timers.target
EOF
install -m 750 /opt/mp-app/ops/backup/mp-alert.sh /usr/local/bin/mp-alert.sh
install -m 644 /opt/mp-app/ops/systemd/mp-alert@.service /opt/mp-app/ops/systemd/mp-backup.service /opt/mp-app/ops/systemd/mp-backup.timer /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now mp-backup.timer && systemctl list-timers mp-backup.timer --no-pager | head -2
/usr/local/bin/mp-alert.sh prueba && tail -1 /var/lib/mp-health/alerts.log
```
Expected: el timer listado con `NEXT` a las 08:00 UTC; una línea `ALERTA prueba` en el log.

- [ ] **Step 4: Script de prueba de restauración**

```bash
cat > /opt/mp-app/ops/backup/mp-restore-test.sh <<'EOF'
#!/usr/bin/env bash
# Prueba de restauración (Brief 01, criterio de aceptación 4): volumen con contenido conocido → backup → borrar → restaurar → comparar SHA-256; y diff del Caddyfile.
set -euo pipefail
set -a; . /etc/mp-backup/restic.env; set +a
vol=mp-restore-test; work="$(mktemp -d)"
docker volume rm -f "$vol" >/dev/null 2>&1 || true
docker volume create "$vol" >/dev/null
docker run --rm -v "$vol":/data alpine:3.20 sh -c 'echo "FIC restore test $(date -u)" > /data/marker.txt; dd if=/dev/urandom of=/data/blob.bin bs=1M count=5 status=none'
docker run --rm -v "$vol":/data:ro alpine:3.20 sh -c 'cd /data && sha256sum marker.txt blob.bin' > "$work/before.sha"
/usr/local/bin/mp-backup.sh
docker volume rm "$vol" >/dev/null
snap="$(restic snapshots --json --latest 1 --tag daily | python3 -c 'import json,sys;print(json.load(sys.stdin)[0]["short_id"])')"
restic restore "$snap" --target "$work/restore" --include "/var/backups/mp-stage/vol-$vol.tgz" --include /etc/caddy/Caddyfile --quiet
docker volume create "$vol" >/dev/null
docker run --rm -v "$vol":/data -v "$work/restore/var/backups/mp-stage":/src:ro alpine:3.20 tar xzf "/src/vol-$vol.tgz" -C /data
docker run --rm -v "$vol":/data:ro alpine:3.20 sh -c 'cd /data && sha256sum marker.txt blob.bin' > "$work/after.sha"
diff "$work/before.sha" "$work/after.sha" && echo "RESTORE volumen OK (snapshot $snap)"
diff /etc/caddy/Caddyfile "$work/restore/etc/caddy/Caddyfile" && echo "RESTORE Caddyfile OK"
docker volume rm "$vol" >/dev/null; rm -rf "$work"
EOF
install -m 750 /opt/mp-app/ops/backup/mp-restore-test.sh /usr/local/bin/mp-restore-test.sh
bash -n /usr/local/bin/mp-restore-test.sh && echo "sintaxis OK"
```
Expected: `sintaxis OK`.

- [ ] **Step 5: Checkpoint E — primera corrida y prueba de restauración (quién la ejecuta depende de D3)**

Con `MP_BACKUP_INCLUDE_N8N=1` la ejecuta **Gianclaudio** desde su terminal (`sudo /usr/local/bin/mp-restore-test.sh`) y pega las dos líneas `RESTORE ... OK` en el chat. Con `MP_BACKUP_INCLUDE_N8N=0` la ejecuta la sesión.
Run: `sudo /usr/local/bin/mp-restore-test.sh 2>&1 | tail -6; cat /var/lib/mp-backup/last-success; restic snapshots --tag daily | tail -3`
Expected: `RESTORE volumen OK (snapshot xxxxxxxx)`, `RESTORE Caddyfile OK`, fecha de hoy, y al menos un snapshot. La restauración de n8n (dump + volúmenes) la prueba Gianclaudio cuando lo decida, fuera de esta sesión; se anota en el runbook.

- [ ] **Step 6: Verificar el disparo por systemd y la alerta en fallo**

```bash
systemctl start mp-backup.service && systemctl status mp-backup.service --no-pager | tail -3
cp /etc/mp-backup/restic.env /root/backups/restic.env.ok && sed -i 's#^RESTIC_REPOSITORY=.*#RESTIC_REPOSITORY=/nonexistent/repo#' /etc/mp-backup/restic.env
systemctl start mp-backup.service; sleep 2; tail -1 /var/lib/mp-health/alerts.log
install -m 600 /root/backups/restic.env.ok /etc/mp-backup/restic.env && rm /root/backups/restic.env.ok
systemctl start mp-backup.service && echo "backup restablecido"
```
Expected: primer `status` `inactive (dead)` con `Succeeded`; tras el sabotaje una línea `ALERTA backup.service`; al final `backup restablecido`.

- [ ] **Step 7: Checkpoint F — backups de Supabase (pendiente hasta el 03-oct, plan Pro)**

Cuando exista `isthmus-mp` en Pro: Dashboard → Project Settings → Database → Backups: confirmar "Daily backups" activo y la hora; decidir PITR (add-on). Anotar en `docs/ops/RUNBOOK_VPS.md` §Backups y en RIESGOS R10. Si el brief cierra antes, queda como pendiente explícito.

- [ ] **Step 8: Commit**

```bash
cd /opt/mp-app && git add ops/backup ops/systemd && git commit -m "ops(brief-01): restic daily backups, restore test and alert hook" && git push origin main
```

---

### Task 8: Contrato de `/api/health` y sonda externa (D6)

**Files:**
- Create: `docs/ops/HEALTH.md`, `ops/health/mp-healthcheck.sh`, `ops/systemd/mp-healthcheck.service`, `ops/systemd/mp-healthcheck.timer`

**Interfaces:**
- Produces: contrato que implementa el Brief 02 (`app/api/health/route.ts`): `GET /api/health` → `200 {"status":"ok"}` o `503 {"status":"degraded"|"down"}` con `checks.{db,n8n,zoho,loandisk,backup}` = `{state: ok|fail|skipped, ms, detail}`; `backup` lee `/var/lib/mp-backup/last-success` (montado `:ro`, falla si > 36 h); sin secretos ni PII; detalle completo solo con cabecera `X-Health-Token` (= `HEALTH_TOKEN` del `.env`), sin token solo `status`.

- [ ] **Step 1: Escribir el contrato**

```bash
mkdir -p /opt/mp-app/docs/ops /opt/mp-app/ops/health
cat > /opt/mp-app/docs/ops/HEALTH.md <<'EOF'
# `/api/health` — contrato (Brief 01) e implementación (Briefs 02–05)

**Ruta:** `GET /api/health` (sin autenticación para el resumen; detalle con cabecera `X-Health-Token: <HEALTH_TOKEN>`).
**Respuesta:** `200` cuando todos los chequeos críticos están `ok`; `503` si alguno crítico falla. Siempre JSON, nunca HTML ni trazas.

```json
{ "status": "ok | degraded | down", "env": "staging", "version": "<git sha>", "at": "2026-10-02T08:00:00Z",
  "checks": {
    "db":       { "state": "ok|fail|skipped", "ms": 12, "detail": "select 1" },
    "n8n":      { "state": "ok|fail|skipped", "ms": 80, "detail": "GET https://automation.isthmuscap.com/healthz" },
    "zoho":     { "state": "ok|fail|skipped", "ms": 150, "detail": "token válido hasta <fecha>" },
    "loandisk": { "state": "ok|fail|skipped", "ms": 300, "detail": "GET branch 87572" },
    "backup":   { "state": "ok|fail", "ms": 1, "detail": "último éxito <ISO>; umbral 36 h" }
  },
  "last_alert": "<última línea de /var/lib/mp-health/alerts.log o null>" }
```

| Chequeo | Crítico | Se implementa en | Fuente |
|---|---|---|---|
| `db` | sí | Brief 03 (`select 1` con service role, timeout 2 s) | Supabase `isthmus-mp` |
| `n8n` | sí | Brief 02 (`/healthz`, timeout 3 s) | `N8N_WEBHOOK_BASE` |
| `zoho` | no (degraded) | Brief 05 (adaptador; verifica que el token de la credencial N8N responda) | vía N8N, nunca directo |
| `loandisk` | no (degraded) | Brief 05 (adaptador `core`) | LoanDisk API |
| `backup` | sí | Brief 02 (lee `/var/lib/mp-backup/last-success`, volumen `:ro`) | Task 7 |

**Sonda externa:** `mp-healthcheck.timer` (cada 5 min) hace `GET https://staging-mp.isthmuscap.com/api/health`; tres fallos seguidos → `mp-alert.sh health:<url>:<código>`. Se **activa en el Brief 02** cuando la ruta exista (hoy respondería 503 por la página de espera).
**Alerta:** canal WhatsApp al admin con plantilla UTILITY (Brief 13); hasta entonces journal + `/var/lib/mp-health/alerts.log`.
**Sin `skipped` en producción:** un chequeo `skipped` solo es válido en staging mientras la dependencia no esté configurada.
EOF
```

- [ ] **Step 2: Sonda y unidades (instaladas, timer sin activar)**

```bash
cat > /opt/mp-app/ops/health/mp-healthcheck.sh <<'EOF'
#!/usr/bin/env bash
# Sonda externa de /api/health (Brief 01). 3 fallos seguidos → mp-alert.sh. Estado en /var/lib/mp-health.
set -u
url="${1:-https://staging-mp.isthmuscap.com/api/health}"; st=/var/lib/mp-health; mkdir -p "$st"
code="$(curl -s -m 10 -o "$st/last-body.json" -w '%{http_code}' "$url" || echo 000)"
date -u +%FT%TZ > "$st/last-run"; echo "$code" > "$st/last-code"
if [ "$code" = "200" ]; then echo 0 > "$st/failures"; date -u +%FT%TZ > "$st/last-success"; exit 0; fi
f=$(( $(cat "$st/failures" 2>/dev/null || echo 0) + 1 )); echo "$f" > "$st/failures"
echo "health $url -> $code (fallo $f)"
[ "$f" -ge 3 ] && /usr/local/bin/mp-alert.sh "health:$url:$code"
exit 1
EOF
cat > /opt/mp-app/ops/systemd/mp-healthcheck.service <<'EOF'
[Unit]
Description=Sonda externa de /api/health (Brief 01)
[Service]
Type=oneshot
ExecStart=/usr/local/bin/mp-healthcheck.sh
EOF
cat > /opt/mp-app/ops/systemd/mp-healthcheck.timer <<'EOF'
[Unit]
Description=Sonda /api/health cada 5 min (activar en Brief 02)
[Timer]
OnCalendar=*:0/5
Persistent=false
[Install]
WantedBy=timers.target
EOF
install -m 750 /opt/mp-app/ops/health/mp-healthcheck.sh /usr/local/bin/mp-healthcheck.sh
install -m 644 /opt/mp-app/ops/systemd/mp-healthcheck.service /opt/mp-app/ops/systemd/mp-healthcheck.timer /etc/systemd/system/
systemctl daemon-reload
/usr/local/bin/mp-healthcheck.sh; echo rc=$?; cat /var/lib/mp-health/last-code
systemctl is-enabled mp-healthcheck.timer 2>&1
```
Expected: `health ... -> 503 (fallo 1)`, `rc=1`, `503`, y `disabled` (se activa en el Brief 02). Borrar el contador: `echo 0 > /var/lib/mp-health/failures`.

- [ ] **Step 3: Commit**

```bash
cd /opt/mp-app && git add docs/ops/HEALTH.md ops/health ops/systemd/mp-healthcheck.* && git commit -m "ops(brief-01): /api/health contract and external probe (timer disabled until Brief 02)" && git push origin main
```

---

### Task 9: Runbook del VPS y actualización de docs

**Files:**
- Create: `docs/ops/RUNBOOK_VPS.md` (skill `operations:runbook`)
- Modify: `docs/RIESGOS.md` (R04, R10, R11, R36), `docs/INVENTARIO_ACTUAL.md` §11 y §12, `docs/design/README.md` (capturas de la página de espera)

- [ ] **Step 1: Escribir el runbook con estas secciones y comandos exactos**

1. Acceso: `ssh deploy@5.78.214.136`; root deshabilitado; recuperación por consola Hetzner (Rescue) si se pierde la llave; `sudo` con contraseña (gestor de Gianclaudio) y allowlist `MP_OPS`.
2. Servicios: tabla puerto → contenedor → directorio compose → quién lo administra (cotizador `/opt/cotizador-isthmus`, maxmotors `/home/maxmotors`, n8n `/opt/n8n` **solo Gianclaudio**, gotenberg, mp-app `/opt/mp-app`).
3. Desplegar mp-app: `cd /opt/mp-app && git pull && docker compose up -d --build mp-app-staging` (staging) / `mp-app` (producción, con aprobación); `docker compose logs -f mp-app-staging`; rollback `docker compose up -d --no-build mp-app-staging` con la imagen previa (`docker tag`).
4. Caddy: editar `/etc/caddy/Caddyfile` → `sudo caddy validate --config /etc/caddy/Caddyfile` → `sudo systemctl reload caddy`; logs en `/var/log/caddy/*.log`; página de espera en `/var/www/mp-placeholder`.
5. Firewall: `sudo ufw status`; regla `DOCKER-USER` (`sudo iptables -S DOCKER-USER`); **nunca `ufw reload`/`disable` con contenedores arriba**; para desbloquear una IP en fail2ban: `sudo fail2ban-client set sshd unbanip <ip>`.
6. Backups: `sudo systemctl status mp-backup.timer`; corrida manual `sudo systemctl start mp-backup.service`; listar `sudo restic snapshots` (con `set -a; . /etc/mp-backup/restic.env`); restaurar un archivo `restic restore <id> --target /tmp/r --include <ruta>`; restaurar un volumen (pasos del `mp-restore-test.sh`); restaurar n8n (dump `n8n-pg_dumpall.sql.gz` → `docker exec -i n8n-postgres-1 psql -U n8n`; **lo ejecuta Gianclaudio**); prueba mensual `sudo /usr/local/bin/mp-restore-test.sh`; dónde está `RESTIC_PASSWORD`.
7. Actualizaciones y reinicio: `sudo apt-get update && sudo apt-get upgrade`; `ls /var/run/reboot-required`; procedimiento de reinicio = `check-services.sh pre-reboot` → `sudo systemctl reboot` → esperar 2 min → `check-services.sh post-reboot` → `sudo iptables -S DOCKER-USER`.
8. Salud y alertas: `/api/health` (contrato en `HEALTH.md`), `systemctl status mp-healthcheck.timer`, `/var/lib/mp-health/alerts.log`, `systemctl --failed`.
9. Secretos: `/etc/mp-app/{staging,production}.env`, `/etc/mp-backup/restic.env`; rotación del token de WhatsApp (Brief 04).
10. Escalamiento: Gianclaudio (infra y n8n) → Diego (decisiones de negocio); Hetzner soporte para hardware.

Run: `grep -c "^## " /opt/mp-app/docs/ops/RUNBOOK_VPS.md`
Expected: `10`.

- [ ] **Step 2: Actualizar riesgos e inventario**

- RIESGOS: R04 (cabeceras y CSP activas, `.env` fuera del repo), R10 (backups del VPS implementados; Supabase pendiente Checkpoint F), R11 (segunda copia en restic activa), R36 (sin cambio; sigue en n8n). Añadir **R37** "Puertos publicados por Docker alcanzables desde Internet" → cerrado con la regla `DOCKER-USER` (Task 4), detectivo: `iptables -S DOCKER-USER` en el runbook tras cada reinicio.
- INVENTARIO §11: SSH (`deploy`, root cerrado), DNS `mp.`/`staging-mp.` creados, `.env` en `/etc/mp-app`, backups restic, Supabase (pendiente 03-oct). §12: tachar el 9 (DNS) y anotar el estado de Supabase.
- `docs/design/README.md`: fila "Página de espera (Caddy 503)" con las capturas `placeholder-390.png` / `placeholder-1440.png`.

Run: `grep -n "R37\|/etc/mp-app\|placeholder-390" /opt/mp-app/docs/RIESGOS.md /opt/mp-app/docs/INVENTARIO_ACTUAL.md /opt/mp-app/docs/design/README.md | wc -l`
Expected: ≥ 3.

- [ ] **Step 3: Commit**

```bash
cd /opt/mp-app && git add docs/ops/RUNBOOK_VPS.md docs/RIESGOS.md docs/INVENTARIO_ACTUAL.md docs/design/README.md && git commit -m "docs(brief-01): VPS runbook, risk register and inventory updates" && git push origin main
```

---

### Task 10: Las 5 pantallas clave en HTML con tokens FIC (revisión en celular)

**Files:**
- Create: `docs/design/pantallas/base.css`, `docs/design/pantallas/index.html`, `01_wizard_monto.html`, `02_timeline_solicitud.html`, `03_estado_cuenta.html`, `04_base_diaria_carga.html`, `05_admin_bandeja.html`
- Create: `docs/design/capturas/0N_<pantalla>-390.png` y `-1440.png` (10 archivos)
- Modify: `docs/design/README.md` (tabla de pantallas + enlace al Artifact privado)

**Interfaces:**
- Consumes: `styles/tokens.css` (enlazado como `../../../styles/tokens.css`, mismo patrón que `preview.html`), Manrope por Google Fonts.
- Produces: la referencia visual que cada brief de UI (02, 07, 09, 15, 16) debe reproducir; aprobación de Gianclaudio registrada en `docs/design/README.md`.

- [ ] **Step 1: Cargar los skills y fijar el contenido de cada pantalla (datos ficticios etiquetados "Ejemplo", sin PII)**

Skills: `frontend-design` (dirección visual: sobrio, un acento por pantalla, mucho blanco, esquinas suaves), `design:ux-copy` (textos), y al final `design:accessibility-review`. Contenido por pantalla, tomado del Prompt Maestro:

| # | Pantalla | Viewport primario | Contenido mínimo |
|---|---|---|---|
| 01 | Wizard del cliente, paso 3 "Datos de la solicitud" (monto) | 390 | Stepper 6 pasos (paso 3 activo); botones de monto `$100 · $150 · $200 · $300` (§13.7); plazo `3 meses` (default), `6`, `9`, `12` (§16.1); ciclo `15 y 30` / `10 y 25`; tarjeta "Tu cuota" con el ejemplo verificado SO-00079: `$300`, 3 meses, 6 cuotas de `$86.00`, total `$516.00`, primer descuento `15 oct 2026` (§4.6); nota "La cuota se descuenta de tu planilla"; botón primario `Continuar`, secundario `Guardar y seguir después` (flujo reanudable §19). |
| 02 | Línea de tiempo de la solicitud | 390 | Encabezado con NUC `IS-00XXXX` (ejemplo) y SO; timeline vertical `Recibida → En revisión → Aprobada → Documentos enviados → Firmados → Desembolsado` (§4.1.6) con 3 completados, 1 activo, 2 pendientes; fecha/hora por evento; CTA contextual `Firmar documentos`. |
| 03 | Estado de cuenta | 390 | Saldo, próxima cuota (fecha y monto), cuotas pagadas/pendientes (`3 de 6`), `StatusBadge` "Al día" (`--estado-current`); tabla de cuotas (n.º, fecha, capital, interés, balance) con cifras tabulares; botones `Descargar cronograma PDF`, `Ver recibos` (§4.1 post-desembolso). |
| 04 | Carga de Base Diaria con reporte de errores (afiliado) | 1440 | Zona de carga (`.xlsx/.csv`), plantilla descargable (§17.4), resumen `412 filas · 405 válidas · 7 con error`, tabla de errores (fila, columna, problema, cómo corregirlo) con textos de ux-copy; botones `Corregir y volver a cargar`, `Cargar las 405 válidas`; también legible a 390. |
| 05 | Bandeja de admin | 1440 | Filtros por estado (máquina §7), tabla: SO, NUC, afiliado, monto, cuota, estado (`StatusBadge`), SLA restante, acción; panel lateral de detalle con botones `Aprobar`, `Solicitar revisión`, `Rechazar`; indicador "Parámetros vigentes: tasa 24 % · máx. descuento 50 %" (§4.4). |

- [ ] **Step 2: `base.css` compartido y las 6 páginas**

`base.css` solo usa variables de `tokens.css` (nada de hex), define `.btn`, `.card`, `.stepper`, `.timeline`, `.badge-estado-*`, `.table` (cifras `font-feature-settings:"tnum"`), tamaño de toque `min-height:var(--fic-touch-min)`, foco visible `outline:3px solid var(--fic-azul-claro)`. `index.html` lista las 5 pantallas con enlaces y la nota "Datos de ejemplo". Cada página: `<html lang="es">`, `viewport`, encabezado con logo (`../../../public/brand/logo.png`), un solo acento (`--fic-azul`) y estados con `--estado-*`.

Run: `grep -L 'tokens.css' /opt/mp-app/docs/design/pantallas/0*.html; grep -c '#[0-9A-Fa-f]\{6\}' /opt/mp-app/docs/design/pantallas/base.css; grep -c 'Ejemplo' /opt/mp-app/docs/design/pantallas/0*.html | grep -c ':0'`
Expected: nada en la primera línea (todas enlazan los tokens), `0` hex en `base.css`, `0` páginas sin la etiqueta "Ejemplo".

- [ ] **Step 3: Capturas 390 y 1440 con Gotenberg (patrón de `docs/design/README.md`)**

```bash
rm -rf /tmp/gb && mkdir -p /tmp/gb && cp /opt/mp-app/styles/tokens.css /opt/mp-app/public/brand/logo.png /opt/mp-app/docs/design/pantallas/base.css /tmp/gb/
for f in /opt/mp-app/docs/design/pantallas/0*.html; do n=$(basename "$f" .html)
  sed -e 's#\.\./\.\./\.\./styles/tokens\.css#tokens.css#' -e 's#\.\./\.\./\.\./public/brand/logo\.png#logo.png#' "$f" > /tmp/gb/index.html
  for w in 390 1440; do h=$([ $w = 390 ] && echo 1800 || echo 1100)
    curl -s -X POST http://127.0.0.1:3000/forms/chromium/screenshot/html -F files=@/tmp/gb/index.html -F files=@/tmp/gb/tokens.css -F files=@/tmp/gb/base.css -F files=@/tmp/gb/logo.png -F width=$w -F height=$h -F format=png -F waitDelay=2s -o "/opt/mp-app/docs/design/capturas/$n-$w.png"
  done; done
ls -l /opt/mp-app/docs/design/capturas/0*.png | wc -l
```
Expected: `10`. Revisar cada PNG (Read) antes de seguir.

- [ ] **Step 4: Revisión de accesibilidad y copy; corregir en sitio**

Skill `design:accessibility-review` sobre las 5 páginas (contraste AA, orden de foco, etiquetas de formulario, `aria-current` en stepper/timeline, toque ≥ 44 px) y `design:ux-copy` sobre todos los textos (sin jerga técnica; errores de la Base Diaria explican qué corregir). Registrar hallazgos y correcciones en `docs/design/README.md` → "Revisión de accesibilidad (Brief 01)".

Run: `grep -c "aria-current" /opt/mp-app/docs/design/pantallas/01_wizard_monto.html /opt/mp-app/docs/design/pantallas/02_timeline_solicitud.html`
Expected: ≥ 1 en cada archivo.

- [ ] **Step 5: Artifact privado para el celular (D8)**

Cargar `artifact-design` y publicar **un** Artifact "Pantallas FIC" que contenga las 5 pantallas con un selector (pestañas o enlaces) y los tokens inline (el Artifact no puede leer `tokens.css` del repo; se copian los valores y se anota que la fuente de verdad es `styles/tokens.css`), icono `design`, con modo oscuro conforme al contrato del skill. Pegar la URL en `docs/design/README.md` y en el chat.

Run: `grep -c "claude.ai/artifact" /opt/mp-app/docs/design/README.md`
Expected: `1`.

- [ ] **Step 6: Commit**

```bash
cd /opt/mp-app && git add docs/design && git commit -m "design(brief-01): five key screens in HTML with FIC tokens, captures and a11y review" && git push origin main
```

---

### Task 11: Actualizaciones de seguridad y reinicio coordinado (Checkpoint B)

**Files:** ninguno en el repo; evidencia en `/var/log/mp-ops/check-services.log`.

- [ ] **Step 1: Aplicar las actualizaciones sin reiniciar (se puede hacer en cualquier momento del brief)**

```bash
apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade && apt-get -y autoremove --purge
apt list --upgradable 2>/dev/null | wc -l; cat /var/run/reboot-required.pkgs
/opt/mp-app/scripts/ops/check-services.sh post-upgrade; echo rc=$?
```
Expected: `1` (solo la cabecera de `apt list`), la lista de paquetes que piden reinicio (kernel), `rc=0`.

- [ ] **Step 2: Ventana B (Gianclaudio, desde su terminal como `deploy`)**

```bash
/opt/mp-app/scripts/ops/check-services.sh pre-reboot && sudo systemctl reboot
```

- [ ] **Step 3: Tras ~2 min, reconectar y verificar**

```bash
uptime; uname -r; ls /var/run/reboot-required 2>&1
/opt/mp-app/scripts/ops/check-services.sh post-reboot; echo rc=$?
sudo iptables -S DOCKER-USER | grep -c "dports 3000,3001,3002,5678"
sudo fail2ban-client status sshd | head -3; systemctl is-active caddy fail2ban docker mp-backup.timer
```
Expected: `7.0.0-34-generic`, sin `reboot-required`, `rc=0` con los 5 contenedores `Up`, `1` (regla persistida), `active` ×4. Criterio de aceptación 2 cumplido (Cotizador y Max Motors antes y después). Si la regla `DOCKER-USER` no está, aplicarla con el comando de Task 4 Step 3 y revisar `/etc/ufw/after.rules`.

---

### Task 12: Cierre del brief

- [ ] **Step 1: Verificación completa (skill `superpowers:verification-before-completion`)**

```bash
cd /opt/mp-app
sshd -T 2>/dev/null | grep -Ei '^(permitrootlogin|passwordauthentication) '
sudo -n -u deploy sudo -n systemctl status caddy | head -1
fail2ban-client status sshd | grep "Jail"; ufw status | head -1; iptables -S DOCKER-USER | grep -c DROP
curl -sI https://staging-mp.isthmuscap.com | head -1; echo | openssl s_client -connect staging-mp.isthmuscap.com:443 -servername staging-mp.isthmuscap.com 2>/dev/null | openssl x509 -noout -issuer
systemctl list-timers mp-backup.timer --no-pager | head -2; cat /var/lib/mp-backup/last-success
docker compose config --quiet && echo compose-ok; ls -l /etc/mp-app; ls docs/design/capturas | wc -l
git status --porcelain | grep -c '\.env$'; git status -sb | head -1
```
Expected: `prohibit-password`/`no` tras la fase 1 (`no`/`no` tras la fase 2); Caddy `active`; jail `sshd`; `Status: active`; `1`; `HTTP/2 503` y `Let's Encrypt`; timer con próxima ejecución y fecha de hoy; `compose-ok`, dos `.env` 640, `13` capturas (2 preview + 1 placeholder ×2 + 10 pantallas → ajustar al conteo real); `0`; `## main...origin/main` sin `ahead`.

- [ ] **Step 2: Commit final y push**

```bash
cd /opt/mp-app && git add -A && git status --porcelain | grep -c '\.env$' && git commit -m "ops(brief-01): close infrastructure brief" ; git push origin main; git status -sb | head -1
```
Expected: `0` antes del commit (ningún `.env`), push sin error, `## main...origin/main`.

- [ ] **Step 3: Resumen para Gianclaudio**

Hecho / evidencia por criterio de aceptación; **pendientes**: Supabase backups (Checkpoint F, 03-oct), canal de alerta (Brief 13), activación de `mp-healthcheck.timer` (Brief 02), restauración de n8n probada por Gianclaudio, Storage Box si llegó después (cambio de `RESTIC_REPOSITORY`); **bloqueantes**: ninguno para el Brief 02 salvo la aprobación de las 5 pantallas en celular.
