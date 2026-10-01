# Brief 02 — Scaffold de la app y marca FIC
<!-- Paquete: v5 — 01-oct-2026 -->
**Modo:** auto · **Duración estimada:** medio día

## Objetivo
App Next.js 14 (App Router, TypeScript) corriendo en staging con la identidad visual de FIC y la estructura de los tres portales, sin lógica de negocio todavía.

## Tareas
1. Scaffold con App Router, TypeScript estricto, Tailwind, ESLint + Prettier, `pino` para logs estructurados (`request_id`, `nuc`, sin PII).
2. Rutas base: `/cliente`, `/afiliado`, `/admin`, `/afiliarse`, `/verificar/[uuid]`, `/api/health`. Layouts separados por portal.
3. **PWA**: `manifest.json` con el logo FIC en todos los tamaños, service worker (`next-pwa`), pantalla de instalación con instrucciones iOS/Android.
4. **Marca**: `styles/tokens.css` del Brief 00, componentes base (Button, Card, Input, Stepper, Timeline, StatusBadge con los estados de LoanDisk, Table, EmptyState, Toast). Usar el skill `frontend-design`; móvil primero en `/cliente`, escritorio primero en `/afiliado` y `/admin`.
5. Layout de adaptadores vacíos en `lib/{kyc,signing,core,banking,messaging,storage,rules}/` con sus interfaces TypeScript definidas (sin implementación).
6. Dockerfile multi-stage, servicio en `docker-compose.yml`, despliegue a staging.
7. Playwright configurado con capturas a 390 px y 1440 px.

## Criterio de aceptación
- `https://staging-mp.isthmuscap.com` carga los tres portales con la marca aplicada.
- La app se instala en un teléfono real y abre con el logo FIC.
- Capturas de Playwright coinciden con las pantallas aprobadas en `docs/design/`.
- `npm run lint` y `tsc --noEmit` limpios.
