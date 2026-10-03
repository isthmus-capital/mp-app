# Brief 01 — Infraestructura y hardening del VPS
<!-- Paquete: v5 — 01-oct-2026 -->
**Modo:** aprobación manual · **Duración estimada:** medio día

**Estado: CERRADO el 03-oct-2026** por decisión de Gianclaudio. Criterios 2, 3 y 4 cumplidos; criterio 1 en fase 1 (la fase 2 queda con disparador). Lo que quedó fuera vive en **INVENTARIO §13 "Infra — pendientes post-Brief 01"**, cada ítem con su disparador.

**Revisión final de rama (03-oct-2026)**, revisor fresco (subagente) sobre `6e8c0c8..d9c68eb` (20 commits, 72 archivos). Veredicto: *con correcciones*. Sin deriva entre el repo y el host: los 16 artefactos instalados son idénticos byte a byte, con modos y dueños correctos. TLS, cabeceras, `sshd -T`, `DOCKER-USER`, fail2ban, el timer y el compose se verificaron en vivo. Hallazgos y destino:

| Hallazgo | Severidad | Estado al cierre |
|---|---|---|
| C1. `mp-restore-test.sh` y `mp-backup.sh` eligen el snapshot del grupo más antiguo; la prueba sale con 0 aunque falle | Crítico | Corregido, instalado y probado el 03-oct 03:46 UTC (`rc=0`, snapshot `01b5731b`) |
| I1. `restic snapshots *` / `restic stats *` con `NOPASSWD` admiten `--password-command` (comando como root) | Importante | Aprobado; wrapper sin argumentos en el repo, `visudo` OK; falta instalarlo (§13 ítem 9) |
| I2. Reglas `deny` de n8n sin `Edit`/`Write` ni `docker logs/cp/volume/run` | Importante | Hecho. Además se descubrió que `Read(/opt/n8n/**)` no protegía nada: corregido a `//opt/n8n/**` (§13 ítem 10) |
| I3. Evidencia del criterio 4 sin registrar | Importante | Registrada en INVENTARIO §0.1 |
| I4. El runbook decía que Claude Code corre como `deploy`; corre como `root` | Importante | Decidido: `deploy` desde el Brief 02 (CLAUDE.md); traspaso en §13 ítem 11 |
| I5. `Environment=HOME=/root` en `mp-backup.service` sin instalar | Importante | Instalado y cargado el 03-oct |
| I6. `__pycache__` sin ignorar | Importante | Corregido (`.gitignore`) |
| M1, M6, M7, M8. Textos del runbook, de la ventana y de diseño | Menor | Corregidos |
| M2–M5, M11, M13. Mejoras de scripts y del host | Menor | §13 ítem 12 |
| M9, M10, M12. CSP con nonces, `wget` y montajes en la imagen, red `n8n_default` | Menor | Brief 02 (§13 ítem 13) |

## Contexto
VPS Hetzner CPX31 `5.78.214.136`, Ubuntu, Docker Compose + Caddy. Hoy corre como root y tiene actualizaciones pendientes. Ya aloja Cotizador (3001) y Max Motors (3002); **no se debe interrumpir ninguno**.

## Tareas
1. Usuario `deploy` no-root con sudo limitado; acceso por llave SSH; deshabilitar login root por SSH y password auth. — **Fase 1 hecha el 02-oct-2026** (`deploy` con sudoers `MP_OPS`, llave SSH, `PasswordAuthentication no`, root solo por llave); el rechazo de root (fase 2, Task 3b) pasa a INVENTARIO §13 ítem 2.
2. `fail2ban`, `ufw` (22, 80, 443), actualizaciones de seguridad con ventana de reinicio coordinada. — **Ventana ejecutada el 03-oct-2026** (apt upgrade con `docker-ce` 29.8.2 y reinicio a kernel 7.0.0-34; R39 cerrado; bitácora en INVENTARIO §0.1; kernel 7.0.0-38 queda pendiente, R45).
3. Backups: volúmenes Docker a almacenamiento externo (diario, retención 14 días) y verificación de los backups automáticos de Supabase. — **03-oct-2026:** el Storage Box externo queda aplazado sin fecha; los Backups de Hetzner (activos) cubren la pérdida del servidor y restic queda local con retención 14 días (runbook §6). Backup diario con restic activo desde el 02-oct (timer 08:00 UTC); la primera corrida con n8n pasa a INVENTARIO §13 ítem 3; Supabase Pro y proyecto `isthmus-mp` creados el 02-oct, primer backup diario por verificar (§13 ítem 7).
4. Caddy: `mp.isthmuscap.com` y `staging-mp.isthmuscap.com` (puerto 3013) con TLS, HSTS, cabeceras de seguridad y CSP base. — **Hecho el 03-oct-2026** (snippet v3 `ops/caddy/Caddyfile.mp.snippet`, Let's Encrypt hasta el 01-ene-2027, página de espera 503 con marca MP).
5. `docker-compose.yml` con el servicio `mp-app` (build, healthcheck, `restart: unless-stopped`, límites de memoria) y su `.env` fuera del repo. — **Hecho el 02-oct-2026** (`docker-compose.yml` con `mp-app` y `mp-app-staging` en `127.0.0.1`; `/etc/mp-app/{staging,production}.env` 640 root:deploy).
6. `/api/health` que verifique DB, N8N, token Zoho y LoanDisk; alerta por WhatsApp al admin si falla. — Contrato en `docs/ops/HEALTH.md` y sonda `mp-healthcheck.sh` instalada con el timer deshabilitado; la ruta y la alerta se entregan en el **Brief 02** (INVENTARIO §13 ítem 1).

## Criterio de aceptación
- Login root por SSH rechazado; `deploy` funciona desde VS Code Remote-SSH. — **Fase 1 cumplida 02-oct-2026** (contraseñas cerradas, root solo por llave, `deploy` funciona); el rechazo de root es la fase 2, cuando `deploy` opere Cotizador y Max Motors (plan Task 3b) → INVENTARIO §13 ítem 2.
- Cotizador y Max Motors siguen respondiendo (verificar antes y después). — **Cumplido el 03-oct-2026** en la ventana de mantenimiento: 307/307 antes, entre pasos y después (`check-services.sh` pre-ventana, pre/post-upgrade y pre/post-reboot), cotizaciones cargadas en ambos sitios, n8n normal, puertos de Docker en timeout desde ~60 nodos de check-host.net (R39 cerrado).
- `https://staging-mp.isthmuscap.com` responde con certificado válido. — **Cumplido el 03-oct-2026** (también `mp.isthmuscap.com`): Let's Encrypt hasta el 01-ene-2027, HTTP/2 503 con la página de espera MP y cabeceras de seguridad; Cotizador, Max Motors y n8n sin cambios antes y después.
- Restauración de un backup probada en staging, con evidencia en la salida. — **Cumplido el 03-oct-2026 03:46 UTC.** La primera corrida (02-oct ~03:57 UTC, snapshot `a2d407f6`) no dejó la salida registrada, y la revisión de cierre encontró que el script elegía mal el snapshot y salía con 0 aunque fallara. Con el script corregido e instalado, Gianclaudio la repitió: `RESTORE volumen OK (snapshot 01b5731b)`, `RESTORE Caddyfile OK`, `rc=0`; `01b5731b` es el snapshot más reciente del repositorio (evidencia completa en INVENTARIO §0.1). Queda como prueba mensual (`RUNBOOK_VPS.md` §6).
