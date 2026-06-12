#!/usr/bin/env bash
# ============================================================
# Instalação do Kodi AUTO-CONTIDA (roda na Pi como root, destacado).
# Idempotente. Status em /var/log/lasdpc/kodi.status
# ============================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
mkdir -p /var/log/lasdpc
STATUS=/var/log/lasdpc/kodi.status
echo "RUNNING $(date -Iseconds)" > "$STATUS"

if command -v kodi >/dev/null 2>&1; then
  echo ">> Kodi já instalado"
else
  echo ">> Instalando Kodi + addons"
  apt-get update -qq
  apt-get install -y kodi kodi-peripheral-joystick kodi-inputstream-adaptive
fi

KHOME=$(getent passwd lasdpc | cut -d: -f6)
mkdir -p "$KHOME/.kodi/userdata"
if [ ! -f "$KHOME/.kodi/userdata/advancedsettings.xml" ]; then
  cat > "$KHOME/.kodi/userdata/advancedsettings.xml" <<'XML'
<advancedsettings>
  <video><adjustrefreshrate>2</adjustrefreshrate></video>
  <gui><algorithmdirtyregions>3</algorithmdirtyregions></gui>
</advancedsettings>
XML
fi
chown -R lasdpc:lasdpc "$KHOME/.kodi"

echo "DONE $(date -Iseconds)" > "$STATUS"
echo "KODI-COMPLETE"
