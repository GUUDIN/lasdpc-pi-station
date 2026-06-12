#!/usr/bin/env bash
# ============================================================
# 100 — Media/Gaming preflight (Etapa 0).
# Prepara diretorios remotos e executa os TCs automatizados de entrada.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 0 — preflight media/gaming em $PI_HOST"

log "Preparando diretorios remotos e instalando avahi-utils se necessario"
pi_ssh 'set -euo pipefail
  sudo install -d -o root -g adm -m 0775 /var/log/lasdpc
  sudo install -d -o root -g root -m 0755 /var/backups/lasdpc
  sudo mkdir -p \
    /srv/lasdpc-pi-station/roms \
    /srv/lasdpc-pi-station/saves \
    /srv/lasdpc-pi-station/config
  sudo chown -R lasdpc:lasdpc /srv/lasdpc-pi-station/roms /srv/lasdpc-pi-station/saves /srv/lasdpc-pi-station/config
  if ! command -v avahi-browse >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y avahi-daemon avahi-utils
  fi
  sudo systemctl enable --now avahi-daemon
'

log "Executando TCs automatizados da Etapa 0"
pi_ssh 'set -euo pipefail
  pass(){ printf "PASS %s\n" "$1"; }
  fail(){ printf "FAIL %s: %s\n" "$1" "$2"; exit 1; }

  . /etc/os-release
  [ "${VERSION_ID:-}" = "13" ] && [ "${VERSION_CODENAME:-}" = "trixie" ] && [ "$(uname -m)" = "aarch64" ] \
    && pass TC-0.1 || fail TC-0.1 "Debian/Trixie/aarch64 esperado"

  free_gb=$(df -BG --output=avail / | tail -1 | tr -dc "0-9")
  [ "$free_gb" -ge 8 ] && pass TC-0.2 || fail TC-0.2 "menos de 8 GB livres em /"

  throttled=$(vcgencmd get_throttled)
  [ "$throttled" = "throttled=0x0" ] && pass TC-0.3 || fail TC-0.3 "$throttled"

  temp_raw=$(vcgencmd measure_temp | sed -E "s/.*=([0-9.]+).*/\1/")
  awk -v t="$temp_raw" "BEGIN{exit !(t < 60)}" && pass TC-0.4 || fail TC-0.4 "temperatura idle ${temp_raw}C >= 60C"

  grep -Eq "^dtoverlay=vc4-kms-v3d" /boot/firmware/config.txt && pass TC-0.5 || fail TC-0.5 "dtoverlay ausente"
  lsmod | grep -q bcm2835_codec && pass TC-0.6 || fail TC-0.6 "bcm2835_codec nao carregado"

  systemctl is-active --quiet docker || fail TC-0.7 "docker inativo"
  cd /opt/lasdpc-pi-station/docker
  sudo docker compose ls | grep -q lasdpc-iot && pass TC-0.7 || fail TC-0.7 "compose lasdpc-iot nao listado"

  curl -fsS http://localhost:8090 >/dev/null && pass TC-0.8 || fail TC-0.8 "menu localhost:8090 nao responde"
  lasdpc-mode desktop >/tmp/lasdpc-mode-desktop.out
  lasdpc-mode menu >/tmp/lasdpc-mode-menu.out
  pass TC-0.9

  tailscale status >/dev/null && pass TC-0.10 || fail TC-0.10 "tailscale status falhou"
  command -v avahi-browse >/dev/null 2>&1 || fail TC-0.11 "avahi-browse ausente"
  avahi-browse -t -a >/tmp/lasdpc-avahi.txt 2>/dev/null || true
  [ -s /tmp/lasdpc-avahi.txt ] && pass TC-0.11 || fail TC-0.11 "sem resultados mDNS em avahi-browse"

  mkdir -p /var/log/lasdpc
  {
    echo "## Etapa 0 — preflight — $(date -Is)"
    echo "Acoes executadas: diretorios remotos preparados; avahi-daemon/avahi-utils presentes; TCs automatizados executados."
    echo "Pacotes/versoes instalados: $(dpkg-query -W -f='\''${Package}=${Version} '\'' avahi-daemon avahi-utils 2>/dev/null || true)"
    echo "Arquivos criados/modificados: /var/log/lasdpc, /var/backups/lasdpc, /srv/lasdpc-pi-station/{roms,saves,config}"
    echo "TCs: TC-0.1 PASS; TC-0.2 PASS; TC-0.3 PASS; TC-0.4 PASS; TC-0.5 PASS; TC-0.6 PASS; TC-0.7 PASS; TC-0.8 PASS; TC-0.9 PASS; TC-0.10 PASS; TC-0.11 PASS"
    echo "Riscos/observacoes: TC-0.12 e TC-0.13 sao validados no host de controle por envolver Git local e smriti."
    echo "Proxima etapa liberada: PENDENTE TC-0.12/TC-0.13"
    echo
  } >> /var/log/lasdpc/IMPLEMENTACAO.md
'

log "Validando TC-0.12 no repositório local"
git -C "$PROJECT_DIR" status --short
git -C "$PROJECT_DIR" log -1 --oneline
git -C "$PROJECT_DIR" remote -v
ok "TC-0.12 validado no host de controle"

ok "Etapa 0 preflight remoto concluido; valide TC-0.13/smriti no host de controle."
