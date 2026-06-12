#!/usr/bin/env bash
# ============================================================
# 90 — Healthcheck (Etapa 14). Instala o script + timer na Pi e roda agora.
# Idempotente.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 14 — healthcheck em $PI_HOST"

log ">> Instalando script e timer"
pi_rsync -a "$PROJECT_DIR/remote/bin/lasdpc-healthcheck.sh" "$PI_USER@$PI_HOST:/tmp/lasdpc-healthcheck.sh"
pi_rsync -a "$PROJECT_DIR/remote/systemd/lasdpc-healthcheck.service" "$PI_USER@$PI_HOST:/tmp/lasdpc-healthcheck.service"
pi_rsync -a "$PROJECT_DIR/remote/systemd/lasdpc-healthcheck.timer" "$PI_USER@$PI_HOST:/tmp/lasdpc-healthcheck.timer"
pi_ssh "set -e
  sudo mv /tmp/lasdpc-healthcheck.sh /usr/local/bin/lasdpc-healthcheck.sh && sudo chmod 755 /usr/local/bin/lasdpc-healthcheck.sh
  sudo mv /tmp/lasdpc-healthcheck.service /etc/systemd/system/lasdpc-healthcheck.service
  sudo mv /tmp/lasdpc-healthcheck.timer /etc/systemd/system/lasdpc-healthcheck.timer
  sudo systemctl daemon-reload
  sudo systemctl enable --now lasdpc-healthcheck.timer
  echo '   timer: '\$(systemctl is-active lasdpc-healthcheck.timer)
"
log ">> Rodando healthcheck agora"
pi_ssh "/usr/local/bin/lasdpc-healthcheck.sh" || warn "healthcheck retornou problemas (ver acima)"
ok "Healthcheck instalado (timer a cada 15 min) e executado."
