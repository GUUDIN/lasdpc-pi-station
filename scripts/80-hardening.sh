#!/usr/bin/env bash
# ============================================================
# 80 — Hardening (Etapa 13), conservador e com SALVAGUARDA.
# - SSH: sem root, sem senha (key-only) — chave já validada.
# - Firewall ufw: deny in / allow out; tailscale0 liberado; SSH+VNC+IoT da LAN.
# - Backstop: desliga ufw sozinho em 180s se eu perder acesso (auto-revert).
# - unattended-upgrades só de segurança.
# Idempotente.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

LANNET="${LAN_CIDR:-10.0.0.0/22}"
log "Etapa 13 — hardening em $PI_HOST (LAN=$LANNET)"

# --- 0) Baseline: confirmar SSH antes de mexer ---
pi_ssh 'echo "sessão base OK: $(whoami)@$(hostname)"' >/dev/null || die "SSH base falhou; aborto."

# --- 1) SSH hardening (key-only, sem root) ---
log ">> SSH: PermitRootLogin no + PasswordAuthentication no (chave já validada)"
pi_ssh "set -e
  sudo install -m 0755 -d /etc/ssh/sshd_config.d
  printf 'PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nChallengeResponseAuthentication no\nPubkeyAuthentication yes\n' | sudo tee /etc/ssh/sshd_config.d/10-lasdpc-hardening.conf >/dev/null
  sudo sshd -t && sudo systemctl reload ssh && echo '   sshd recarregado'
"
# Valida que a chave ainda conecta (sessão nova)
if pi_ssh 'echo SSH-KEY-OK' | grep -q SSH-KEY-OK; then ok "SSH por chave segue funcionando"; else die "SSH quebrou após hardening — reveja manualmente."; fi

# --- 2) Firewall ufw com backstop de auto-revert ---
log ">> Firewall ufw (com auto-revert em 180s como rede de segurança)"
pi_ssh "set -e
  command -v ufw >/dev/null 2>&1 || { sudo apt-get update -qq && sudo apt-get install -y ufw; }
  # BACKSTOP: agenda desligar o ufw em 180s; cancelo depois se o acesso seguir ok
  sudo systemctl stop lasdpc-ufw-revert.timer 2>/dev/null || true
  sudo systemd-run --on-active=180 --unit=lasdpc-ufw-revert /usr/sbin/ufw --force disable >/dev/null 2>&1 || true
  echo '   backstop armado (ufw disable em 180s se eu sumir)'

  sudo ufw --force reset >/dev/null
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  # Tailscale: libera a interface inteira (acesso remoto preservado)
  sudo ufw allow in on tailscale0 comment 'tailnet'
  sudo ufw allow 41641/udp comment 'tailscale p2p'
  # SSH e serviços só da LAN
  sudo ufw allow from $LANNET to any port 22 proto tcp comment 'ssh lan'
  sudo ufw allow from $LANNET to any port 5900 proto tcp comment 'vnc lan'
  for p in 1880 3000 8086 1883 8080; do sudo ufw allow from $LANNET to any port \$p proto tcp comment 'iot lan'; done
  sudo ufw --force enable
  echo '   ufw habilitado'
"

# --- 3) Verificar acesso e CANCELAR o backstop ---
sleep 3
if pi_ssh 'echo POS-UFW-OK' | grep -q POS-UFW-OK; then
  ok "SSH OK após ufw — cancelando auto-revert"
  pi_ssh "sudo systemctl stop lasdpc-ufw-revert.timer 2>/dev/null; sudo systemctl reset-failed lasdpc-ufw-revert 2>/dev/null; sudo ufw status verbose | head -20"
else
  die "Perdi acesso após ufw — o backstop vai desligar o firewall em <180s. Reveja as regras."
fi

# --- 4) Atualizações automáticas só de segurança ---
log ">> unattended-upgrades (apenas segurança)"
pi_ssh "set -e
  sudo apt-get install -y unattended-upgrades >/dev/null 2>&1 || true
  echo 'APT::Periodic::Update-Package-Lists \"1\";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
  echo 'APT::Periodic::Unattended-Upgrade \"1\";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
  echo '   unattended-upgrades de segurança ativo'
"

warn "NOTA: portas publicadas pelo Docker contornam o ufw (DOCKER chain). A proteção real aqui é: Pi atrás de NAT + acesso via Tailscale. Ver docs/security.md."
ok "Hardening concluído (com salvaguarda). Acesso por chave + Tailscale preservado."
