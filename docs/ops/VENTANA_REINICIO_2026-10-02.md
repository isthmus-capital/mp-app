# Ventana de reinicio — 02-oct-2026 22:00 Panamá (03:00 UTC 03-oct)

**Alcance (decisión de Gianclaudio):** solo el reinicio del VPS por el kernel nuevo (`7.0.0-34-generic`, ya instalado; hoy corre `7.0.0-31`). **No** se actualizan paquetes (`docker-ce` y `containerd.io` reiniciarían los contenedores; van en la ventana de fin de semana junto con la rotación de Postgres de n8n, ver `ROTACION_N8N_POSTGRES.md`). **No** se toca n8n.

**Quién:** Gianclaudio, desde su terminal. Claude Code no ejecuta el reinicio. Duración esperada: 2–3 minutos sin servicio para todo el VPS (Cotizador, Max Motors, n8n, Gotenberg).

## Antes (5 min)

1. **Restart policies** (lo verificas tú; Claude Code no inspecciona los contenedores de n8n):

```bash
docker inspect -f '{{.Name}} -> {{.HostConfig.RestartPolicy.Name}}' $(docker ps -q)
```

Esperado: ninguno en `no`. Al 02-oct, `cotizador-app` y `maxmotors-app` están en `unless-stopped` y `gotenberg` en `always` (verificado); `n8n-n8n-1` y `n8n-postgres-1` los confirmas tú. Si alguno está en `no`, corrígelo antes: `docker update --restart unless-stopped <nombre>`.

2. **n8n sin ejecuciones en curso:** UI → *Executions* → ninguna en *Running*.

3. **Línea base y regla de firewall:**

```bash
/opt/mp-app/scripts/ops/check-services.sh pre-reboot; echo rc=$?
iptables -S DOCKER-USER | grep -c DROP      # esperado 1
```

4. **Sesión de respaldo:** deja abierta una segunda terminal SSH (como `root` si el hardening de sshd aún no se aplicó; como `deploy` si ya se aplicó). Si el login de `deploy` ya está confirmado y el hardening aplicado, el reinicio no cambia nada de SSH.

## Reinicio

```bash
systemctl reboot
```

Espera ~2 minutos y vuelve a conectar.

## Después (5 min)

```bash
uptime; uname -r                                   # 7.0.0-34-generic
ls /var/run/reboot-required 2>&1                   # No such file or directory
/opt/mp-app/scripts/ops/check-services.sh post-reboot; echo rc=$?    # rc=0 y 5 contenedores Up
iptables -S DOCKER-USER | grep -c DROP             # 1 (regla persistida desde /etc/ufw/after.rules)
systemctl is-active caddy fail2ban docker ufw mp-backup.timer   # active ×5
fail2ban-client status sshd | head -3
ufw status | head -1                               # Status: active
```

Si todo coincide, pega en el chat las líneas de `post-reboot` y el conteo de `DOCKER-USER`; con eso cierro el criterio de aceptación 2 del Brief 01 y lo anoto en el inventario.

## Si algo falla

| Síntoma | Acción |
|---|---|
| Un contenedor no está `Up` | `docker start <nombre>`. Cotizador: `docker compose -f /opt/cotizador-isthmus/docker-compose.yml up -d`; Max Motors: `docker compose -f /home/maxmotors/docker-compose.yml up -d`; n8n: lo levantas tú desde su compose. |
| `DOCKER-USER` sin la regla DROP | `iptables -I DOCKER-USER 1 -i eth0 -p tcp -m conntrack --ctstate NEW -m multiport --dports 3000,3001,3002,5678 -j DROP` y avísame para revisar `/etc/ufw/after.rules`. **Nunca `ufw reload` con contenedores arriba.** |
| Caddy no responde en 443 | `systemctl status caddy`; `journalctl -u caddy -n 50`; `systemctl restart caddy`. |
| Un sitio da 502 | El contenedor detrás aún arranca; repetir `check-services.sh` en 1 min. |
| No entra por SSH | Consola Hetzner (Cloud Console → *Console*) con root; revisar `systemctl status ssh` y `/etc/ssh/sshd_config.d/`. |
| Reversa del kernel | No aplica: el kernel anterior sigue instalado; en GRUB (consola Hetzner) se puede elegir `7.0.0-31` si el nuevo no arranca. |
