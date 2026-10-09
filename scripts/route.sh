#!/usr/bin/env bash
set -Eeuo pipefail

CONTAINER="${CONTAINER:-vipnet-diag}"
TARGET_IP="${TARGET_IP:-}"
ACTION="${1:-}"

die() {
    echo "Ошибка: $*" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
Использование:
  sudo env TARGET_IP=192.0.2.10 ./scripts/route.sh apply
  sudo env TARGET_IP=192.0.2.10 ./scripts/route.sh check
  sudo env TARGET_IP=192.0.2.10 ./scripts/route.sh remove

Переменные окружения:
  CONTAINER  Имя контейнера (по умолчанию vipnet-diag)
  TARGET_IP  IPv4-адрес защищённого ресурса

192.0.2.10 — только документационный пример.
USAGE
}

[[ "$EUID" -eq 0 ]] || die "Запусти скрипт через sudo."
[[ -n "$TARGET_IP" ]] || { usage; die "Не задан TARGET_IP."; }

for cmd in docker ip iptables python3; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Не найдена команда: $cmd"
done

python3 - "$TARGET_IP" <<'PY'
import ipaddress, sys
try:
    ipaddress.IPv4Address(sys.argv[1])
except ValueError:
    raise SystemExit("TARGET_IP должен быть корректным IPv4-адресом")
PY

docker inspect "$CONTAINER" >/dev/null 2>&1 ||
    die "Контейнер '$CONTAINER' не найден."

[[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" == "true" ]] ||
    die "Контейнер '$CONTAINER' не запущен."

CONTAINER_IP="$(
    docker inspect -f \
      '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
      "$CONTAINER"
)"
[[ -n "$CONTAINER_IP" ]] ||
    die "Не удалось определить IPv4 контейнера."

VPN_IP="$(
    docker exec "$CONTAINER" sh -lc \
      "ip -o -4 addr show dev tun0 | awk 'NR==1 {split(\$4,a,\"/\"); print a[1]}'"
)"
[[ -n "$VPN_IP" ]] ||
    die "Не найден IPv4-адрес интерфейса tun0."

docker exec "$CONTAINER" ip link show eth0 >/dev/null 2>&1 ||
    die "Не найден интерфейс eth0 в контейнере."
docker exec "$CONTAINER" ip link show tun0 >/dev/null 2>&1 ||
    die "Не найден интерфейс tun0 в контейнере."

container_iptables() {
    docker exec "$CONTAINER" iptables "$@"
}

has_rule() {
    local table="$1" chain="$2"
    shift 2
    container_iptables -t "$table" -C "$chain" "$@" >/dev/null 2>&1
}

add_rule() {
    local table="$1" chain="$2"
    shift 2
    if ! has_rule "$table" "$chain" "$@"; then
        container_iptables -t "$table" -A "$chain" "$@"
    fi
}

delete_rule() {
    local table="$1" chain="$2"
    shift 2
    while has_rule "$table" "$chain" "$@"; do
        container_iptables -t "$table" -D "$chain" "$@"
    done
}

check_forwarding() {
    local value
    value="$(docker exec "$CONTAINER" \
        cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" ||
        die "Не удалось прочитать IPv4 forwarding контейнера."
    [[ "$value" == "1" ]] ||
        die "IPv4 forwarding выключен в контейнере. Скрипт не меняет sysctl автоматически."
}

case "$ACTION" in
    apply)
        check_forwarding

        # Весь IP-трафик к одному явно заданному адресу.
        add_rule filter FORWARD \
            -i eth0 -o tun0 -d "$TARGET_IP/32" -j ACCEPT

        # Обратный трафик только для существующих соединений.
        add_rule filter FORWARD \
            -i tun0 -o eth0 \
            -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

        # Подмена исходного адреса на адрес VPN-интерфейса.
        add_rule nat POSTROUTING \
            -o tun0 -d "$TARGET_IP/32" \
            -j SNAT --to-source "$VPN_IP"

        # Маршрут на хосте только к выбранному ресурсу.
        ip route replace "$TARGET_IP/32" via "$CONTAINER_IP"

        echo "Настройка применена."
        echo "Контейнер: $CONTAINER ($CONTAINER_IP)"
        echo "VPN IP:    $VPN_IP"
        echo "Ресурс:    $TARGET_IP (все IP-протоколы)"
        ;;

    check)
        echo "Контейнер: $CONTAINER ($CONTAINER_IP)"
        echo "VPN IP:    $VPN_IP"
        echo "Forwarding: $(docker exec "$CONTAINER" \
            cat /proc/sys/net/ipv4/ip_forward)"
        echo
        echo "Маршрут хоста:"
        ip route get "$TARGET_IP" || true
        echo
        echo "Маршрут контейнера:"
        docker exec "$CONTAINER" ip route get "$TARGET_IP" || true
        echo
        echo "Правила FORWARD:"
        container_iptables -t filter -S FORWARD
        echo
        echo "Правила NAT:"
        container_iptables -t nat -S POSTROUTING
        ;;

    remove)
        # Для удаления нужны контейнер и tun0 с тем же VPN IP.
        delete_rule filter FORWARD \
            -i eth0 -o tun0 -d "$TARGET_IP/32" -j ACCEPT

        delete_rule filter FORWARD \
            -i tun0 -o eth0 \
            -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

        delete_rule nat POSTROUTING \
            -o tun0 -d "$TARGET_IP/32" \
            -j SNAT --to-source "$VPN_IP"

        # Не трогаем маршрут, если он указывает не на этот контейнер.
        if ip route show "$TARGET_IP/32" |
            grep -Fq "via $CONTAINER_IP"; then
            ip route del "$TARGET_IP/32" via "$CONTAINER_IP"
        fi

        echo "Правила скрипта и соответствующий маршрут удалены."
        echo "Глобальные политики firewall не менялись."
        ;;

    *)
        usage
        exit 2
        ;;
esac
