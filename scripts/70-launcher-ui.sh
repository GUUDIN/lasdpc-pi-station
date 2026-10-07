#!/usr/bin/env bash
# ============================================================
# 70 — Menu central LASDPC Station (servidor local) + serviço systemd.
# Instala launcher/ em /opt e o serviço lasdpc-launcher (localhost:8090).
# Idempotente.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env
LAUNCHER="$REMOTE_BASE/launcher"

log "Etapa 6 — menu central em $PI_HOST"

log ">> Enviando app do menu para $LAUNCHER"
pi_ssh "sudo mkdir -p $LAUNCHER && sudo chown $PI_USER:$PI_USER $LAUNCHER"
pi_rsync -a "$PROJECT_DIR/remote/launcher/" "$PI_USER@$PI_HOST:$LAUNCHER/"

log ">> Extensoes do kiosk (escape/Menu, h264ify, anuncios do YouTube TV) + uBO Lite"
pi_ssh "sudo mkdir -p $REMOTE_BASE/kiosk && sudo chown $PI_USER:$PI_USER $REMOTE_BASE/kiosk"
for ext in escape-extension h264ify-extension ytads-extension; do
  pi_rsync -a --delete "$PROJECT_DIR/remote/kiosk/$ext/" "$PI_USER@$PI_HOST:$REMOTE_BASE/kiosk/$ext/"
done
for b in lasdpc-youtube lasdpc-ubol-install.sh; do
  pi_rsync -a "$PROJECT_DIR/remote/bin/$b" "$PI_USER@$PI_HOST:/tmp/$b"
  pi_ssh "sudo install -o root -g root -m 0755 /tmp/$b /usr/local/bin/$b"
done
pi_ssh "/usr/local/bin/lasdpc-ubol-install.sh"
# Barra de traducao: as flags --disable-translate/Translate nao valem mais no
# Chromium >= ~140; so a politica gerenciada esconde (ver docs/troubleshooting.md)
pi_ssh "sudo mkdir -p /etc/chromium/policies/managed && echo '{\"TranslateEnabled\": false}' | sudo tee /etc/chromium/policies/managed/lasdpc-kiosk.json >/dev/null"

log ">> Instalando serviço systemd lasdpc-launcher"
pi_rsync -a "$PROJECT_DIR/remote/systemd/lasdpc-launcher.service" "$PI_USER@$PI_HOST:/tmp/lasdpc-launcher.service"
pi_ssh "sed -i 's/^User=.*/User=$PI_USER/' /tmp/lasdpc-launcher.service"
pi_ssh "set -e
  sudo mv /tmp/lasdpc-launcher.service /etc/systemd/system/lasdpc-launcher.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now lasdpc-launcher
  sleep 2
  systemctl is-active lasdpc-launcher
"
log ">> Testando o menu em localhost:8090"
pi_ssh "curl -fsS -o /dev/null -w '   HTTP %{http_code}\n' http://localhost:8090/ && curl -fsS http://localhost:8090/api/status | head -c 200; echo"
ok "Menu central no ar (localhost:8090)."
