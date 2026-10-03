#!/usr/bin/env bash
# Prueba de restauración (Brief 01, criterio de aceptación 4): volumen con contenido conocido → backup → borrar → restaurar → comparar SHA-256; y diff del Caddyfile.
# Sale con 1 si alguna comparación falla y limpia el volumen y la carpeta temporal en cualquier caso (revisión de cierre del Brief 01, 03-oct-2026).
set -euo pipefail
set -a; . /etc/mp-backup/restic.env; set +a
vol=mp-restore-test; work="$(mktemp -d)"
cleanup() { docker volume rm -f "$vol" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
docker volume rm -f "$vol" >/dev/null 2>&1 || true
docker volume create "$vol" >/dev/null
docker run --rm -v "$vol":/data alpine:3.20 sh -c 'echo "FIC restore test $(date -u)" > /data/marker.txt; dd if=/dev/urandom of=/data/blob.bin bs=1M count=5 status=none'
docker run --rm -v "$vol":/data:ro alpine:3.20 sh -c 'cd /data && sha256sum marker.txt blob.bin' > "$work/before.sha"
/usr/local/bin/mp-backup.sh
docker volume rm "$vol" >/dev/null
# El más reciente de verdad: `--latest 1` devuelve uno por grupo (host, rutas) y el JSON va del más antiguo al más nuevo.
snap="$(restic snapshots --json --tag daily | python3 -c 'import json,sys;s=json.load(sys.stdin);print(max(s,key=lambda x:x["time"])["short_id"])')"
restic restore "$snap" --target "$work/restore" --include "/var/backups/mp-stage/vol-$vol.tgz" --include /etc/caddy/Caddyfile --quiet
docker volume create "$vol" >/dev/null
docker run --rm -v "$vol":/data -v "$work/restore/var/backups/mp-stage":/src:ro alpine:3.20 tar xzf "/src/vol-$vol.tgz" -C /data
docker run --rm -v "$vol":/data:ro alpine:3.20 sh -c 'cd /data && sha256sum marker.txt blob.bin' > "$work/after.sha"
ok=0
if diff "$work/before.sha" "$work/after.sha"; then echo "RESTORE volumen OK (snapshot $snap)"; else echo "RESTORE volumen FALLO (snapshot $snap)"; ok=1; fi
if diff /etc/caddy/Caddyfile "$work/restore/etc/caddy/Caddyfile"; then echo "RESTORE Caddyfile OK"; else echo "RESTORE Caddyfile FALLO"; ok=1; fi
exit "$ok"
