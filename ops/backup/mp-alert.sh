#!/usr/bin/env bash
# Alerta operativa (Brief 01). Canal de salida: pendiente del Brief 13 (plantilla UTILITY de WhatsApp o correo desde gestionprestamos@ vía mp_notificar).
# Hasta entonces: journal + /var/lib/mp-health/alerts.log, que /api/health (Brief 02) expone como last_alert.
set -u
src="${1:-desconocido}"; ts="$(date -u +%FT%TZ)"
mkdir -p /var/lib/mp-health
printf '%s ALERTA %s\n' "$ts" "$src" | tee -a /var/lib/mp-health/alerts.log
logger -t mp-alert -p user.err "ALERTA $src"
