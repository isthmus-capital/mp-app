# Ventana de mantenimiento del fin de semana — checklist único (Brief 01)

<!-- Brief 01 — 02-oct-2026. Reducida el 03-oct-2026 por decisión de Gianclaudio: la rotación de la contraseña de Postgres de n8n queda FUERA de la ventana y sin fecha (R40 "aceptado temporalmente"; procedimiento conservado en ROTACION_N8N_POSTGRES.md). Claude Code no ejecuta ningún paso ni abre archivos de n8n. -->

**Ejecutada el sáb 03-oct-2026, 02:33–03:00 UTC** por Gianclaudio (terminal root) con verificación de Claude Code en solo lectura. Resultado en `docs/INVENTARIO_ACTUAL.md` §0.1; R39 cerrado; criterio 2 del Brief 01 cumplido. Pendiente que dejó: kernel `7.0.0-38` retenido (R45). Este documento se conserva como procedimiento para la próxima ventana.

**Orden:** pre-chequeo → `apt upgrade` (incluye `docker-ce`) → reinicio de kernel → post-reboot → verificación externa de puertos (check-host.net) → verificación de n8n, Cotizador y Max Motors.

**Quién:** Gianclaudio, desde su terminal, como `root` (o `deploy` con `sudo -i`). Los comandos van en tu terminal, nunca en el chat.
**Fecha y hora:** fin de semana, la fijas tú. Evita 08:00 UTC ± 10 min (03:00 Panamá), cuando corre `mp-backup.timer`.
**Corte esperado:** todos los contenedores ~1 min (paso 2) y todo el VPS 2–3 min (paso 3). Cotizador, Max Motors, n8n y Gotenberg quedan sin servicio en esos tramos.
**Snapshot manual:** no hace falta. El VPS tiene Backups de Hetzner activos (ver `RUNBOOK_VPS.md` §6) y esta ventana no cambia ninguna base de datos, así que tampoco hace falta un dump previo.
**Fuera de esta ventana:** la rotación de la contraseña de Postgres de n8n (R40) queda aplazada sin fecha (decisión de Gianclaudio, 03-oct-2026). Cuando se decida hacerla, el procedimiento está en `ROTACION_N8N_POSTGRES.md`.

## 1. Pre-chequeo (5 min)

- [ ] **Restart policies** (las verificas tú; Claude Code no inspecciona los contenedores de n8n). Ninguno puede estar en `no`:

```bash
docker inspect -f '{{.Name}} -> {{.HostConfig.RestartPolicy.Name}}' $(docker ps -q)
```

Al 02-oct, `cotizador-app` y `maxmotors-app` están en `unless-stopped` y `gotenberg` en `always` (verificado); `n8n-n8n-1` y `n8n-postgres-1` los confirmas tú. Si alguno está en `no`: `docker update --restart unless-stopped <nombre>`.

- [ ] **n8n sin ejecuciones en curso:** UI → *Executions* → ninguna en *Running* (o por MCP: `search_workflow_executions` con `status` running, new y waiting debe devolver 0; así se verificó el 03-oct).
- [ ] **Línea base y regla de firewall:**

```bash
/opt/mp-app/scripts/ops/check-services.sh pre-ventana; echo rc=$?      # rc=0
iptables -S DOCKER-USER | grep -c DROP                                  # 1
uname -r; ls /var/run/reboot-required                                   # kernel actual y reinicio pendiente
```

- [ ] **Segunda terminal SSH abierta** durante toda la ventana. Con la fase 1 del hardening, `root` sigue entrando por llave; tras la fase 2 (`PermitRootLogin no`) solo `deploy` + `sudo -i`. El `apt upgrade` puede actualizar `openssh-server`; la sesión abierta sobrevive, pero la segunda es el seguro.

## 2. Actualización de paquetes, incluido `docker-ce` (10 min)

`docker-ce`, `containerd.io` y los plugins de Compose reinician el daemon de Docker y con él todos los contenedores (~1 min). Al 02-oct hay 26 paquetes pendientes (kernel `7.0.0-34` ya instalado).

```bash
/opt/mp-app/scripts/ops/check-services.sh pre-upgrade; echo rc=$?
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade && apt-get -y autoremove --purge
docker ps --format '{{.Names}} {{.Status}}'          # los 5 contenedores deben volver solos (restart policies)
/opt/mp-app/scripts/ops/check-services.sh post-upgrade; echo rc=$?
iptables -S DOCKER-USER | grep -c DROP               # debe seguir en 1
apt list --upgradable 2>/dev/null | wc -l            # 1 (solo la cabecera); más si hay paquetes en phasing o un kernel nuevo retenido (03-oct: 3)
cat /var/run/reboot-required.pkgs
```

- [ ] `post-upgrade` con `rc=0` y 5 contenedores `Up`; `DOCKER-USER` en `1`; sin paquetes pendientes.
- [ ] **Kernel nuevo retenido** (`linux-image-virtual` en `apt list --upgradable`, como el `7.0.0-38` de R45): `apt-get upgrade` no lo instala porque requiere un paquete nuevo. Instalarlo antes del paso 3 con `apt-get -y install linux-image-virtual` y comprobar que aparece en `/var/run/reboot-required.pkgs`.
- [ ] Si la regla `DOCKER-USER` no está: `iptables -I DOCKER-USER 1 -i eth0 -p tcp -m conntrack --ctstate NEW -m multiport --dports 3000,3001,3002,5678 -j DROP`. **Nunca `ufw reload` con contenedores arriba.**
- [ ] Si un contenedor no volvió: `docker start <nombre>`; n8n: `docker compose -f /opt/n8n/docker-compose.yml up -d`.

## 3. Reinicio de kernel (3 min)

```bash
/opt/mp-app/scripts/ops/check-services.sh pre-reboot && systemctl reboot
```

Espera ~2 minutos y reconecta. Si hay una sesión de Claude Code abierta, corre en el propio VPS y muere con el reinicio: retómala desde el historial de la extensión de VS Code (el 03-oct se retomó sin perder contexto).

## 4. Post-reboot (5 min)

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

- [ ] Todo coincide. Si la regla `DOCKER-USER` no está tras el reinicio, aplicar el comando del paso 2 y avisarme para revisar `/etc/ufw/after.rules`.

## 5. Verificación externa de puertos (check-host.net, 5 min)

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

- [ ] Los cuatro puertos de Docker en timeout y 22/80/443 abiertos. Si un puerto de Docker responde, aplicar la regla del paso 2 y repetir.

## 6. Verificación de n8n, Cotizador y Max Motors (5 min)

Desde tu laptop (o con `https://check-host.net/check-http?host=<URL>`):

```bash
for u in https://automation.isthmuscap.com/healthz https://cotizador.isthmuscap.com/ https://precios.maxmotorspa.com/; do
  curl -s -o /dev/null -m 15 -w "$u -> %{http_code}\n" "$u"; done
```

- [ ] n8n `200`; Cotizador `200/301/302/307/308`; Max Motors `200/301/302/307/308` (línea base del 02-oct: 307 y 307).
- [ ] Prueba funcional, no solo código HTTP: abrir el Cotizador y Max Motors en el navegador y cargar una cotización; en n8n, *Executions* debe mostrar actividad normal y los webhooks de las ejecuciones nuevas deben llegar.
- [ ] Pega en el chat la salida de `post-reboot`, el conteo de `DOCKER-USER` y las líneas de este paso. Con eso cierro el criterio de aceptación 2 del Brief 01 y lo anoto en el inventario.

## 7. Registro

Anota en `docs/INVENTARIO_ACTUAL.md` §0.1 (bitácora v1): fecha, "actualización de paquetes" y "reinicio de kernel", quién lo ejecutó y el resultado de `post-upgrade` y `post-reboot`. Esa anotación la hago yo si me pegas las salidas. R39 se cierra con esta ventana; R40 sigue "aceptado temporalmente" hasta que se decida la rotación.

## Si algo falla

| Síntoma | Acción |
|---|---|
| Un contenedor no está `Up` | `docker start <nombre>`. Cotizador: `docker compose -f /opt/cotizador-isthmus/docker-compose.yml up -d`; Max Motors: `docker compose -f /home/maxmotors/docker-compose.yml up -d`; n8n: `docker compose -f /opt/n8n/docker-compose.yml up -d`. |
| `DOCKER-USER` sin la regla DROP | `iptables -I DOCKER-USER 1 -i eth0 -p tcp -m conntrack --ctstate NEW -m multiport --dports 3000,3001,3002,5678 -j DROP` y avísame. **Nunca `ufw reload` con contenedores arriba.** |
| Caddy no responde en 443 | `systemctl status caddy`; `journalctl -u caddy -n 50`; `systemctl restart caddy`. |
| Un sitio da 502 | El contenedor detrás aún arranca; repetir `check-services.sh` en 1 min. |
| No entra por SSH | Consola Hetzner (Cloud Console → *Console*) con root; revisar `systemctl status ssh` y `/etc/ssh/sshd_config.d/`. |
| El kernel nuevo no arranca | El anterior sigue instalado: en GRUB (consola Hetzner) elegir el que corría antes de la ventana (al 03-oct-2026, `7.0.0-34`; verificar con `uname -r` en el pre-chequeo). |
| Daño que no se arregla con lo anterior | Restaurar el backup del servidor desde el panel de Hetzner (Backups) es el último recurso: revierte **todo** el disco al punto del backup. |
