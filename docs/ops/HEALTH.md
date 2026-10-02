# `/api/health` — contrato (Brief 01) e implementación (Briefs 02–05)

**Ruta:** `GET /api/health` (sin autenticación para el resumen; detalle con cabecera `X-Health-Token: <HEALTH_TOKEN>` del `.env`).
**Respuesta:** `200` cuando todos los chequeos críticos están `ok`; `503` si alguno crítico falla. Siempre JSON, nunca HTML ni trazas. Sin secretos ni PII.

```json
{ "status": "ok | degraded | down", "env": "staging", "version": "<git sha>", "at": "2026-10-02T08:00:00Z",
  "checks": {
    "db":       { "state": "ok|fail|skipped", "ms": 12,  "detail": "select 1" },
    "n8n":      { "state": "ok|fail|skipped", "ms": 80,  "detail": "GET <N8N_WEBHOOK_BASE>/healthz" },
    "zoho":     { "state": "ok|fail|skipped", "ms": 150, "detail": "token válido hasta <fecha>" },
    "loandisk": { "state": "ok|fail|skipped", "ms": 300, "detail": "GET branch 87572" },
    "backup":   { "state": "ok|fail",         "ms": 1,   "detail": "último éxito <ISO>; umbral 36 h" }
  },
  "last_alert": "<última línea de /var/lib/mp-health/alerts.log o null>" }
```

| Chequeo | Crítico | Se implementa en | Fuente |
|---|---|---|---|
| `db` | sí | Brief 03 (`select 1` con service role, timeout 2 s) | Supabase `isthmus-mp` |
| `n8n` | sí | Brief 02 (`/healthz`, timeout 3 s) | `N8N_WEBHOOK_BASE` |
| `zoho` | no (`degraded`) | Brief 05 (adaptador; verifica que la credencial de N8N responda) | vía N8N, nunca directo |
| `loandisk` | no (`degraded`) | Brief 05 (adaptador `core`) | LoanDisk API |
| `backup` | sí | Brief 02 (lee `/var/lib/mp-backup/last-success`, volumen montado `:ro`) | `mp-backup.timer` (Brief 01) |

**Sonda externa:** `mp-healthcheck.timer` (cada 5 min) hace `GET https://staging-mp.isthmuscap.com/api/health`; tres fallos seguidos → `mp-alert.sh health:<url>:<código>`. Instalada en el Brief 01, **se activa en el Brief 02** cuando exista la ruta (hoy respondería 503 por la página de espera, o nada mientras no haya DNS).
**Alerta:** canal WhatsApp al admin con plantilla UTILITY (Brief 13); hasta entonces journal (`logger -t mp-alert`) + `/var/lib/mp-health/alerts.log`.
**`skipped`:** solo válido en staging mientras la dependencia no esté configurada; en producción todo chequeo debe ser `ok` o `fail`.
