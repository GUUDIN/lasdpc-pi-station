#!/usr/bin/env bash
# ============================================================
# 50 — Kodi e multimídia (Etapa 9).
# Instala Kodi (build oficial RPi) + joystick + inputstream-adaptive.
# Áudio HDMI, retorno ao menu ao sair (via lasdpc-session), CEC nativo.
# Sem addons piratas, sem DRM. Idempotente. Instala detached (download grande).
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 9 — Kodi em $PI_HOST"

REMOTE=$(cat <<'REOF'
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
mkdir -p /var/log/lasdpc
STATUS=/var/log/lasdpc/kodi.status
echo "RUNNING $(date -Iseconds)" > "$STATUS"

if command -v kodi >/dev/null 2>&1; then
  echo ">> Kodi já instalado: $(kodi --version 2>/dev/null | head -1)"
else
  echo ">> Instalando Kodi + addons (joystick, inputstream-adaptive)"
  apt-get update -qq
  apt-get install -y kodi kodi-peripheral-joystick kodi-inputstream-adaptive
fi

KUSER_HOME=$(getent passwd lasdpc | cut -d: -f6)
KDIR="$KUSER_HOME/.kodi/userdata"
mkdir -p "$KDIR"
if [ ! -f "$KDIR/advancedsettings.xml" ]; then
  cat > "$KDIR/advancedsettings.xml" <<XML
<advancedsettings>
  <video>
    <adjustrefreshrate>2</adjustrefreshrate>
  </video>
  <gui>
    <algorithmdirtyregions>3</algorithmdirtyregions>
  </gui>
</advancedsettings>
XML
fi
chown -R lasdpc:lasdpc "$KUSER_HOME/.kodi"
echo "   ~/.kodi preparado"

echo "DONE $(date -Iseconds)" > "$STATUS"
echo "KODI-COMPLETE"
REOF
)

log ">> Lançando instalação do Kodi destacada (systemd-run)"
TMP=$(mktemp)
printf '%s\n' "$REMOTE" > "$TMP"
pi_rsync -a "$TMP" "$PI_USER@$PI_HOST:/home/$PI_USER/lasdpc-kodi.sh"
rm -f "$TMP"
pi_ssh "sudo systemctl reset-failed lasdpc-kodi 2>/dev/null || true
  sudo systemd-run --unit=lasdpc-kodi --collect /bin/bash -c 'exec bash /home/$PI_USER/lasdpc-kodi.sh >> /var/log/lasdpc/kodi.log 2>&1'
  sleep 2; echo \"   lasdpc-kodi: \$(systemctl is-active lasdpc-kodi)\""
ok "Instalação do Kodi em andamento (destacada)."
warn "Streaming com DRM (Netflix/Prime/Disney+) pode não funcionar como em dispositivo certificado — ver docs/troubleshooting.md."
