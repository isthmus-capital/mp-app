#!/usr/bin/env bash
# Lista los snapshots diarios de restic en solo lectura, sin argumentos (sudoers MP_OPS).
# Sustituye a "restic snapshots *" y "restic stats *" con comodín, que admitían --password-command (comando como root).
# Hallazgo I1 de la revisión de cierre del Brief 01; decisión de Gianclaudio del 03-oct-2026.
set -euo pipefail
[ "$#" -eq 0 ] || { echo "mp-restic-snapshots: no acepta argumentos" >&2; exit 2; }
set -a; . /etc/mp-backup/restic.env; set +a
export HOME=/root
exec /usr/bin/restic snapshots --tag daily
