# Íconos de la PWA — PROVISIONALES

Recortados del PNG del logo (`public/brand/mp-logo.png`: símbolo de la mano con el círculo y el mapa de Panamá, sin la barra ni el texto) con `scripts/brand/make-icons.py` el 02-oct-2026. **Se reemplazan por exportaciones del SVG oficial cuando Gianclaudio lo reciba**; hasta entonces no se retocan a mano.

| Archivo | Uso | Fondo | Símbolo |
|---|---|---|---|
| `icon-192.png`, `icon-512.png` | `purpose: any` en `public/manifest.webmanifest` | blanco | 84 % del ancho |
| `icon-maskable-192.png`, `icon-maskable-512.png` | `purpose: maskable` (Android recorta en círculo o squircle) | blanco | 62 % del ancho, dentro de la zona segura del 80 % |
| `apple-touch-icon.png` | iOS "Añadir a inicio" (180 px, sin transparencia) | blanco | 84 % |
| `../favicon.ico` | pestaña del navegador (16, 32 y 48 px) | blanco | 92 % |

Colores del manifest: `theme_color #02265E` (`--mp-azul`), `background_color #FFFFFF`. En el Brief 02 el manifest pasa a `app/manifest.ts` con estos mismos valores y los `<link rel="icon">`/`apple-touch-icon` van en `app/layout.tsx`.
