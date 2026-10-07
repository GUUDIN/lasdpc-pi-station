#!/usr/bin/env bash
# App Spotify: "TV LASDPC" no Spotify Connect.
#  - Spotify Soloist (oficial): liga quando a chave existe (sudo lasdpc-soloist-setkey)
#  - librespot (raspotify) como reserva enquanto nao ha chave; o Spotify recusa a
#    chave de audio a ele para contas novas (docs/troubleshooting.md)
. "$REPO/station/lib/common.sh"

# --- Soloist
install_bin lasdpc-soloist-update lasdpc-soloist-run lasdpc-soloist-setkey
install -d "$BASE_DIR/soloist/runtime"
install_file "$REPO/remote/soloist/Dockerfile" "$BASE_DIR/soloist/runtime/Dockerfile" || true
changed=0
for u in lasdpc-soloist.service lasdpc-soloist-update.service lasdpc-soloist-update.timer; do
  install_system_unit "$REPO/remote/systemd/$u" && changed=1
done
[ "$changed" = 1 ] && systemctl daemon-reload
if ! glibc_at_least 2.38 && ! command -v docker >/dev/null 2>&1; then
  warn "Soloist precisa de glibc >= 2.38 (Trixie) ou Docker; neste sistema so a reserva librespot funciona"
else
  /usr/local/bin/lasdpc-soloist-update || warn "download do Soloist falhou"
  systemctl enable --quiet --now lasdpc-soloist-update.timer
fi

# --- reserva librespot (so enquanto o Soloist nao tem chave)
RASPOTIFY_VERSION="0.48.3"
RASPOTIFY_PKGVER="0.48.3~librespot.v0.8.0-939dc5e"
RASPOTIFY_DEB="raspotify_0.48.3.librespot.v0.8.0-939dc5e_arm64.deb"
RASPOTIFY_SHA256="2097b3994824cf17163ecc47c6f6a5a695202987e2ab0b650f50d663291c63f2"
if [ "$(dpkg-query -W -f='${Version}' raspotify 2>/dev/null || true)" != "$RASPOTIFY_PKGVER" ]; then
  curl -fsSL -o "/tmp/$RASPOTIFY_DEB" "https://github.com/dtcooper/raspotify/releases/download/$RASPOTIFY_VERSION/$RASPOTIFY_DEB"
  echo "$RASPOTIFY_SHA256  /tmp/$RASPOTIFY_DEB" | sha256sum -c --quiet
  DEBIAN_FRONTEND=noninteractive apt-get install -y "/tmp/$RASPOTIFY_DEB"
fi
# o servico de sistema da raspotify briga com o PipeWire da sessao: so o binario e usado
systemctl disable --now raspotify >/dev/null 2>&1 || true
install_user_unit "$REPO/remote/systemd/user/lasdpc-spotify.service"
if session_running; then
  userctl systemctl --user daemon-reload
  if [ -f /etc/lasdpc/soloist.env ]; then
    userctl systemctl --user disable --now lasdpc-spotify.service >/dev/null 2>&1 || true
    systemctl enable --quiet lasdpc-soloist.service
  else
    userctl systemctl --user enable --now lasdpc-spotify.service >/dev/null 2>&1 || true
  fi
fi
