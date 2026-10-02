# Sistema de diseño FIC — Brief 00
<!-- Paquete: v5 — Brief 00 — 02-oct-2026 -->

## Estado

| Entregable | Estado | Dónde |
|---|---|---|
| Tokens de marca (§15) | Listo | `styles/tokens.css` |
| Preset de Tailwind | Listo (se cablea en Brief 02) | `styles/tailwind.preset.ts` |
| Página de prueba con logo, colores y tipografía | Lista | `docs/design/preview.html` |
| Capturas 390 px y 1440 px | Listas | `docs/design/capturas/preview-390.png`, `preview-1440.png` |
| 5 pantallas clave (HTML con tokens FIC) | **Hechas el 02-oct-2026; pendiente la revisión en celular y la aprobación de Gianclaudio** | Fuente en `pantallas/` (`index.html` + `01`…`05`, `base.css`), capturas `capturas/0N_*-390.png` y `-1440.png`, Artifact privado para el celular: https://claude.ai/artifact/RpN6nuHhQxpaG88QvxUiRt |
| Página de espera (Caddy 503 con marca, Brief 01) | Lista | `ops/caddy/placeholder/index.html`, capturas `capturas/placeholder-390.png` y `-1440.png` |

Pantallas pendientes (§15): wizard del cliente (paso de monto), línea de tiempo de la solicitud, estado de cuenta, carga de Base Diaria con reporte de errores, bandeja de admin. Cuando existan, se guardan aquí como `pantallas/NN_<pantalla>.html` (fuente) y `capturas/NN_<pantalla>-390.png` / `-1440.png` y cada brief de UI las referencia.

## Decisiones tomadas en el Brief 00

- **Colores**: los 8 tokens de §15 se copian literalmente. Se añaden cuatro neutros derivados (`--fic-blanco`, `--fic-gris-200`, `--fic-gris-300`, `--fic-texto`) como propuesta; Gianclaudio puede ajustarlos en la sesión de diseño.
- **Tipografía**: Manrope (geométrica, sobria, cifras tabulares con `font-feature-settings: "tnum"`), con fallback del sistema. **Propuesta sujeta a la sesión de diseño con Gianclaudio (cierre del Brief 01, §19).** Si cambia, se edita solo `--fic-font-sans`.
- **Estados del préstamo**: se usan los nombres de LoanDisk (Current, Due Today, Missed Repayment, Arrears, Past Maturity) con colores de la paleta FIC, no los de LoanDisk. El mapeo vive en `tokens.css` como `--estado-*` y en el preset como `estado.*`. Cambiar un color es cambiar un token.
- **Sin gradientes, sin sombras marcadas, un acento por pantalla**: una sola sombra permitida (`--fic-shadow-sm`); el preset define `theme.boxShadow` fuera de `extend` para retirar `shadow-md/lg/xl/2xl`. `fontSize` lleva tuplas con line-height para no perder los valores por defecto de Tailwind. Tamaño de toque mínimo `--fic-touch-min: 44px` (§9).
- **Fuente única de verdad**: los valores viven en `tokens.css`; el preset de Tailwind solo referencia variables. Por eso los modificadores de opacidad de Tailwind (`bg-fic-azul/50`) no aplican; si el Brief 02 los necesita, se exponen canales RGB.

## Cómo cablear en el Brief 02

1. `app/globals.css`: `@import "../styles/tokens.css";` antes de las directivas de Tailwind.
2. `tailwind.config.ts`:
   ```ts
   import ficPreset from "./styles/tailwind.preset";
   export default { presets: [ficPreset], content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"] };
   ```
3. Fuente: `next/font/google` con `Manrope` y `variable: "--font-manrope"`; `tokens.css` ya declara `--fic-font-sans: var(--font-manrope, "Manrope"), …`, así que no se redefine `--fic-font-sans` (evita que cascadas distintas cambien el fallback). Si Gianclaudio aprueba otra fuente, cambian `--font-manrope` y el fallback en `tokens.css`.
4. `StatusBadge` usa `estado.*` del preset; nunca hex en componentes.

## Cómo regenerar las capturas

Playwright 1.56 no soporta Ubuntu 26.04 (el VPS) y el MCP de Playwright no tiene Chrome instalado, así que en el Brief 00 las capturas se generaron con el Chromium del contenedor **Gotenberg** ya desplegado (ruta `chromium/screenshot/html`, enviando la página y sus dos recursos como archivos). El Brief 02 las regenera con Playwright en Docker (`mcr.microsoft.com/playwright`) a 390×844 y 1440×900.

```bash
# copia con rutas planas (tokens.css y logo.png junto al index.html)
sed -e 's#\.\./\.\./styles/tokens\.css#tokens.css#' -e 's#\.\./\.\./public/brand/logo\.png#logo.png#' docs/design/preview.html > /tmp/gb/index.html
cp styles/tokens.css /tmp/gb/tokens.css && cp public/brand/logo.png /tmp/gb/logo.png
curl -X POST http://127.0.0.1:3000/forms/chromium/screenshot/html \
  -F files=@/tmp/gb/index.html -F files=@/tmp/gb/tokens.css -F files=@/tmp/gb/logo.png \
  -F width=390 -F height=2300 -F format=png -F waitDelay=2s -o docs/design/capturas/preview-390.png
# idem con width=1440 height=1500 → preview-1440.png
```

La página solo contiene datos ficticios etiquetados "Ejemplo"; no hay PII en las capturas.

## Pantallas clave (Brief 01, 02-oct-2026)

| # | Pantalla | Viewport primario | Datos de ejemplo |
|---|---|---|---|
| 01 | Wizard del cliente, paso 3 (monto, plazo, ciclo, cuota) | 390 px | SO-00079 verificado en §4.6: $300, 24 %, 3 meses → 6 cuotas de $86.00, total $516.00, primer descuento 15-oct-2026 |
| 02 | Línea de tiempo de la solicitud | 390 px | Seis estados de §4.1.6; el actual con su acción (firmar) |
| 03 | Estado de cuenta | 390 px | 3 de 6 cuotas pagadas, saldo $258.00, tabla capital/interés |
| 04 | Carga de Base Diaria con reporte de errores | 1440 px | 412 filas, 7 errores con "qué pasa / cómo corregirlo" por columna del ANEXO A, 3 advertencias |
| 05 | Bandeja de administración | 1440 px | Filtros por estado (máquina §7), lista con plazo de respuesta, expediente con regla del % de descuento |

Decisiones de diseño tomadas (a confirmar en la sesión con Gianclaudio):
- **Un bloque azul FIC por pantalla** con la cifra protagonista (cuota, monto, saldo); tarjetas blancas con borde fino, sin sombras; azul claro solo para el estado activo. Manrope como única familia, cifras tabulares.
- **Tono**: formal en "tú" (igual que la página de espera). Alternativa: "usted" en todo el portal del cliente.
- **Interés visible en la cotización** ("24 % mensual sobre el monto") por transparencia; si FIC prefiere mostrar solo cuota y total, se quita una línea.
- **Plazos no habilitados** (6/9/12) se muestran deshabilitados con la nota "Por ahora tu empresa ofrece el plazo de 3 meses"; alternativa: ocultarlos.
- **Clientes en la bandeja** con iniciales y NUC; en la app real irá el nombre completo (PII solo para usuarios internos).
- **Token nuevo** `--fic-gris-400 #7F8A9C` para bordes de inputs y chips (3.5:1 sobre blanco, WCAG 1.4.11); añadido a `tokens.css` y al preset de Tailwind.

## Revisión de accesibilidad (Brief 01, WCAG 2.1 AA)

Contraste medido con los tokens reales: texto principal 16.0:1 sobre blanco y 14.8:1 sobre gris-100; texto secundario (`--fic-gris-600`, 14 px) 5.98:1 y 5.53:1; blanco sobre azul 11.0:1 (también con opacidad 85 %, 8.4:1); alerta 5.0:1 y error 6.6:1 sobre blanco. Tres contrastes no textuales fallaban y se corrigieron: segmento activo del avance (azul claro 2.4:1 → borde interior azul), bordes de inputs/chips/radios (gris-300 1.5:1 → `--fic-gris-400` 3.5:1) y punto de las insignias "en proceso" (azul claro 2.6:1 → azul). Marcado: `aria-selected` en filas de tabla sustituido por `aria-current`; `aria-current="step"` en el avance del wizard y en la línea de tiempo; urgencia del plazo con texto oculto "(urgente)" además del color; placeholder de búsqueda con `--fic-gris-600`; etiquetas visibles u ocultas para todos los campos; `caption` y `scope` en las tablas; foco visible con `--fic-azul-claro` (4.2:1 sobre azul); toque mínimo 44 px en botones, chips y radios; tablas anchas en contenedor con desplazamiento propio (la página nunca se desplaza en horizontal a 390 px). Pendiente: prueba con lector de pantalla (VoiceOver/TalkBack) y en celular real por Gianclaudio.

## Cómo regenerar las capturas de las pantallas

```bash
cd docs/design/pantallas && rm -rf /tmp/gb && mkdir -p /tmp/gb && cp ../../../styles/tokens.css ../../../public/brand/logo.png base.css /tmp/gb/
for f in 0*.html; do n="${f%.html}"
  sed -e 's#\.\./\.\./\.\./styles/tokens\.css#tokens.css#' -e 's#\.\./\.\./\.\./public/brand/logo\.png#logo.png#' "$f" > /tmp/gb/index.html
  for w in 390 1440; do h=$([ $w = 390 ] && echo 1700 || echo 1100)
    curl -s -X POST http://127.0.0.1:3000/forms/chromium/screenshot/html -F files=@/tmp/gb/index.html -F files=@/tmp/gb/tokens.css -F files=@/tmp/gb/base.css -F files=@/tmp/gb/logo.png -F width=$w -F height=$h -F format=png -F waitDelay=2s -o "../capturas/$n-$w.png"
  done; done
```

