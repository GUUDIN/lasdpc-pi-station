#!/usr/bin/env bash
# ============================================================
# lasdpc-ubol-install.sh — instala o uBlock Origin Lite (MV3) descompactado em
# /opt/lasdpc-pi-station/kiosk/ubol e a politica do Chromium que o configura.
# O Chromium >= 139 nao carrega mais o uBlock Origin classico (MV2); o Lite e a
# versao MV3 oficial do mesmo autor (github.com/uBlockOrigin/uBOL-home).
# Versao fixada + sha256 conferido. Idempotente. Roda na Pi (usa sudo).
# ============================================================
set -euo pipefail
VERSION="2026.1006.1931"
SHA256="1670f92590f5ad5b20f02d0a75e144572567b4ba979b3dc3204c41f651206fe7"
URL="https://github.com/uBlockOrigin/uBOL-home/releases/download/${VERSION}/uBOLite_${VERSION}.chromium.zip"
DEST=/opt/lasdpc-pi-station/kiosk/ubol
POLICY=/etc/chromium/policies/managed/lasdpc-ubol.json

if [ "$(cat "$DEST/.version" 2>/dev/null)" != "$VERSION" ]; then
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/ubol.zip" "$URL"
  echo "$SHA256  $tmp/ubol.zip" | sha256sum -c --quiet
  sudo rm -rf "$DEST" && sudo mkdir -p "$DEST"
  sudo unzip -q "$tmp/ubol.zip" -d "$DEST"
  echo "$VERSION" | sudo tee "$DEST/.version" >/dev/null
  rm -rf "$tmp"
  echo "uBO Lite $VERSION instalado em $DEST"
fi

# ID de extensao descompactada = sha256 do caminho absoluto, em letras a-p
ID="$(python3 -c "import hashlib,sys;h=hashlib.sha256(sys.argv[1].encode()).hexdigest()[:32];print(''.join(chr(97+int(c,16)) for c in h))" "$(realpath "$DEST")")"
# sem pagina de boas-vindas (abriria uma aba por cima do kiosk) e sem contador
sudo mkdir -p "$(dirname "$POLICY")"
printf '{"3rdparty":{"extensions":{"%s":{"disableFirstRunPage":true,"showBlockedCount":false}}}}\n' "$ID" \
  | sudo tee "$POLICY" >/dev/null
echo "politica do uBO Lite ($ID) em $POLICY"
