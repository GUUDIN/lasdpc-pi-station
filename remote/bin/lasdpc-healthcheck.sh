#!/usr/bin/env bash
# ============================================================
# lasdpc-healthcheck — verificações periódicas da estação.
# Temperatura, throttling, espaço, unidades falhas, containers, kiosk.
# Loga no journal (tag lasdpc-health). Sai !=0 se houver problema.
# Usado pelo timer systemd e por 'make healthcheck'.
# ============================================================
set -u
WARN_TEMP=75      # °C
CRIT_TEMP=82
MIN_FREE_GB=3
problems=0
out=""

add(){ out="$out$1\n"; }

# Temperatura
TEMP=$(vcgencmd measure_temp 2>/dev/null | tr -dc '0-9.')
if [ -n "$TEMP" ]; then
  add "temp=${TEMP}C"
  awk "BEGIN{exit !($TEMP>=$CRIT_TEMP)}" && { add "CRIT: temperatura >= ${CRIT_TEMP}C"; problems=1; }
  awk "BEGIN{exit !($TEMP>=$WARN_TEMP && $TEMP<$CRIT_TEMP)}" && add "WARN: temperatura alta"
fi

# Throttling / undervoltage
THR=$(vcgencmd get_throttled 2>/dev/null)
add "$THR"
[ "$THR" = "throttled=0x0" ] || { add "WARN: throttling/undervoltage detectado ($THR)"; }

# Espaço livre em /
FREE=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
add "free_root=${FREE}G"
[ "${FREE:-0}" -lt "$MIN_FREE_GB" ] && { add "CRIT: espaço livre < ${MIN_FREE_GB}G"; problems=1; }

# Unidades systemd falhas
FAILED=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
[ -n "$FAILED" ] && { add "WARN: unidades falhas: $FAILED"; }

# Containers IoT
if command -v docker >/dev/null 2>&1; then
  total=$(sudo docker ps -a --filter "name=lasdpc-" --format '{{.Names}}' 2>/dev/null | wc -l)
  up=$(sudo docker ps --filter "name=lasdpc-" --filter "status=running" --format '{{.Names}}' 2>/dev/null | wc -l)
  add "containers=${up}/${total} up"
  if [ "$total" -gt 0 ] && [ "$up" -lt "$total" ]; then add "WARN: containers fora do ar"; fi
fi

# Kiosk (se modo dashboard/menu, chromium deveria estar rodando)
MODE=$(tr -d '[:space:]' < /home/lasdpc/.config/lasdpc/mode 2>/dev/null || echo '?')
add "mode=$MODE"

MSG=$(printf "%b" "$out" | tr '\n' '|')
logger -t lasdpc-health "$MSG"
printf "%b" "$out"
exit $problems
