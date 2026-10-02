#!/usr/bin/env bash
# Capturas de las 5 pantallas clave y de la página de tokens a 390 px (móvil) y 1440 px (escritorio)
# con el Chromium del contenedor Gotenberg ya desplegado en el VPS (puerto 3000, solo localhost).
# Brief 02 las reemplaza por Playwright en Docker (mcr.microsoft.com/playwright).
# Uso: docs/design/tools/capturas.sh   (desde cualquier directorio)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
P="$ROOT/docs/design/pantallas"
OUT="$ROOT/docs/design/capturas"
GB="${GOTENBERG_URL:-http://127.0.0.1:3000}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp "$ROOT/styles/tokens.css" "$P/base.css" "$ROOT/public/brand/mp-logo.png" "$ROOT/public/brand/logo.png" "$TMP/"

shot() { # shot <html> <ancho> <alto> <salida>
  curl -sf -X POST "$GB/forms/chromium/screenshot/html" \
    -F files=@"$1" -F files=@"$TMP/tokens.css" -F files=@"$TMP/base.css" \
    -F files=@"$TMP/mp-logo.png" -F files=@"$TMP/logo.png" \
    -F width="$2" -F height="$3" -F format=png -F waitDelay=2s -o "$4"
  echo "$(basename "$4"): $(python3 -c "from PIL import Image;im=Image.open('$4');print('%dx%d'%im.size)")"
}

for f in "$P"/0*.html; do
  n="$(basename "${f%.html}")"
  sed -e 's#\.\./\.\./\.\./styles/tokens\.css#tokens.css#' \
      -e 's#\.\./\.\./\.\./public/brand/mp-logo\.png#mp-logo.png#' "$f" > "$TMP/index.html"
  shot "$TMP/index.html" 390 1700 "$OUT/$n-390.png"
  shot "$TMP/index.html" 1440 1100 "$OUT/$n-1440.png"
done

# Página de tokens (docs/design/preview.html)
sed -e 's#\.\./\.\./styles/tokens\.css#tokens.css#' \
    -e 's#\.\./\.\./public/brand/mp-logo\.png#mp-logo.png#' \
    -e 's#\.\./\.\./public/brand/logo\.png#logo.png#' "$ROOT/docs/design/preview.html" > "$TMP/index.html"
shot "$TMP/index.html" 390 2600 "$OUT/preview-390.png"
shot "$TMP/index.html" 1440 1700 "$OUT/preview-1440.png"

# Página de espera (Caddy 503, ops/caddy/placeholder) con su logo reducido
cp "$ROOT/ops/caddy/placeholder/mp-logo.png" "$TMP/mp-logo.png"
sed -e 's#"/mp-logo.png"#"mp-logo.png"#' "$ROOT/ops/caddy/placeholder/index.html" > "$TMP/index.html"
shot "$TMP/index.html" 390 844 "$OUT/placeholder-390.png"
shot "$TMP/index.html" 1440 900 "$OUT/placeholder-1440.png"
