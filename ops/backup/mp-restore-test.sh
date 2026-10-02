#!/usr/bin/env bash
# Prueba de restauración (Brief 01, criterio de aceptación 4): volumen con contenido conocido → backup → borrar → restaurar → comparar SHA-256; y diff del Caddyfile.
set -euo pipefail
set -a; . /etc/mp-backup/restic.env; set +a
vol=mp-restore-test; work="$(mktemp -d)"
docker volume rm -f "$vol" >/dev/null 2>&1 || true
docker volume create "$vol" >/dev/null
docker run --rm -v "$vol":/data alpine:3.20 sh -c 'echo "FIC restore test $(date -u)" > /data/marker.txt; dd if=/dev/urandom of=/data/blob.bin bs=1M count=5 status=none'
docker run --rm -v "$vol":/data:ro alpine:3.20 sh -c 'cd /data && sha256sum marker.txt blob.bin' > "$work/before.sha"
/usr/local/bin/mp-backup.sh
docker volume rm "$vol" >/dev/null
snap="$(restic snapshots --json --latest 1 --tag daily | python3 -c 'import json,sys;print(json.load(sys.stdin)[0]["short_id"])')"
restic restore "$snap" --target "$work/restore" --include "/var/backups/mp-stage/vol-$vol.tgz" --include /etc/caddy/Caddyfile --quiet
docker volume create "$vol" >/dev/null
docker run --rm -v "$vol":/data -v "$work/restore/var/backups/mp-stage":/src:ro alpine:3.20 tar xzf "/src/vol-$vol.tgz" -C /data
docker run --rm -v "$vol":/data:ro alpine:3.20 sh -c 'cd /data && sha256sum marker.txt blob.bin' > "$work/after.sha"
diff "$work/before.sha" "$work/after.sha" && echo "RESTORE volumen OK (snapshot $snap)"
diff /etc/caddy/Caddyfile "$work/restore/etc/caddy/Caddyfile" && echo "RESTORE Caddyfile OK"
docker volume rm "$vol" >/dev/null; rm -rf "$work"
