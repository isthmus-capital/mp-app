#!/usr/bin/env bash
# Reversa del bloqueo DOCKER-USER (Brief 01, D5). Quita la regla en vivo y restaura after.rules. No reinicia nada.
set -u
RULE=(-i eth0 -p tcp -m conntrack --ctstate NEW -m multiport --dports 3000,3001,3002,5678 -j DROP)
while iptables -C DOCKER-USER "${RULE[@]}" 2>/dev/null; do iptables -D DOCKER-USER "${RULE[@]}"; done
echo "regla en vivo eliminada; DOCKER-USER ahora:"; iptables -S DOCKER-USER
if [ -f /root/backups/after.rules.pre-brief01 ]; then
  cp -a /root/backups/after.rules.pre-brief01 /etc/ufw/after.rules && echo "/etc/ufw/after.rules restaurado (sin ufw reload; aplica al próximo arranque)"
fi
systemctl stop mp-docker-user-revert.timer 2>/dev/null || true
