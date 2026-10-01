#!/usr/bin/env bash
# ============================================================
# 21 — Reaplicar config do labwc (rc.xml, menu.xml) + lasdpc-session ao vivo.
# Mais rápido que rodar 20-desktop-kiosk.sh inteiro.
# Idempotente; não reinicia a Pi.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "kiosk-config — aplicando labwc + lasdpc-session em $PI_HOST"

log ">> rc.xml (atalhos + regras de janela)"
pi_rsync -a "$PROJECT_DIR/remote/kiosk/labwc-rc.xml" "$PI_USER@$PI_HOST:/tmp/labwc-rc.xml"
pi_ssh "sudo cp /tmp/labwc-rc.xml /etc/xdg/labwc/rc.xml && echo '   rc.xml atualizado'"

log ">> menu.xml (botão direito no desktop)"
pi_rsync -a "$PROJECT_DIR/remote/kiosk/labwc-menu.xml" "$PI_USER@$PI_HOST:/tmp/labwc-menu.xml"
pi_ssh "mkdir -p ~/.config/labwc && mv /tmp/labwc-menu.xml ~/.config/labwc/menu.xml && echo '   menu.xml atualizado'"

log ">> lasdpc-session (runner de modos)"
pi_rsync -a "$PROJECT_DIR/remote/bin/lasdpc-session" "$PI_USER@$PI_HOST:/tmp/lasdpc-session"
pi_ssh "sudo mv /tmp/lasdpc-session /usr/local/bin/lasdpc-session && sudo chmod 755 /usr/local/bin/lasdpc-session && echo '   lasdpc-session atualizado'"

log ">> Recarregando labwc ao vivo"
# Via SSH nao ha LABWC_PID, entao 'labwc --reconfigure' falha.
# Mandamos SIGHUP direto no processo, que e o mesmo que o reconfigure faz.
pi_ssh "
  PID=\$(pgrep -x labwc | head -1)
  if [ -n \"\$PID\" ]; then
    kill -HUP \"\$PID\" && echo '   labwc recarregado via SIGHUP (atalhos e menu ativos imediatamente)'
  else
    echo '   labwc nao esta rodando — reinicie para aplicar'
  fi
"

ok "kiosk-config concluído. Super+Esc → menu central; botão direito no desktop → opções LASDPC."
