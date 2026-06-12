#!/usr/bin/env bash
# ============================================================
# Finalização do sistema-base, AUTO-CONTIDA e DESTACADA (roda na Pi).
# Idempotente. Lançada via systemd-run para sobreviver a quedas de SSH/Wi-Fi.
# Grava progresso em /var/log/lasdpc/base.log e status em /var/log/lasdpc/base.status
# ============================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

HOSTNAME_WANT="lasdpc-pi-display-01"
TZ_WANT="America/Sao_Paulo"
LOCALE_WANT="pt_BR.UTF-8"
KBD_WANT="br"

mkdir -p /var/log/lasdpc
STATUS=/var/log/lasdpc/base.status
echo "RUNNING $(date -Iseconds)" > "$STATUS"

step(){ echo ">> $*"; }

step "Hostname"
[ "$(hostnamectl --static)" = "$HOSTNAME_WANT" ] || hostnamectl set-hostname "$HOSTNAME_WANT"
grep -qE "^127.0.1.1[[:space:]]+$HOSTNAME_WANT\b" /etc/hosts || \
  { grep -qE '^127.0.1.1' /etc/hosts && sed -i "s/^127.0.1.1.*/127.0.1.1\t$HOSTNAME_WANT/" /etc/hosts || printf '127.0.1.1\t%s\n' "$HOSTNAME_WANT" >> /etc/hosts; }

step "Timezone + NTP"
[ "$(cat /etc/timezone 2>/dev/null)" = "$TZ_WANT" ] || timedatectl set-timezone "$TZ_WANT"
timedatectl set-ntp true || true

step "Locale $LOCALE_WANT"
if ! locale -a 2>/dev/null | grep -qiE 'pt_BR.utf8|pt_BR.UTF-8'; then
  sed -i "s/^# *${LOCALE_WANT} UTF-8/${LOCALE_WANT} UTF-8/" /etc/locale.gen || true
  grep -q "^${LOCALE_WANT} UTF-8" /etc/locale.gen || echo "${LOCALE_WANT} UTF-8" >> /etc/locale.gen
  locale-gen
fi
update-locale LANG="$LOCALE_WANT" LC_ALL= || true

step "Teclado $KBD_WANT/ABNT2"
kb=/etc/default/keyboard
if ! grep -q "XKBLAYOUT=\"$KBD_WANT\"" "$kb" 2>/dev/null; then
  sed -i "s/^XKBLAYOUT=.*/XKBLAYOUT=\"$KBD_WANT\"/" "$kb" 2>/dev/null || true
  grep -q '^XKBLAYOUT=' "$kb" 2>/dev/null || echo "XKBLAYOUT=\"$KBD_WANT\"" >> "$kb"
  sed -i 's/^XKBMODEL=.*/XKBMODEL="abnt2"/' "$kb" 2>/dev/null || true
  setupcon --save 2>/dev/null || true
fi

step "apt update + autoremove (upgrade pesado já feito)"
apt-get update -qq || true
apt-get -y autoremove --purge || true

step "Pacotes básicos"
PKGS="git curl wget rsync jq unzip zip htop tmux vim nano lsof tree dnsutils net-tools smartmontools usbutils pciutils ca-certificates gnupg python3 python3-venv python3-pip"
apt-get install -y $PKGS

step "journald limitado (poupa microSD)"
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\nCompress=yes\nSystemMaxUse=100M\nSystemMaxFileSize=20M\nMaxRetentionSec=2week\nRateLimitIntervalSec=30s\nRateLimitBurst=1000\n' > /etc/systemd/journald.conf.d/lasdpc.conf
systemctl restart systemd-journald || true

step "RESUMO"
echo "   hostname: $(hostnamectl --static)"
echo "   timezone: $(cat /etc/timezone)"
echo "   locale:   $(grep LANG= /etc/default/locale 2>/dev/null || true)"
echo "   pacotes-base instalados: OK"

echo "DONE $(date -Iseconds)" > "$STATUS"
echo "BASE-COMPLETE"
