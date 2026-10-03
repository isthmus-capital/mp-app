# Brief 02 — Scaffold de la app y marca MP
<!-- Paquete: v5 — 01-oct-2026 · marca MP desde el 03-oct-2026 (Prompt Maestro §19.9 y §19.13) -->
**Modo:** auto · **Duración estimada:** medio día

## Objetivo
App Next.js 14 (App Router, TypeScript) corriendo en staging con la marca **MP Micropréstamos — Avanzamos Contigo** (logo `public/brand/mp-logo.png`, tokens `--mp-*` de `styles/tokens.css`, preset `mpPreset`) y FIC como respaldo ("Un producto de Financiera Isthmus Capital" en inicio de sesión, pie y documentos, Prompt Maestro §19.9), más la estructura de los tres portales, sin lógica de negocio todavía.

## Tareas
1. Scaffold con App Router, TypeScript estricto, Tailwind, ESLint + Prettier, `pino` para logs estructurados (`request_id`, `nuc`, sin PII).
2. Rutas base: `/cliente`, `/afiliado`, `/admin`, `/afiliarse`, `/verificar/[uuid]`, `/api/health`. Layouts separados por portal.
3. **PWA**: `public/manifest.webmanifest` con el logo MP en todos los tamaños (íconos provisionales de `public/icons/` recortados del PNG hasta recibir el SVG oficial), service worker (`next-pwa`), pantalla de instalación con instrucciones iOS/Android.
4. **Marca**: `styles/tokens.css` (tokens `--mp-*`) y `mpPreset` del Brief 00, logo MP en la cabecera de los tres portales y respaldo FIC en inicio de sesión y pie (§19.9); componentes base (Button, Card, Input, Stepper, Timeline, StatusBadge con los estados de LoanDisk, Table, EmptyState, Toast). Usar el skill `frontend-design`; móvil primero en `/cliente`, escritorio primero en `/afiliado` y `/admin`.
5. Layout de adaptadores vacíos en `lib/{kyc,signing,core,banking,messaging,storage,rules}/` con sus interfaces TypeScript definidas (sin implementación).
6. Dockerfile multi-stage, servicio en `docker-compose.yml`, despliegue a staging.
7. Playwright configurado con capturas a 390 px y 1440 px.
8. **Heredado del Brief 01** (INVENTARIO §13 ítem 1): `/api/health` según el contrato `docs/ops/HEALTH.md` (DB, N8N, token Zoho, LoanDisk) y, al existir la ruta, habilitar `mp-healthcheck.timer` en el VPS y probar la alerta por WhatsApp al admin (`mp-alert@healthcheck`).

## Criterio de aceptación
- `https://staging-mp.isthmuscap.com` carga los tres portales con la marca MP aplicada y el respaldo FIC en inicio de sesión y pie.
- La app se instala en un teléfono real y abre con el logo MP.
- Capturas de Playwright coinciden con las pantallas aprobadas en `docs/design/`.
- `npm run lint` y `tsc --noEmit` limpios.
