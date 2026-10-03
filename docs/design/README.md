# Sistema de diseño MP Micropréstamos — Briefs 00 y 01
<!-- Paquete: v6 — marca MP — 02-oct-2026 -->

## Marca (decisión 02-oct-2026, Prompt Maestro §19.9)

- **El producto es "MP Micropréstamos — Avanzamos Contigo"**: logo `public/brand/mp-logo.png` (PNG 2172×724, RGBA con fondo transparente real: 64 % de píxeles transparentes, bordes limpios). Se usa en la cabecera de los tres portales, en la PWA, en los correos y en los PDF.
- **FIC es el respaldo**: `public/brand/logo.png` (logo vertical de Isthmus Capital, intacto) aparece solo en inicio de sesión, pie de página y documentos con el texto **"Un producto de Financiera Isthmus Capital"**. En los pies de las pantallas va solo el texto (el logo vertical no se lee a 24 px).
- **Colores medidos del archivo real** (mediana de cada grupo de píxeles opacos, `scripts`/sesión 02-oct): azul marino `#02265E` (14.6:1 sobre blanco) y azul medio `#1B70DE` (4.75:1). Los aproximados que traía el brief (`#03285F`, `#1C72DF`) difieren en 1–2 unidades por canal; se adoptan los medidos.
- **Tokens renombrados de `--fic-*` a `--mp-*`** (y el preset de Tailwind de `fic.*` a `mp.*`, `mpPreset`). Se hizo ahora porque todavía no hay código de app que los consuma (Brief 02); FIC no tiene tokens propios.
- **Íconos de la PWA provisionales** recortados del PNG (`public/icons/`, `public/favicon.ico`, `public/manifest.webmanifest`; receta en `scripts/brand/make-icons.py` y notas en `public/icons/README.md`). Se reemplazan cuando llegue el SVG oficial.

### Paleta y escalas (styles/tokens.css)

| Token | Valor | Uso | Contraste |
|---|---|---|---|
| `--mp-azul` | `#02265E` | primario: cabeceras, botones, bloque de la cifra, enlaces | 14.6:1 sobre blanco, 13.5:1 sobre gris-100 |
| `--mp-azul-900` | `#011A42` | hover/pressed del primario, estado Past Maturity | 17.1:1 |
| `--mp-azul-50` | `#EAF0FA` | tinte: fila seleccionada, fondos suaves | texto principal 14.0:1 y secundario 5.2:1 encima |
| `--mp-acento` | `#1B70DE` | estado activo, anillo de foco, gráficos, Due Today | 4.75:1 sobre blanco (AA como texto solo sobre blanco), 4.4:1 sobre gris-100 (solo no textual), 3.1:1 sobre azul |
| `--mp-acento-700` | `#1457B3` | acento usado como texto sobre cualquier fondo claro | 6.9:1 blanco, 6.4:1 gris-100 |
| `--mp-acento-100` | `#DCEAFC` | tinte del acento: halo del paso actual | texto 13.1:1 encima |
| `--mp-acento-claro` | `#8DC0F7` | acento sobre superficies azules (foco dentro de la banda) | 7.6:1 sobre azul; nunca sobre blanco (1.9:1) |
| `--mp-exito` / `--mp-alerta` / `--mp-error` | `#1F7A4D` / `#B45309` / `#B42318` | semánticos (sin cambio) | 5.3 / 5.0 / 6.6:1 |
| neutros | sin cambio (`--mp-gris-100…600`, `--mp-texto #16213A`) | fondos, bordes, texto | ver auditoría |

Reglas: un acento por pantalla; el acento nunca sustituye al primario en botones ni enlaces; los estados usan los semánticos. Sin gradientes, una sola sombra (`--mp-shadow-sm`), toque mínimo 44 px.

## Estado

| Entregable | Estado | Dónde |
|---|---|---|
| Tokens de marca MP (§15) | Listos (02-oct-2026) | `styles/tokens.css` |
| Preset de Tailwind | Listo (se cablea en Brief 02) | `styles/tailwind.preset.ts` |
| Página de prueba con logos, colores, tipografía e íconos | Lista | `docs/design/preview.html`, capturas `capturas/preview-390.png` y `-1440.png` |
| 5 pantallas clave (HTML con tokens MP) | **Regeneradas con la marca MP el 02-oct-2026; pendiente la revisión en celular y la aprobación de Gianclaudio** | Fuente en `pantallas/` (`index.html` + `01`…`05`, `base.css`), capturas `capturas/0N_*-390.png` y `-1440.png`, Artifact privado para el celular: https://claude.ai/artifact/RpN6nuHhQxpaG88QvxUiRt |
| Página de espera (Caddy 503 con marca MP, Brief 01) | En producción desde el 03-oct-2026 en `mp.` y `staging-mp.isthmuscap.com` (`/var/www/mp-placeholder`) | `ops/caddy/placeholder/index.html` + `mp-logo.png`, capturas `capturas/placeholder-390.png` y `-1440.png` |
| Íconos PWA y favicon | **Provisionales** (recorte del PNG) | `public/icons/`, `public/favicon.ico`, `public/manifest.webmanifest` |

## Decisiones tomadas en el Brief 00 (vigentes salvo lo renombrado)

- **Tipografía**: Manrope (geométrica, sobria, cifras tabulares con `font-feature-settings: "tnum"`), con fallback del sistema. **Propuesta sujeta a la revisión en celular con Gianclaudio.** Si cambia, se edita solo `--mp-font-sans`.
- **Estados del préstamo**: se usan los nombres de LoanDisk (Current, Due Today, Missed Repayment, Arrears, Past Maturity) con colores de la paleta MP. El mapeo vive en `tokens.css` como `--estado-*` y en el preset como `estado.*`. Cambiar un color es cambiar un token.
- **Sin gradientes, sin sombras marcadas, un acento por pantalla**: una sola sombra permitida (`--mp-shadow-sm`); el preset define `theme.boxShadow` fuera de `extend` para retirar `shadow-md/lg/xl/2xl`. `fontSize` lleva tuplas con line-height para no perder los valores por defecto de Tailwind. Tamaño de toque mínimo `--mp-touch-min: 44px` (§9).
- **Fuente única de verdad**: los valores viven en `tokens.css`; el preset de Tailwind solo referencia variables. Por eso los modificadores de opacidad de Tailwind (`bg-mp-azul/50`) no aplican; si el Brief 02 los necesita, se exponen canales RGB.

## Cómo cablear en el Brief 02

1. `app/globals.css`: `@import "../styles/tokens.css";` antes de las directivas de Tailwind.
2. `tailwind.config.ts`:
   ```ts
   import mpPreset from "./styles/tailwind.preset";
   export default { presets: [mpPreset], content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"] };
   ```
3. Fuente: `next/font/google` con `Manrope` y `variable: "--font-manrope"`; `tokens.css` ya declara `--mp-font-sans: var(--font-manrope, "Manrope"), …`, así que no se redefine `--mp-font-sans`. Si Gianclaudio aprueba otra fuente, cambian `--font-manrope` y el fallback en `tokens.css`.
4. `StatusBadge` usa `estado.*` del preset; nunca hex en componentes.
5. Cabecera: `mp-logo.png` dentro de una caja blanca sobre la banda azul (el PNG es transparente y el azul del logo desaparecería sobre la banda). Pie de cada portal y pantalla de inicio de sesión: "Un producto de Financiera Isthmus Capital" (en el login, además, el logo FIC pequeño).
6. Manifest e íconos: `app/manifest.ts` con los valores de `public/manifest.webmanifest`; `<link rel="icon" href="/favicon.ico">` y `apple-touch-icon` en `app/layout.tsx`.

## Pantallas clave (Brief 01, 02-oct-2026)

| # | Pantalla | Viewport primario | Datos de ejemplo |
|---|---|---|---|
| 01 | Wizard del cliente, paso 3 (monto, plazo, ciclo, cuota) | 390 px | SO-00079 verificado en §4.6: $300, 24 %, 3 meses → 6 cuotas de $86.00, total $516.00, primer descuento 15-oct-2026 |
| 02 | Línea de tiempo de la solicitud | 390 px | Seis estados de §4.1.6; el actual con su acción (firmar) |
| 03 | Estado de cuenta | 390 px | 3 de 6 cuotas pagadas, saldo $258.00, tabla capital/interés |
| 04 | Carga de Base Diaria con reporte de errores | 1440 px | 412 filas, 7 errores con "qué pasa / cómo corregirlo" por columna del ANEXO A, 3 advertencias |
| 05 | Bandeja de administración | 1440 px | Filtros por estado (máquina §7), lista con plazo de respuesta, expediente con regla del % de descuento |

Decisiones de diseño tomadas (a confirmar en la revisión con Gianclaudio):
- **Un bloque azul MP por pantalla** con la cifra protagonista (cuota, monto, saldo); tarjetas blancas con borde fino, sin sombras; el acento solo para el estado activo y el foco. Manrope como única familia, cifras tabulares.
- **Logo en cabecera a 40 px de alto** dentro de una caja blanca; a esa altura el texto "Micropréstamos" del logo es pequeño en el celular. Alternativa: 48 px, o solo el símbolo + "MP" en móvil cuando exista el SVG.
- **Tono**: formal en "tú" (igual que la página de espera). Alternativa: "usted" en todo el portal del cliente.
- **Interés visible en la cotización** ("24 % mensual sobre el monto") por transparencia; si FIC prefiere mostrar solo cuota y total, se quita una línea.
- **Plazos no habilitados** (6/9/12) se muestran deshabilitados con la nota "Por ahora tu empresa ofrece el plazo de 3 meses"; alternativa: ocultarlos.
- **Clientes en la bandeja** con iniciales y NUC; en la app real irá el nombre completo (PII solo para usuarios internos).
- **Pie de respaldo** "Un producto de Financiera Isthmus Capital." al final de cada pantalla (`.respaldo`), en texto secundario de 12 px.

## Auditoría de accesibilidad (WCAG 2.1 AA) — marca MP, 02-oct-2026

Contraste medido con los tokens reales por `docs/design/tools/contraste.py` (25 combinaciones, 0 fallos):

| Elemento | Primer plano | Fondo | Medido | Mínimo | Resultado |
|---|---|---|---|---|---|
| Texto principal sobre blanco (tarjetas) | `#16213A` | `#FFFFFF` | 16.00:1 | 4.5:1 | Pasa |
| Texto principal sobre gris-100 (página) | `#16213A` | `#F4F6FA` | 14.79:1 | 4.5:1 | Pasa |
| Texto secundario 14 px sobre blanco | `#5B6472` | `#FFFFFF` | 5.98:1 | 4.5:1 | Pasa |
| Texto secundario 14 px sobre gris-100 | `#5B6472` | `#F4F6FA` | 5.53:1 | 4.5:1 | Pasa |
| Texto secundario sobre azul-50 (fila seleccionada) | `#5B6472` | `#EAF0FA` | 5.22:1 | 4.5:1 | Pasa |
| Enlaces y botón secundario (azul sobre blanco) | `#02265E` | `#FFFFFF` | 14.57:1 | 4.5:1 | Pasa |
| Blanco sobre azul (banda, botón, bloque de cifra) | `#FFFFFF` | `#02265E` | 14.57:1 | 4.5:1 | Pasa |
| Blanco al 85 % sobre azul (etiquetas del bloque) | `#D9DEE7` | `#02265E` | 10.79:1 | 4.5:1 | Pasa |
| Borde del chip "Datos de ejemplo" (blanco 55 %) sobre azul | `#8D9DB7` | `#02265E` | 5.30:1 | 3.0:1 | Pasa |
| Blanco sobre azul-900 (pressed) | `#FFFFFF` | `#011A42` | 17.10:1 | 4.5:1 | Pasa |
| Acento como texto sobre blanco | `#1B70DE` | `#FFFFFF` | 4.75:1 | 4.5:1 | Pasa |
| Acento-700 como texto sobre gris-100 | `#1457B3` | `#F4F6FA` | 6.38:1 | 4.5:1 | Pasa |
| Alerta (texto "vence") sobre blanco | `#B45309` | `#FFFFFF` | 5.02:1 | 4.5:1 | Pasa |
| Error (texto "vencido", cifra) sobre blanco | `#B42318` | `#FFFFFF` | 6.57:1 | 4.5:1 | Pasa |
| Éxito (punto de insignia) sobre blanco | `#1F7A4D` | `#FFFFFF` | 5.32:1 | 3.0:1 | Pasa |
| Anillo de foco (acento) sobre gris-100 | `#1B70DE` | `#F4F6FA` | 4.39:1 | 3.0:1 | Pasa |
| Anillo de foco (acento) sobre blanco | `#1B70DE` | `#FFFFFF` | 4.75:1 | 3.0:1 | Pasa |
| Anillo de foco en la banda (acento-claro sobre azul) | `#8DC0F7` | `#02265E` | 7.64:1 | 3.0:1 | Pasa |
| Segmento actual del avance (acento sobre gris-100) | `#1B70DE` | `#F4F6FA` | 4.39:1 | 3.0:1 | Pasa |
| Segmentos hechos del avance (azul sobre gris-100) | `#02265E` | `#F4F6FA` | 13.47:1 | 3.0:1 | Pasa |
| Bordes de inputs, chips y radios (gris-400 sobre blanco) | `#7F8A9C` | `#FFFFFF` | 3.49:1 | 3.0:1 | Pasa |
| Punto de insignia "en proceso" (azul sobre blanco) | `#02265E` | `#FFFFFF` | 14.57:1 | 3.0:1 | Pasa |
| Punto de insignia "Due Today" (acento sobre blanco) | `#1B70DE` | `#FFFFFF` | 4.75:1 | 3.0:1 | Pasa |
| Punto de la línea de tiempo hecho (azul sobre gris-100) | `#02265E` | `#F4F6FA` | 13.47:1 | 3.0:1 | Pasa |
| Radio elegido: borde azul sobre blanco | `#02265E` | `#FFFFFF` | 14.57:1 | 3.0:1 | Pasa |

Cambios respecto a la auditoría anterior (paleta FIC): el segmento actual del avance ya no necesita borde interior (el acento contrasta 4.4:1 sobre la página, antes 2.4:1); el halo del paso actual de la línea de tiempo pasa de un `rgba` escrito a mano al token `--mp-acento-100`; el anillo de foco usa `--mp-acento` sobre fondos claros y `--mp-acento-claro` dentro de la banda azul (antes un solo color, 4.2:1 sobre azul y 2.6:1 sobre blanco). El acento solo se usa como texto sobre blanco; sobre gris-100 se usa `--mp-acento-700`.

Marcado y operación sin cambios desde el Brief 01: `aria-current` en filas, pasos y línea de tiempo; urgencia con texto oculto "(urgente)" además del color; etiquetas visibles u ocultas en todos los campos; `caption` y `scope` en tablas; toque mínimo 44 px; tablas anchas con desplazamiento propio (sin desplazamiento horizontal de la página a 390 px). Las imágenes del logo llevan `alt="MP Micropréstamos"`. Pendiente: prueba con lector de pantalla (VoiceOver/TalkBack) y en celular real por Gianclaudio.

## Cómo regenerar

- Capturas (5 pantallas, página de tokens y página de espera, 390 y 1440 px, con el Chromium de Gotenberg del VPS): `docs/design/tools/capturas.sh`. Brief 02 las pasa a Playwright en Docker (`mcr.microsoft.com/playwright`); Playwright 1.56 no soporta Ubuntu 26.04 y el MCP de Playwright no tiene Chrome.
- Auditoría de contraste: `python3 docs/design/tools/contraste.py` (sale con error si una combinación falla).
- Artifact del celular: `python3 docs/design/tools/build_artifact.py salida.html` y publicar sobre la misma URL con `mp-logo.png` y `logo.png` reducidos (480 px y 240 px de ancho).
- Íconos: `python3 scripts/brand/make-icons.py`.

Las páginas solo contienen datos ficticios etiquetados "Ejemplo"; no hay PII en las capturas.
