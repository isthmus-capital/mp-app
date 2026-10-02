# Sistema de diseño FIC — Brief 00
<!-- Paquete: v5 — Brief 00 — 02-oct-2026 -->

## Estado

| Entregable | Estado | Dónde |
|---|---|---|
| Tokens de marca (§15) | Listo | `styles/tokens.css` |
| Preset de Tailwind | Listo (se cablea en Brief 02) | `styles/tailwind.preset.ts` |
| Página de prueba con logo, colores y tipografía | Lista | `docs/design/preview.html` |
| Capturas 390 px y 1440 px | Listas | `docs/design/capturas/preview-390.png`, `preview-1440.png` |
| 5 pantallas clave (HTML con tokens FIC) | **Pendiente** (cierre del Brief 01) | Decisión 02-oct-2026 (§19): se preparan en HTML con `styles/tokens.css` al cierre del Brief 01 y se revisan con **Gianclaudio** en celular (no con Diego); lo aprobado se congela aquí antes del Brief 02. |

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
