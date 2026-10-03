# Rotación de la contraseña de Postgres de n8n — procedimiento (aplazado sin fecha)

<!-- Brief 01 — 02-oct-2026. Separado de VENTANA_MANTENIMIENTO_FINDE.md el 03-oct-2026 cuando la rotación salió de la ventana de mantenimiento (decisión de Gianclaudio; R40 "aceptado temporalmente"). Claude Code no ejecuta ningún paso ni abre archivos de n8n. -->

**Estado:** aplazado **sin fecha**. Se conserva para cuando Gianclaudio decida ejecutarlo; hasta entonces R40 queda "aceptado temporalmente" con las reglas `deny` de `.claude/settings.json` como control.

**Motivo.** El 02-oct-2026 la contraseña vigente del Postgres de n8n apareció en la salida de una herramienta de la sesión de Claude Code (lectura indebida del compose de n8n). No se copió a ningún archivo, documento ni memoria, pero se trata como expuesta (R40). En esa misma salida se mostraron `AUTOPAL_COMPANY` y `AUTOPAL_USER` (no `AUTOPAL_KEY`, que quedó enmascarada): evalúa si son secretos de esa integración y, si lo son, rótalos con el proveedor. `N8N_ENCRYPTION_KEY` y `N8N_BASIC_AUTH_PASSWORD` quedaron enmascaradas y no requieren rotación por este motivo.

**Quién y cuándo:** Gianclaudio, desde su terminal, como `root` (o `deploy` con `sudo -i`). En un momento de baja actividad, con n8n sin ejecuciones en *Running*; evita 08:00 UTC ± 10 min (03:00 Panamá), cuando corre `mp-backup.timer`. Corte esperado: n8n ~1 min (paso 2.4). Segunda terminal SSH abierta durante todo el procedimiento. No hace falta snapshot manual del servidor (Backups de Hetzner activos, `RUNBOOK_VPS.md` §6); el dump del paso 1 sí, porque la copia del servidor no es consistente a nivel de base de datos y la reversa depende de él.

## 1. Dump previo (2 min)

El dump queda en `/root/backups`, que el backup diario también respalda.

```bash
docker exec n8n-postgres-1 pg_dump -U n8n -Fc n8n > /root/backups/n8n-pre-rotacion-$(date +%F).dump
ls -lh /root/backups/n8n-pre-rotacion-$(date +%F).dump
cp -a /opt/n8n/docker-compose.yml /root/backups/docker-compose.n8n.pre-rotacion-$(date +%F).yml
```

- [ ] Dump con tamaño razonable (comparable a los de ago/sep en `/root/backups`) y copia del compose hecha.

## 2. Rotación de la contraseña de Postgres de n8n (5 min)

- [ ] **2.1 Generar la nueva** (32 caracteres alfanuméricos, para no romper el parseo del compose ni URLs). Guárdala en tu gestor **antes** de seguir:

```bash
NEWPW="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-32)"; echo "$NEWPW"
```

- [ ] **2.2 Actualizar el compose.** Dos valores: `POSTGRES_PASSWORD` (solo se usa al inicializar el volumen; por coherencia) y `DB_POSTGRESDB_PASSWORD` (la que usa n8n):

```bash
sed -i -E "s|^(\s*POSTGRES_PASSWORD:\s*).*|\1${NEWPW}|; s|^(\s*- DB_POSTGRESDB_PASSWORD=).*|\1${NEWPW}|" /opt/n8n/docker-compose.yml
grep -nE "POSTGRES_PASSWORD|DB_POSTGRESDB_PASSWORD" /opt/n8n/docker-compose.yml
```

Esperado: dos líneas que terminan en la nueva contraseña. Si el formato difiere del que espera el `sed` (por ejemplo `POSTGRES_PASSWORD=` en lista en vez de `POSTGRES_PASSWORD:` en mapa), edita a mano con `nano` y repite el `grep`.

- [ ] **2.3 Cambiarla en Postgres.** La conexión local por socket no pide contraseña (`trust` de la imagen oficial), así que no necesitas la anterior. Aplica a conexiones nuevas; n8n sigue con su pool hasta el 2.4, por eso van seguidos:

```bash
docker exec -i n8n-postgres-1 psql -U n8n -d n8n -v ON_ERROR_STOP=1 -c "ALTER USER n8n WITH PASSWORD '${NEWPW}';"
```

Esperado: `ALTER ROLE`.

- [ ] **2.4 Recrear solo n8n** (`--no-deps` no toca `postgres`; ~30–60 s):

```bash
docker compose -f /opt/n8n/docker-compose.yml up -d --no-deps --force-recreate n8n
```

- [ ] **2.5 Verificar:**

```bash
docker compose -f /opt/n8n/docker-compose.yml ps
docker logs --since 3m n8n-n8n-1 2>&1 | grep -iE "error|ECONNREFUSED|password authentication failed" || echo "sin errores de conexión en el log"
curl -s -o /dev/null -w "healthz %{http_code}\n" https://automation.isthmuscap.com/healthz
docker exec -e PGPASSWORD="$NEWPW" -i n8n-postgres-1 psql -h 127.0.0.1 -U n8n -d n8n -tAc "select 1"
```

Esperado: ambos contenedores `Up`, `sin errores de conexión en el log`, `healthz 200` y `1` (la nueva contraseña autentica por red, no por socket). En la UI: abrir *Executions* y un workflow cualquiera (lectura real de la base). Opcional: pídeme confirmar con `search_workflows` (solo lectura, por el MCP).

- [ ] **2.6 Limpiar:** `unset NEWPW; history -c`
- [ ] **2.7 (opcional) Cerrar la deriva de `postgres`.** Su contenedor sigue con la variable antigua en el entorno (no afecta: la contraseña real ya cambió). Un reinicio del VPS **no** lo corrige, porque restaura el contenedor existente sin recrearlo. Si quieres cerrarlo ahora, `docker compose -f /opt/n8n/docker-compose.yml up -d` recrea `postgres` (datos en volumen, sin pérdida) y n8n por `depends_on` (~1 min); repite 2.5. Si no, se cierra en el próximo `up -d`.

**Si 2.5 no dio `healthz 200` y `1`, ver Reversa.**

## 3. Registro

Anota en `docs/INVENTARIO_ACTUAL.md` §0.1 (bitácora v1): fecha, "rotación de contraseña Postgres n8n", quién la ejecutó y el resultado de 2.5. Esa anotación la hago yo si me pegas las salidas (sin la contraseña). Marca R40 como cerrado en `docs/RIESGOS.md` cuando 2.5 haya pasado.

## Reversa de la rotación

```bash
cp -a /root/backups/docker-compose.n8n.pre-rotacion-$(date +%F).yml /opt/n8n/docker-compose.yml
docker exec -i n8n-postgres-1 psql -U n8n -d n8n -c "ALTER USER n8n WITH PASSWORD '<contraseña anterior, de tu gestor>';"
docker compose -f /opt/n8n/docker-compose.yml up -d --no-deps --force-recreate n8n
```

Y repetir 2.5. Si el problema es otro (por ejemplo, la base no arranca), el último recurso es restaurar el dump del paso 1: `docker exec -i n8n-postgres-1 pg_restore -U n8n -d n8n --clean --if-exists < /root/backups/n8n-pre-rotacion-<fecha>.dump`.
