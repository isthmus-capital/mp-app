# Brief 01 — Infraestructura y hardening del VPS
<!-- Paquete: v5 — 01-oct-2026 -->
**Modo:** aprobación manual · **Duración estimada:** medio día

## Contexto
VPS Hetzner CPX31 `5.78.214.136`, Ubuntu, Docker Compose + Caddy. Hoy corre como root y tiene actualizaciones pendientes. Ya aloja Cotizador (3001) y Max Motors (3002); **no se debe interrumpir ninguno**.

## Tareas
1. Usuario `deploy` no-root con sudo limitado; acceso por llave SSH; deshabilitar login root por SSH y password auth.
2. `fail2ban`, `ufw` (22, 80, 443), actualizaciones de seguridad con ventana de reinicio coordinada. — **Ventana ejecutada el 03-oct-2026** (apt upgrade con `docker-ce` 29.8.2 y reinicio a kernel 7.0.0-34; R39 cerrado; bitácora en INVENTARIO §0.1; kernel 7.0.0-38 queda pendiente, R45).
3. Backups: volúmenes Docker a almacenamiento externo (diario, retención 14 días) y verificación de los backups automáticos de Supabase. — **03-oct-2026:** el Storage Box externo queda aplazado sin fecha; los Backups de Hetzner (activos) cubren la pérdida del servidor y restic queda local con retención 14 días (runbook §6).
4. Caddy: `mp.isthmuscap.com` y `staging-mp.isthmuscap.com` (puerto 3013) con TLS, HSTS, cabeceras de seguridad y CSP base.
5. `docker-compose.yml` con el servicio `mp-app` (build, healthcheck, `restart: unless-stopped`, límites de memoria) y su `.env` fuera del repo.
6. `/api/health` que verifique DB, N8N, token Zoho y LoanDisk; alerta por WhatsApp al admin si falla.

## Criterio de aceptación
- Login root por SSH rechazado; `deploy` funciona desde VS Code Remote-SSH. — **Fase 1 cumplida 02-oct-2026** (contraseñas cerradas, root solo por llave, `deploy` funciona); el rechazo de root es la fase 2, cuando `deploy` opere Cotizador y Max Motors (plan Task 3b).
- Cotizador y Max Motors siguen respondiendo (verificar antes y después). — **Cumplido el 03-oct-2026** en la ventana de mantenimiento: 307/307 antes, entre pasos y después (`check-services.sh` pre-ventana, pre/post-upgrade y pre/post-reboot), cotizaciones cargadas en ambos sitios, n8n normal, puertos de Docker en timeout desde ~60 nodos de check-host.net (R39 cerrado).
- `https://staging-mp.isthmuscap.com` responde con certificado válido. — **Cumplido el 03-oct-2026** (también `mp.isthmuscap.com`): Let's Encrypt hasta el 01-ene-2027, HTTP/2 503 con la página de espera MP y cabeceras de seguridad; Cotizador, Max Motors y n8n sin cambios antes y después.
- Restauración de un backup probada en staging, con evidencia en la salida.
