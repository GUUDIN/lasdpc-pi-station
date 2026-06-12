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

log ">> Instalando serviço systemd lasdpc-launcher"
pi_rsync -a "$PROJECT_DIR/remote/systemd/lasdpc-launcher.service" "$PI_USER@$PI_HOST:/tmp/lasdpc-launcher.service"
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
