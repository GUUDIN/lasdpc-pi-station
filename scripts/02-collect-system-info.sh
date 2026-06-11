#!/usr/bin/env bash
# ============================================================
# 02 — Coleta de informações da Pi (SOMENTE LEITURA).
# Gera relatório com data/hora em logs/ e valida pré-requisitos.
# Interrompe com mensagem clara se o ambiente for impróprio.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

REPORT="$LOG_DIR/inspecao-$(ts).md"
log "Coletando informações de $PI_HOST -> $REPORT"

# Bloco de comandos read-only executados remotamente
read -r -d '' REMOTE_CMDS <<'EOF' || true
echo "### hostnamectl";            hostnamectl 2>/dev/null
echo "### os-release";             cat /etc/os-release 2>/dev/null
echo "### uname";                  uname -a
echo "### arquitetura(dpkg)";      dpkg --print-architecture 2>/dev/null
echo "### long-bit";               getconf LONG_BIT
echo "### modelo";                 tr -d '\0' < /proc/device-tree/model 2>/dev/null; echo
echo "### memoria";                free -h
echo "### blocos";                 lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL 2>/dev/null
echo "### disco";                  df -hT
echo "### throttled";              vcgencmd get_throttled 2>/dev/null || echo "vcgencmd indisponível"
echo "### temperatura";            vcgencmd measure_temp 2>/dev/null || echo "vcgencmd indisponível"
echo "### mem-arm";                vcgencmd get_mem arm 2>/dev/null || true
echo "### mem-gpu";                vcgencmd get_mem gpu 2>/dev/null || true
echo "### ip-addr";                ip -brief address
echo "### ip-route";               ip route
echo "### systemd-failed";         systemctl --failed --no-pager 2>/dev/null
echo "### sessao-grafica";         echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-?} DESKTOP=${XDG_CURRENT_DESKTOP:-?}"
echo "### login-manager";          (systemctl get-default; ls /usr/bin/lightdm /usr/bin/sddm /usr/bin/gdm3 2>/dev/null) 2>/dev/null
echo "### softwares";              for b in chromium chromium-browser kodi docker emulationstation retroarch; do command -v $b >/dev/null 2>&1 && echo "  presente: $b ($(command -v $b))" || echo "  ausente:  $b"; done
echo "### internet";               (getent hosts deb.debian.org >/dev/null 2>&1 && echo "DNS OK") ; (curl -fsS -m5 -o /dev/null https://deb.debian.org && echo "HTTPS OK" || echo "HTTPS FALHOU")
echo "### audio";                  (aplay -l 2>/dev/null | head -20) || echo "aplay indisponível"
EOF

{
  echo "# Relatório de Inspeção — LASDPC Pi Station"
  echo
  echo "- Data: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- Host: ${PI_USER}@${PI_HOST}:${PI_PORT}"
  echo
  echo '```'
  pi_ssh "$REMOTE_CMDS" 2>&1
  echo '```'
} | tee "$REPORT" >/dev/null

ok "Relatório salvo em $REPORT"
echo
log "=== Validação de pré-requisitos (bloqueios da Etapa 2) ==="

fail=0
model="$(grep -A1 '### modelo' "$REPORT" | tail -1 || true)"
echo "$model" | grep -qi 'Raspberry Pi 4' && ok "Modelo: Pi 4 detectada" || { err "Não parece ser uma Raspberry Pi 4 (modelo: $model)"; fail=1; }

arch="$(grep -A1 '### arquitetura' "$REPORT" | tail -1 || true)"
case "$arch" in arm64|armhf) ok "Arquitetura: $arch" ;; *) err "Arquitetura inesperada: $arch"; fail=1 ;; esac

# Espaço livre na raiz (precisa >= 8GB)
avail_g="$(pi_ssh "df -BG --output=avail / | tail -1 | tr -dc '0-9'" 2>/dev/null || echo 0)"
if [ "${avail_g:-0}" -ge 8 ]; then ok "Espaço livre em /: ${avail_g}G (>= 8G)"; else err "Espaço livre insuficiente em /: ${avail_g}G (< 8G)"; fail=1; fi

# Sistema de arquivos somente leitura?
if pi_ssh 'touch /tmp/.lasdpc_rw_test 2>/dev/null && rm -f /tmp/.lasdpc_rw_test'; then ok "Sistema de arquivos gravável"; else err "Sistema de arquivos parece somente-leitura"; fail=1; fi

# Temperatura
temp="$(pi_ssh "vcgencmd measure_temp 2>/dev/null | tr -dc '0-9.'" 2>/dev/null || echo 0)"
if [ -n "$temp" ] && awk "BEGIN{exit !($temp < 80)}"; then ok "Temperatura: ${temp}°C (< 80)"; else warn "Temperatura alta ou indisponível: ${temp}°C — verifique refrigeração antes de cargas pesadas"; fi

# Throttling
thr="$(pi_ssh "vcgencmd get_throttled 2>/dev/null" 2>/dev/null || echo '')"
if echo "$thr" | grep -q 'throttled=0x0'; then ok "Sem throttling ($thr)"; else warn "Throttling/undervoltage detectado: $thr — verifique fonte de alimentação"; fi

echo
if [ "$fail" -ne 0 ]; then
  die "BLOQUEIO: pré-requisitos não atendidos. Reveja $REPORT antes de prosseguir com a instalação."
fi
ok "Pré-requisitos OK. Ambiente apto para as próximas etapas."
