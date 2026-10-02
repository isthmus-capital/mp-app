#!/usr/bin/env bash
# Verifica que los servicios existentes del VPS respondan (Brief 01). Uso: check-services.sh [etiqueta]
set -u
label="${1:-check}"; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
out="/var/log/mp-ops/check-services.log"; mkdir -p "$(dirname "$out")"
check() { # nombre url codigos_aceptados
  local code; code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$2" || echo 000)"
  printf '%s %s %-10s %s -> %s (esperado %s)\n' "$ts" "$label" "$1" "$2" "$code" "$3" | tee -a "$out"
  [[ " $3 " == *" $code "* ]]
}
rc=0
check cotizador https://cotizador.isthmuscap.com/         "200 301 302 307 308" || rc=1
check maxmotors https://precios.maxmotorspa.com/          "200 301 302 307 308" || rc=1
check n8n       https://automation.isthmuscap.com/healthz "200" || rc=1
check gotenberg http://127.0.0.1:3000/health              "200" || rc=1
docker ps --format '{{.Names}} {{.Status}}' | sed "s/^/$ts $label /" | tee -a "$out"
exit $rc
