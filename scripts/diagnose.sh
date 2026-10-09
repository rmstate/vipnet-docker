#!/usr/bin/env bash
set -u
section() { printf '\n===== %s =====\n' "$1"; }

section "Система"
date -Is 2>/dev/null || date
uname -a
if [[ -r /etc/os-release ]]; then . /etc/os-release; printf 'OS: %s\n' "${PRETTY_NAME:-unknown}"; fi

section "Docker"
docker --version 2>&1 || true
docker compose version 2>&1 || true
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>&1 || true

section "Интерфейсы хоста"
ip -br addr 2>&1 || true
section "Маршруты хоста"
ip route 2>&1 || true

section "Сетевые параметры"
for f in /proc/sys/net/ipv4/ip_forward /proc/sys/net/ipv4/conf/all/rp_filter; do
  if [[ -r "$f" ]]; then printf '%s=' "$f"; cat "$f"; fi
done

section "Контейнеры ViPNet (если существуют)"
for name in vipnet-diag vipnet5 vipnet; do
  if docker inspect "$name" >/dev/null 2>&1; then
    echo "--- $name ---"
    docker inspect --format 'image={{.Config.Image}} status={{.State.Status}} privileged={{.HostConfig.Privileged}} cap_add={{json .HostConfig.CapAdd}}' "$name" 2>&1 || true
    docker exec "$name" sh -lc 'ip -br addr; echo "--- routes ---"; ip route; echo "--- processes ---"; ps aux' 2>&1 || true
    docker exec "$name" sh -lc 'command -v vipnetclient >/dev/null 2>&1 && vipnetclient info' 2>&1 || true
  fi
done

section "Готово"
echo "Перед публикацией отчёта обезличьте адреса и идентификаторы. DST не читается и не выводится этим скриптом."
