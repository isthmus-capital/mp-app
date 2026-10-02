#!/usr/bin/env bash
# Sonda externa de /api/health (Brief 01). 3 fallos seguidos → mp-alert.sh. Estado en /var/lib/mp-health.
set -u
url="${1:-https://staging-mp.isthmuscap.com/api/health}"; st=/var/lib/mp-health; mkdir -p "$st"
code="$(curl -s -m 10 -o "$st/last-body.json" -w '%{http_code}' "$url" 2>/dev/null)"; code="${code:-000}"
date -u +%FT%TZ > "$st/last-run"; echo "$code" > "$st/last-code"
if [ "$code" = "200" ]; then echo 0 > "$st/failures"; date -u +%FT%TZ > "$st/last-success"; exit 0; fi
f=$(( $(cat "$st/failures" 2>/dev/null || echo 0) + 1 )); echo "$f" > "$st/failures"
echo "health $url -> $code (fallo $f)"
[ "$f" -ge 3 ] && /usr/local/bin/mp-alert.sh "health:$url:$code"
exit 1
