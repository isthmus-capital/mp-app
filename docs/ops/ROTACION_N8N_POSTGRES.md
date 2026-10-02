# Rotación de la contraseña de Postgres de n8n — procedimiento (ejecuta Gianclaudio)

<!-- Brief 01 — 02-oct-2026. Claude Code no ejecuta ningún paso de este documento ni abre archivos de n8n. -->

**Motivo.** El 02-oct-2026 la contraseña vigente del Postgres de n8n apareció en la salida de una herramienta de la sesión de Claude Code (lectura indebida del compose de n8n). No se copió a ningún archivo, documento ni memoria, pero debe tratarse como expuesta y rotarse. En esa misma salida se mostraron los valores de `AUTOPAL_COMPANY` y `AUTOPAL_USER` (no `AUTOPAL_KEY`, que sí quedó enmascarada); evalúa si esos dos valores son secretos de esa integración y, si lo son, rótalos con el proveedor. `N8N_ENCRYPTION_KEY` y `N8N_BASIC_AUTH_PASSWORD` quedaron enmascaradas y no requieren rotación por este motivo.

**Cuándo.** **Ventana de fin de semana** (decisión de Gianclaudio, 02-oct-2026): no va en el reinicio del 02-oct. n8n queda fuera de servicio ~1 minuto (recreación de su contenedor). Postgres no se detiene. En la misma ventana conviene hacer la actualización de paquetes pendiente (`docker-ce`, `containerd.io`, `caddy` y el resto), porque reinicia el daemon de Docker y todos los contenedores; ver la sección final.

**Quién.** Gianclaudio, como `root` en el VPS (o `deploy` con `sudo -i`). Los comandos van en tu terminal, nunca en el chat.

## 0. Pre-requisitos (2 min)

1. En la UI de n8n (`https://automation.isthmuscap.com`) → *Executions* → confirmar que no hay ejecuciones en estado *Running*. Si hay, esperar a que terminen.
2. Dump fresco de seguridad (queda en `/root/backups`, que el backup diario del Brief 01 también respalda):

```bash
docker exec n8n-postgres-1 pg_dump -U n8n -Fc n8n > /root/backups/n8n-pre-rotacion-$(date +%F).dump
ls -lh /root/backups/n8n-pre-rotacion-$(date +%F).dump
```

3. Respaldo del compose:

```bash
cp -a /opt/n8n/docker-compose.yml /root/backups/docker-compose.n8n.pre-rotacion-$(date +%F).yml
```

## 1. Generar la nueva contraseña

Solo letras y números (32 caracteres), para que no rompa el parseo del compose ni ninguna URL de conexión:

```bash
NEWPW="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-32)"; echo "$NEWPW"
```

**Guárdala en tu gestor de contraseñas antes de seguir.**

## 2. Actualizar el compose (dos valores)

El servicio `postgres` lleva `POSTGRES_PASSWORD` (solo se usa al inicializar el volumen; se actualiza por coherencia) y el servicio `n8n` lleva `DB_POSTGRESDB_PASSWORD` (la que n8n usa para conectarse). Ambos deben quedar con la nueva:

```bash
sed -i -E "s|^(\s*POSTGRES_PASSWORD:\s*).*|\1${NEWPW}|; s|^(\s*- DB_POSTGRESDB_PASSWORD=).*|\1${NEWPW}|" /opt/n8n/docker-compose.yml
grep -nE "POSTGRES_PASSWORD|DB_POSTGRESDB_PASSWORD" /opt/n8n/docker-compose.yml
```

Esperado: dos líneas, las dos terminando en la nueva contraseña. Si el formato de alguna línea es distinto al esperado por el `sed` (por ejemplo `POSTGRES_PASSWORD=` en lista en vez de `POSTGRES_PASSWORD:` en mapa), edítala a mano con `nano` y repite el `grep`.

## 3. Cambiar la contraseña en Postgres

Dentro del contenedor la conexión local por socket no pide contraseña (`trust` de la imagen oficial), así que no necesitas la anterior. El cambio aplica a conexiones **nuevas**; n8n sigue funcionando con su pool hasta el paso 4, por eso los pasos 3 y 4 van seguidos.

```bash
docker exec -i n8n-postgres-1 psql -U n8n -d n8n -v ON_ERROR_STOP=1 -c "ALTER USER n8n WITH PASSWORD '${NEWPW}';"
```

Esperado: `ALTER ROLE`.

## 4. Recrear solo el contenedor de n8n

```bash
docker compose -f /opt/n8n/docker-compose.yml up -d --no-deps --force-recreate n8n
```

`--no-deps` evita tocar `postgres`. Tarda ~30–60 s en volver a responder.

## 5. Verificar

```bash
docker compose -f /opt/n8n/docker-compose.yml ps
docker logs --since 3m n8n-n8n-1 2>&1 | grep -iE "error|ECONNREFUSED|password authentication failed" || echo "sin errores de conexión en el log"
curl -s -o /dev/null -w "healthz %{http_code}\n" https://automation.isthmuscap.com/healthz
# La nueva contraseña autentica por red (no por socket):
docker exec -e PGPASSWORD="$NEWPW" -i n8n-postgres-1 psql -h 127.0.0.1 -U n8n -d n8n -tAc "select 1"
```

Esperado: ambos contenedores `Up` (`n8n-n8n-1` recién creado), `sin errores de conexión en el log`, `healthz 200`, y `1` en la última línea. Después, en la UI: abrir *Executions* y un workflow cualquiera (lectura real de la base). Opcional: pídeme que confirme desde el MCP con `search_workflows` (solo lectura).

## 6. Limpiar la variable y el historial

```bash
unset NEWPW; history -c
```

## 7. Cierre de la deriva del contenedor `postgres` (opcional, misma ventana)

El contenedor `postgres` sigue corriendo con la variable antigua en su entorno (no afecta: la contraseña real ya cambió en la base). La próxima vez que hagas `docker compose up -d` en `/opt/n8n`, Compose lo recreará por el cambio de entorno (datos en volumen, sin pérdida; n8n se recrea también por `depends_on`, ~1 min). Si quieres cerrarlo ahora, hazlo antes del reinicio y repite el paso 5:

```bash
docker compose -f /opt/n8n/docker-compose.yml up -d
```

## Reversa (si n8n no levanta en el paso 5)

```bash
cp -a /root/backups/docker-compose.n8n.pre-rotacion-$(date +%F).yml /opt/n8n/docker-compose.yml
docker exec -i n8n-postgres-1 psql -U n8n -d n8n -c "ALTER USER n8n WITH PASSWORD '<contraseña anterior, de tu gestor>';"
docker compose -f /opt/n8n/docker-compose.yml up -d --no-deps --force-recreate n8n
```

Y repetir el paso 5. Si el problema es otro (por ejemplo la base no arranca), restaurar el dump del paso 0 es el último recurso: `docker exec -i n8n-postgres-1 pg_restore -U n8n -d n8n --clean --if-exists < /root/backups/n8n-pre-rotacion-<fecha>.dump`.

## Misma ventana: actualización de paquetes (docker-ce, containerd.io, caddy y resto)

Al 02-oct-2026 hay 26 paquetes pendientes; `docker-ce`, `containerd.io` y los plugins de Compose reinician el daemon de Docker (y con él todos los contenedores, ~1 min), por eso no se hicieron en el reinicio del 02-oct. Después de verificar la rotación (paso 5) y antes de salir de la ventana:

```bash
/opt/mp-app/scripts/ops/check-services.sh pre-upgrade
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade && apt-get -y autoremove --purge
docker ps --format '{{.Names}} {{.Status}}'        # los 5 contenedores deben volver solos (restart policies)
/opt/mp-app/scripts/ops/check-services.sh post-upgrade
ls /var/run/reboot-required 2>/dev/null && echo "pide reinicio: repetir el checklist de reinicio" || echo "sin reinicio pendiente"
iptables -S DOCKER-USER | grep -c DROP            # debe seguir en 1 (Docker no vacía DOCKER-USER al reiniciar)
```

Si el daemon de Docker se reinicia y algún contenedor no vuelve: `docker start <nombre>`; para n8n, `docker compose -f /opt/n8n/docker-compose.yml up -d`.

## Registro

Al terminar, anota en `docs/INVENTARIO_ACTUAL.md` §0.1 (bitácora v1): fecha, "rotación de contraseña Postgres n8n" y "actualización de paquetes", quién, y el resultado del paso 5 y del `post-upgrade`. Esa anotación la puedo hacer yo si me pegas las líneas de salida (sin la contraseña).
