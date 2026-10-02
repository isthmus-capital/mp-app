#!/usr/bin/env bash
# Backup diario del VPS a restic (Brief 01). Lo ejecuta systemd (mp-backup.service) como root. Retención 14 días.
# D3: n8n (volúmenes, dump de Postgres y /opt/n8n) se incluye cuando MP_BACKUP_INCLUDE_N8N=1 en /etc/mp-backup/restic.env.
# MP_BACKUP_INCLUDE_N8N_OVERRIDE=0 en el entorno permite una corrida de validación sin tocar n8n (la usa la sesión de Claude Code).
set -euo pipefail
set -a; . /etc/mp-backup/restic.env; set +a
INCLUDE_N8N="${MP_BACKUP_INCLUDE_N8N_OVERRIDE:-${MP_BACKUP_INCLUDE_N8N:-1}}"
STAGE=/var/backups/mp-stage
log(){ printf '%s mp-backup %s\n' "$(date -u +%FT%TZ)" "$*"; }
cleanup(){ rm -rf "$STAGE"; }
trap cleanup EXIT
rm -rf "$STAGE"; install -d -m 700 "$STAGE"

# 1) Volúmenes Docker con nombre (los anónimos de 64 hex se omiten), copiados en caliente y solo lectura.
for vol in $(docker volume ls -q | grep -Ev '^[0-9a-f]{64}$'); do
  case "$vol" in n8n_*) [ "$INCLUDE_N8N" = "1" ] || { log "omitido $vol (n8n excluido)"; continue; };; esac
  docker run --rm -v "$vol":/data:ro -v "$STAGE":/backup alpine:3.20 tar czf "/backup/vol-$vol.tgz" -C /data .
  log "volumen $vol → vol-$vol.tgz ($(du -h "$STAGE/vol-$vol.tgz" | cut -f1))"
done

# 2) Dump lógico consistente del Postgres de n8n (D3). Lo ejecuta systemd/Gianclaudio, nunca la sesión de Claude Code.
N8N_PATHS=()
if [ "$INCLUDE_N8N" = "1" ]; then
  docker exec "$N8N_PG_CONTAINER" pg_dumpall -U "$N8N_PG_USER" | gzip -1 > "$STAGE/n8n-pg_dumpall.sql.gz"
  log "dump n8n → n8n-pg_dumpall.sql.gz ($(du -h "$STAGE/n8n-pg_dumpall.sql.gz" | cut -f1))"
  N8N_PATHS=(/opt/n8n)
fi

# 3) Configuración del host y proyecto. restic cifra todo (incluye .env y compose con secretos).
#    Solo se pasan rutas existentes: una ruta ausente haría fallar restic (exit 3) y abortar el backup.
WANT=("$STAGE" /opt/mp-app /etc/mp-app /etc/mp-backup /etc/caddy /var/www/mp-placeholder
  /etc/ssh/sshd_config.d /etc/sudoers.d /etc/fail2ban/jail.local /etc/ufw/after.rules
  /etc/systemd/system/mp-backup.service /etc/systemd/system/mp-backup.timer /etc/systemd/system/mp-alert@.service
  /etc/systemd/system/mp-healthcheck.service /etc/systemd/system/mp-healthcheck.timer /usr/local/bin/mp-backup.sh
  /usr/local/bin/mp-restore-test.sh /usr/local/bin/mp-alert.sh /usr/local/bin/mp-healthcheck.sh
  /root/backups /opt/cotizador-isthmus/docker-compose.yml /opt/cotizador-isthmus/.env.production /home/maxmotors/docker-compose.yml)
[ ${#N8N_PATHS[@]} -gt 0 ] && WANT+=("${N8N_PATHS[@]}")
PATHS=(); for p in "${WANT[@]}"; do if [ -e "$p" ]; then PATHS+=("$p"); else log "aviso: no existe $p (omitido)"; fi; done
EXCL=(--exclude /opt/mp-app/node_modules --exclude /opt/mp-app/.next --exclude '/opt/n8n/*.dump')
# Con n8n excluido tampoco se copian los dumps manuales de su base que viven en /root/backups.
[ "$INCLUDE_N8N" = "1" ] || EXCL+=(--exclude '/root/backups/n8n-*')
restic backup --quiet --tag daily "${EXCL[@]}" "${PATHS[@]}"
restic forget --quiet --tag daily --keep-daily 14 --prune
restic check --quiet
date -u +%FT%TZ > /var/lib/mp-backup/last-success
log "OK snapshot $(restic snapshots --json --latest 1 --tag daily | python3 -c 'import json,sys;print(json.load(sys.stdin)[0]["short_id"])')"
