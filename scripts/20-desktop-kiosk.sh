#!/usr/bin/env bash
# ============================================================
# 20 — Kiosk Chromium (Wayland/labwc) + máquina de estados de modos.
# Instala comandos (lasdpc-mode/session/kiosk/status/restart-kiosk),
# fallback local, session.env, autostart do labwc e desativa screen blanking.
# NÃO substitui o desktop: o modo "desktop" mantém o ambiente normal.
# Idempotente.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 5 — kiosk/modos em $PI_HOST (compositor: Wayland/labwc)"

# URL do dashboard: usa DASHBOARD_URL do .env; se vazio, usa a homepage local
DASH_URL="${DASHBOARD_URL:-http://localhost:8080}"
INIT_MODE="${INITIAL_MODE:-menu}"

log ">> Instalando comandos em /usr/local/bin"
for b in lasdpc-mode lasdpc-session lasdpc-kiosk lasdpc-restart-kiosk lasdpc-status; do
  pi_rsync -a "$PROJECT_DIR/remote/bin/$b" "$PI_USER@$PI_HOST:/tmp/$b"
  pi_ssh "sudo mv /tmp/$b /usr/local/bin/$b && sudo chmod 755 /usr/local/bin/$b"
done

log ">> Configuração do usuário (~/.config/lasdpc) — modo, session.env, fallback"
pi_rsync -a "$PROJECT_DIR/remote/kiosk/fallback.html" "$PI_USER@$PI_HOST:/tmp/fallback.html"
pi_ssh "set -e
  mkdir -p ~/.config/lasdpc ~/.config/labwc
  mv /tmp/fallback.html ~/.config/lasdpc/fallback.html
  cat > ~/.config/lasdpc/session.env <<EOF
DASHBOARD_URL=$DASH_URL
MENU_URL=http://localhost:8090
EOF
  # Modo inicial (não sobrescreve se já existir)
  [ -f ~/.config/lasdpc/mode ] || echo '$INIT_MODE' > ~/.config/lasdpc/mode
  echo '   modo inicial: '\$(cat ~/.config/lasdpc/mode)
"

log ">> Autostart do labwc (preserva desktop + adiciona runner de modos)"
pi_rsync -a "$PROJECT_DIR/remote/kiosk/labwc-autostart" "$PI_USER@$PI_HOST:/tmp/labwc-autostart"
pi_ssh "set -e
  if [ -f ~/.config/labwc/autostart ] && ! grep -q lasdpc-session ~/.config/labwc/autostart; then
    cp ~/.config/labwc/autostart ~/.config/labwc/autostart.bak.\$(date +%Y%m%d-%H%M%S)
  fi
  mv /tmp/labwc-autostart ~/.config/labwc/autostart
  echo '   autostart instalado'
"

log ">> Desativando screen blanking (anti-suspensão da tela)"
pi_ssh "sudo raspi-config nonint do_blanking 1 2>/dev/null && echo '   blanking desativado' || echo '   (do_blanking indisponível; o kiosk usa systemd-inhibit)'"

log ">> Verificando Chromium"
pi_ssh "command -v chromium >/dev/null 2>&1 && echo '   chromium: '\$(chromium --version 2>/dev/null | head -1) || echo '   ATENCAO: chromium não encontrado'"

ok "Kiosk/modos instalados. Dashboard URL: $DASH_URL"
warn "Para aplicar a sessão agora sem reboot, recarregue o labwc (Etapa de ativação) ou reinicie a Pi."
