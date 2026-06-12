#!/usr/bin/env bash
# ============================================================
# 10 — Sistema-base (conservador e idempotente).
# hostname, timezone, locale pt_BR.UTF-8, teclado br/ABNT2, NTP,
# apt update + upgrade ESTÁVEL (sem dist/full-upgrade), pacotes básicos,
# limite de journald p/ poupar o microSD. NÃO remove o desktop.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 4 — sistema-base em $PI_HOST (hostname=$PI_HOSTNAME, tz=$PI_TIMEZONE, locale=$PI_LOCALE, kbd=$PI_KEYBOARD)"

REMOTE=$(cat <<REOF
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo ">> Hostname"
cur=\$(hostnamectl --static 2>/dev/null || true)
if [ "\$cur" != "$PI_HOSTNAME" ]; then
  sudo hostnamectl set-hostname "$PI_HOSTNAME"
  echo "   hostname ajustado: \$cur -> $PI_HOSTNAME"
else
  echo "   já é $PI_HOSTNAME"
fi
if ! grep -qE "^127.0.1.1[[:space:]]+$PI_HOSTNAME\b" /etc/hosts; then
  if grep -qE "^127.0.1.1" /etc/hosts; then
    sudo sed -i "s/^127.0.1.1.*/127.0.1.1\t$PI_HOSTNAME/" /etc/hosts
  else
    printf '127.0.1.1\t%s\n' "$PI_HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
  fi
  echo "   /etc/hosts atualizado"
fi

echo ">> Timezone"
if [ "\$(cat /etc/timezone 2>/dev/null)" != "$PI_TIMEZONE" ]; then
  sudo timedatectl set-timezone "$PI_TIMEZONE"
  echo "   timezone -> $PI_TIMEZONE"
else echo "   já é $PI_TIMEZONE"; fi

echo ">> NTP"
sudo timedatectl set-ntp true || true
echo "   NTP: \$(timedatectl show -p NTP --value 2>/dev/null)"

echo ">> Locale ($PI_LOCALE)"
if ! locale -a 2>/dev/null | grep -qiE "pt_BR.utf8|pt_BR.UTF-8"; then
  sudo sed -i "s/^# *${PI_LOCALE} UTF-8/${PI_LOCALE} UTF-8/" /etc/locale.gen || true
  grep -q "^${PI_LOCALE} UTF-8" /etc/locale.gen || echo "${PI_LOCALE} UTF-8" | sudo tee -a /etc/locale.gen >/dev/null
  sudo locale-gen
  echo "   locale gerado"
else echo "   $PI_LOCALE já existe"; fi
sudo update-locale LANG="$PI_LOCALE" LC_ALL= || true
echo "   LANG padrão -> $PI_LOCALE (efetivo no próximo login)"

echo ">> Teclado ($PI_KEYBOARD / ABNT2)"
kb=/etc/default/keyboard
if ! grep -q "XKBLAYOUT=\"$PI_KEYBOARD\"" "\$kb" 2>/dev/null; then
  sudo sed -i "s/^XKBLAYOUT=.*/XKBLAYOUT=\"$PI_KEYBOARD\"/" "\$kb" 2>/dev/null || true
  grep -q "^XKBLAYOUT=" "\$kb" 2>/dev/null || echo "XKBLAYOUT=\"$PI_KEYBOARD\"" | sudo tee -a "\$kb" >/dev/null
  sudo sed -i 's/^XKBMODEL=.*/XKBMODEL="abnt2"/' "\$kb" 2>/dev/null || true
  sudo setupcon --save 2>/dev/null || true
  echo "   teclado -> $PI_KEYBOARD/abnt2"
else echo "   teclado já é $PI_KEYBOARD"; fi

echo ">> apt update + upgrade ESTÁVEL (sem dist/full-upgrade)"
sudo apt-get update -qq
UPGRADABLE=\$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
echo "   pacotes a atualizar: \$UPGRADABLE"
sudo apt-get -y upgrade
sudo apt-get -y autoremove --purge
echo "   upgrade concluído"

echo ">> Pacotes básicos"
PKGS="git curl wget rsync jq unzip zip htop tmux vim nano lsof tree dnsutils net-tools smartmontools usbutils pciutils ca-certificates gnupg python3 python3-venv python3-pip"
sudo apt-get install -y \$PKGS
echo "   pacotes instalados/presentes"

echo ">> Limite de journald (poupa o microSD)"
sudo mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\nCompress=yes\nSystemMaxUse=100M\nSystemMaxFileSize=20M\nMaxRetentionSec=2week\nRateLimitIntervalSec=30s\nRateLimitBurst=1000\n' | sudo tee /etc/systemd/journald.conf.d/lasdpc.conf >/dev/null
sudo systemctl restart systemd-journald || true
echo "   journald limitado a 100M"

echo ">> Armazenamento: microSD (mmcblk) — TRIM não aplicável, ignorado por segurança"

echo ">> RESUMO"
echo "   hostname: \$(hostnamectl --static)"
echo "   timezone: \$(cat /etc/timezone)"
echo "   locale:   \$(grep LANG= /etc/default/locale 2>/dev/null || true)"
echo "   kernel:   \$(uname -r)"
echo "   uptime:   \$(uptime -p)"
echo "BASE-OK"
REOF
)

pi_ssh "$REMOTE" 2>&1 | tee "$LOG_DIR/base-$(ts).log"
ok "Sistema-base concluído (ver log acima)."
warn "Locale/teclado têm efeito pleno após novo login/reboot (reboot ao final do deploy)."
