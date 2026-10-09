#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

CONTAINER="${CONTAINER:-vipnet-diag}"
TARGET_IP="${TARGET_IP:-}"
ACTION="${1:-}"

 die() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Использование:
  sudo env TARGET_IP=192.0.2.10 ./scripts/route.sh check
  sudo env TARGET_IP=192.0.2.10 ./scripts/route.sh apply
  sudo env TARGET_IP=192.0.2.10 ./scripts/route.sh remove

Переменные окружения:
  CONTAINER  Имя контейнера (по умолчанию vipnet-diag)
  TARGET_IP  IPv4-адрес разрешённого тестового ресурса

192.0.2.10 — документационный пример, не реальная цель.
USAGE
}

[[ "$EUID" -eq 0 ]] || die 'Запусти скрипт через sudo.'
[[ -n "$TARGET_IP" ]] || { usage; die 'Не задан TARGET_IP.'; }
[[ "$TARGET_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || die 'TARGET_IP должен быть IPv4-адресом.'
case "$ACTION" in check|apply|remove) ;; *) usage; exit 2 ;; esac
command -v python3 >/dev/null 2>&1 || die 'Не найдена команда: python3'
python3 - "$TARGET_IP" <<'PY'
import ipaddress, sys
try:
    ip = ipaddress.IPv4Address(sys.argv[1])
except ValueError:
    raise SystemExit('TARGET_IP должен быть корректным IPv4-адресом')
if ip.is_unspecified or ip.is_loopback or ip.is_multicast or ip.is_link_local or ip.is_reserved:
    raise SystemExit('TARGET_IP должен быть обычным IPv4-адресом разрешённого тестового ресурса')
PY

IP_TAG="${TARGET_IP//./_}"
FWD_CHAIN="VNF_${IP_TAG}"
NAT_CHAIN="VNN_${IP_TAG}"
STATE_FILE="/run/vipnet-route-${IP_TAG}.state"
LOCK_FILE="/run/vipnet-route-${IP_TAG}.lock"
for cmd in docker ip iptables grep flock; do command -v "$cmd" >/dev/null 2>&1 || die "Не найдена команда: $cmd"; done
[[ ${#FWD_CHAIN} -le 28 && ${#NAT_CHAIN} -le 28 ]] || die 'Слишком длинное имя цепочки.'
exec 9>"$LOCK_FILE"
flock -n 9 || die 'Для этого TARGET_IP уже выполняется другой экземпляр скрипта.'

docker inspect "$CONTAINER" >/dev/null 2>&1 || die "Контейнер '$CONTAINER' не найден."
[[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" == true ]] || die "Контейнер '$CONTAINER' не запущен."
CONTAINER_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER")"
[[ "$CONTAINER_IP" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || die 'Не удалось определить IPv4 контейнера.'
VPN_IP="$(docker exec "$CONTAINER" sh -lc 'ip -o -4 addr show dev tun0 | awk "NR==1 {split(\$4,a,\"/\"); print a[1]}"')"
[[ "$VPN_IP" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || die 'Не найден IPv4-адрес интерфейса tun0.'
docker exec "$CONTAINER" ip link show eth0 >/dev/null 2>&1 || die 'Не найден интерфейс eth0 в контейнере.'
docker exec "$CONTAINER" ip link show tun0 >/dev/null 2>&1 || die 'Не найден интерфейс tun0 в контейнере.'

container_iptables() { docker exec "$CONTAINER" iptables "$@"; }
host_route_exists() { ip -4 route show exact "$TARGET_IP/32" | grep -q .; }
host_route_via() { ip -4 route show exact "$TARGET_IP/32" | grep -Fq "via $1"; }
chain_exists() { container_iptables -t "$1" -S "$2" >/dev/null 2>&1; }
has_rule() { local table="$1" chain="$2"; shift 2; container_iptables -t "$table" -C "$chain" "$@" >/dev/null 2>&1; }
ensure_rule() { local table="$1" chain="$2"; shift 2; RULE_ADDED=0; if ! has_rule "$table" "$chain" "$@"; then container_iptables -t "$table" -A "$chain" "$@"; RULE_ADDED=1; fi; }
remove_rule_all() { local table="$1" chain="$2"; shift 2; while has_rule "$table" "$chain" "$@"; do container_iptables -t "$table" -D "$chain" "$@"; done; }
check_forwarding() { [[ "$(docker exec "$CONTAINER" cat /proc/sys/net/ipv4/ip_forward)" == 1 ]] || die 'IPv4 forwarding выключен в контейнере; скрипт не меняет sysctl автоматически.'; }

# Parse a root-owned state file as data, never as shell code.
read_state() {
  STATE_ROUTE_ADDED=0; STATE_CONTAINER_IP=''; local key value
  [[ -f "$STATE_FILE" && ! -L "$STATE_FILE" ]] || return 1
  [[ "$(stat -c '%u' "$STATE_FILE")" == 0 ]] || die 'Файл состояния должен принадлежать root.'
  [[ "$(stat -c '%a' "$STATE_FILE")" == 600 ]] || die 'Права файла состояния должны быть 600.'
  while IFS='=' read -r key value; do
    case "$key" in
      route_added) [[ "$value" == 0 || "$value" == 1 ]] || die 'Повреждён route_added в файле состояния.'; STATE_ROUTE_ADDED="$value" ;;
      container_ip) [[ "$value" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || die 'Повреждён container_ip в файле состояния.'; STATE_CONTAINER_IP="$value" ;;
      version) [[ "$value" == 1 ]] || die 'Неподдерживаемая версия файла состояния.' ;;
      '') ;;
      *) die "Неизвестное поле в файле состояния: $key" ;;
    esac
  done < "$STATE_FILE"
  [[ -n "$STATE_CONTAINER_IP" ]] || die 'В файле состояния отсутствует container_ip.'
  return 0
}

case "$ACTION" in
check)
  printf 'Контейнер: %s (%s)\nVPN IP:    %s\n' "$CONTAINER" "$CONTAINER_IP" "$VPN_IP"
  printf 'Forwarding: '; docker exec "$CONTAINER" cat /proc/sys/net/ipv4/ip_forward
  printf '\nМаршрут хоста:\n'; ip -4 route get "$TARGET_IP" || true
  printf '\nМаршрут контейнера:\n'; docker exec "$CONTAINER" ip -4 route get "$TARGET_IP" || true
  printf '\nЦепочка FORWARD (%s):\n' "$FWD_CHAIN"; if chain_exists filter "$FWD_CHAIN"; then container_iptables -t filter -S "$FWD_CHAIN"; else echo 'не создана'; fi
  printf '\nЦепочка NAT (%s):\n' "$NAT_CHAIN"; if chain_exists nat "$NAT_CHAIN"; then container_iptables -t nat -S "$NAT_CHAIN"; else echo 'не создана'; fi
  printf '\nХуки в общих цепочках:\n'
  container_iptables -t filter -S FORWARD | grep -E -- "-j ${FWD_CHAIN}([[:space:]]|$)" || true
  container_iptables -t nat -S POSTROUTING | grep -E -- "-j ${NAT_CHAIN}([[:space:]]|$)" || true
  ;;
apply)
  check_forwarding
  state_exists=0
  if read_state; then
    state_exists=1
    [[ "$STATE_CONTAINER_IP" == "$CONTAINER_IP" ]] || die 'IP контейнера изменился; сначала проверь старые правила и выполни remove с прежней конфигурацией.'
  elif [[ -e "$STATE_FILE" ]]; then
    die 'Файл состояния существует, но не прошёл проверку.'
  fi
  if host_route_exists && ! host_route_via "$CONTAINER_IP"; then die "Для $TARGET_IP/32 уже существует другой маршрут; он не изменён."; fi
  if (( ! state_exists )) && { chain_exists filter "$FWD_CHAIN" || chain_exists nat "$NAT_CHAIN" || has_rule filter FORWARD -d "$TARGET_IP/32" -j "$FWD_CHAIN" || has_rule filter FORWARD -s "$TARGET_IP/32" -j "$FWD_CHAIN" || has_rule nat POSTROUTING -o tun0 -d "$TARGET_IP/32" -j "$NAT_CHAIN"; }; then
    die 'Найдены цепочки или хуки без файла состояния. Автоматическое присвоение чужих правил запрещено; проверь их вручную.'
  fi

  # Roll back only objects/rules created by this invocation.
  made_fwd=0; made_nat=0; jump_out=0; jump_in=0; jump_nat=0; made_route=0
  rule_fwd_out=0; rule_fwd_return=0; rule_nat_snat=0
  rollback() {
    local rc=$?
    trap - ERR
    set +e
    (( jump_out )) && remove_rule_all filter FORWARD -d "$TARGET_IP/32" -j "$FWD_CHAIN"
    (( jump_in )) && remove_rule_all filter FORWARD -s "$TARGET_IP/32" -j "$FWD_CHAIN"
    (( jump_nat )) && remove_rule_all nat POSTROUTING -o tun0 -d "$TARGET_IP/32" -j "$NAT_CHAIN"
    (( rule_fwd_out )) && remove_rule_all filter "$FWD_CHAIN" -i eth0 -o tun0 -d "$TARGET_IP/32" -j ACCEPT
    (( rule_fwd_return )) && remove_rule_all filter "$FWD_CHAIN" -i tun0 -o eth0 -s "$TARGET_IP/32" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    (( rule_nat_snat )) && remove_rule_all nat "$NAT_CHAIN" -j SNAT --to-source "$VPN_IP"
    (( made_fwd )) && { container_iptables -t filter -F "$FWD_CHAIN"; container_iptables -t filter -X "$FWD_CHAIN"; }
    (( made_nat )) && { container_iptables -t nat -F "$NAT_CHAIN"; container_iptables -t nat -X "$NAT_CHAIN"; }
    (( made_route )) && ip -4 route del "$TARGET_IP/32" via "$CONTAINER_IP"
    [[ -n "${STATE_TMP:-}" ]] && rm -f "$STATE_TMP"
    exit "$rc"
  }
  trap rollback ERR
  if ! chain_exists filter "$FWD_CHAIN"; then container_iptables -t filter -N "$FWD_CHAIN"; made_fwd=1; fi
  if ! chain_exists nat "$NAT_CHAIN"; then container_iptables -t nat -N "$NAT_CHAIN"; made_nat=1; fi
  if (( state_exists )) && chain_exists nat "$NAT_CHAIN" && ! has_rule nat "$NAT_CHAIN" -j SNAT --to-source "$VPN_IP"; then
    if container_iptables -t nat -S "$NAT_CHAIN" | grep -q -- '-j SNAT --to-source'; then
      die 'VPN IP изменился, а цепочка NAT содержит старый SNAT. Выполни remove и затем apply после проверки текущих правил.'
    fi
  fi
  ensure_rule filter "$FWD_CHAIN" -i eth0 -o tun0 -d "$TARGET_IP/32" -j ACCEPT; rule_fwd_out=$RULE_ADDED
  ensure_rule filter "$FWD_CHAIN" -i tun0 -o eth0 -s "$TARGET_IP/32" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; rule_fwd_return=$RULE_ADDED
  ensure_rule nat "$NAT_CHAIN" -j SNAT --to-source "$VPN_IP"; rule_nat_snat=$RULE_ADDED
  if ! has_rule filter FORWARD -d "$TARGET_IP/32" -j "$FWD_CHAIN"; then container_iptables -t filter -I FORWARD 1 -d "$TARGET_IP/32" -j "$FWD_CHAIN"; jump_out=1; fi
  if ! has_rule filter FORWARD -s "$TARGET_IP/32" -j "$FWD_CHAIN"; then container_iptables -t filter -I FORWARD 1 -s "$TARGET_IP/32" -j "$FWD_CHAIN"; jump_in=1; fi
  if ! has_rule nat POSTROUTING -o tun0 -d "$TARGET_IP/32" -j "$NAT_CHAIN"; then container_iptables -t nat -I POSTROUTING 1 -o tun0 -d "$TARGET_IP/32" -j "$NAT_CHAIN"; jump_nat=1; fi
  if ! host_route_exists; then ip -4 route add "$TARGET_IP/32" via "$CONTAINER_IP"; made_route=1; fi
  if (( ! state_exists )); then
    STATE_TMP="$(mktemp /run/vipnet-route-XXXXXX)"
    printf 'version=1\nroute_added=%s\ncontainer_ip=%s\n' "$made_route" "$CONTAINER_IP" > "$STATE_TMP"
    chmod 600 "$STATE_TMP"
    mv -n "$STATE_TMP" "$STATE_FILE"
    STATE_TMP=''
  fi
  trap - ERR
  printf 'Настройка применена.\nКонтейнер: %s (%s)\nVPN IP: %s\nРесурс: %s/32\nЦепочки: %s, %s\n' "$CONTAINER" "$CONTAINER_IP" "$VPN_IP" "$TARGET_IP" "$FWD_CHAIN" "$NAT_CHAIN"
  ;;
remove)
  state_exists=0
  if read_state; then state_exists=1; elif [[ -e "$STATE_FILE" ]]; then die 'Файл состояния повреждён или небезопасен; правила не изменены.'; fi
  if (( ! state_exists )); then
    if chain_exists filter "$FWD_CHAIN" || chain_exists nat "$NAT_CHAIN" || has_rule filter FORWARD -d "$TARGET_IP/32" -j "$FWD_CHAIN" || has_rule filter FORWARD -s "$TARGET_IP/32" -j "$FWD_CHAIN" || has_rule nat POSTROUTING -o tun0 -d "$TARGET_IP/32" -j "$NAT_CHAIN"; then
      die 'Найдены правила без файла состояния. Ничего не удалено; проверь их вручную.'
    fi
    echo 'Состояние проекта не найдено; принадлежащие проекту правила не обнаружены. Нечего удалять.'
    exit 0
  fi
  remove_rule_all filter FORWARD -d "$TARGET_IP/32" -j "$FWD_CHAIN"
  remove_rule_all filter FORWARD -s "$TARGET_IP/32" -j "$FWD_CHAIN"
  remove_rule_all nat POSTROUTING -o tun0 -d "$TARGET_IP/32" -j "$NAT_CHAIN"
  if chain_exists filter "$FWD_CHAIN"; then
    # Refuse to flush rules not expected from this tool.
    unexpected="$(container_iptables -t filter -S "$FWD_CHAIN" | grep -vE "^-N ${FWD_CHAIN}$|^-A ${FWD_CHAIN} (-i eth0 -o tun0 -d ${TARGET_IP}/32 -j ACCEPT|-i tun0 -o eth0 -s ${TARGET_IP}/32 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT)$" || true)"
    [[ -z "$unexpected" ]] || die 'Цепочка FORWARD содержит неожиданные правила; не очищена.'
    container_iptables -t filter -F "$FWD_CHAIN"; container_iptables -t filter -X "$FWD_CHAIN"
  fi
  if chain_exists nat "$NAT_CHAIN"; then
    unexpected="$(container_iptables -t nat -S "$NAT_CHAIN" | grep -vE "^-N ${NAT_CHAIN}$|^-A ${NAT_CHAIN} -j SNAT --to-source [0-9.]+$" || true)"
    [[ -z "$unexpected" ]] || die 'Цепочка NAT содержит неожиданные правила; не очищена.'
    container_iptables -t nat -F "$NAT_CHAIN"; container_iptables -t nat -X "$NAT_CHAIN"
  fi
  if [[ "$STATE_ROUTE_ADDED" == 1 ]] && host_route_via "$STATE_CONTAINER_IP"; then ip -4 route del "$TARGET_IP/32" via "$STATE_CONTAINER_IP"; fi
  rm -f "$STATE_FILE"
  echo 'Цепочки и хуки проекта удалены; маршрут удалён только если его создание было записано в состоянии.'
  ;;
esac
