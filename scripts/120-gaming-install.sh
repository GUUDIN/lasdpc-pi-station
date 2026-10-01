#!/usr/bin/env bash
# ============================================================
# 120 — Etapa 4: instala perfil GAMING (RetroArch+cores+ES-DE).
# Envia o wrapper + instalador e roda DESTACADO (downloads pesados).
# Idempotente. Acompanhe com: ./scripts/121-gaming-check.sh
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 4 — gaming em $PI_HOST (RetroArch apt + cores + ES-DE 3.4.1)"

log ">> Enviando wrapper lasdpc-esde e instalador"
pi_rsync -a "$PROJECT_DIR/remote/bin/lasdpc-esde" "$PI_USER@$PI_HOST:/tmp/lasdpc-esde"
pi_ssh "sudo mv /tmp/lasdpc-esde /usr/local/bin/lasdpc-esde && sudo chmod 755 /usr/local/bin/lasdpc-esde"
pi_rsync -a "$PROJECT_DIR/remote/bin/lasdpc-gaming-install.sh" "$PI_USER@$PI_HOST:/home/$PI_USER/lasdpc-gaming-install.sh"

log ">> Lançando instalação DESTACADA (systemd-run)"
pi_ssh "sudo mkdir -p /var/log/lasdpc
  sudo systemctl reset-failed lasdpc-gaming 2>/dev/null || true
  sudo systemd-run --unit=lasdpc-gaming --collect /bin/bash -c 'mkdir -p /var/log/lasdpc; LASDPC_USER=$PI_USER exec bash /home/$PI_USER/lasdpc-gaming-install.sh >> /var/log/lasdpc/gaming.log 2>&1'
  sleep 3
  echo \"   gaming ativo? \$(systemctl is-active lasdpc-gaming)\"
  echo \"   status: \$(cat /var/log/lasdpc/gaming.status 2>/dev/null)\""
ok "Instalação gaming em andamento. Valide depois com: make gaming-check"
