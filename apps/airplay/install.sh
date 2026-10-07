#!/usr/bin/env bash
# App AirPlay: UxPlay compilado (versao fixada) como servico do usuario, ligado so
# no modo airplay (lasdpc-media.target, ver app.json "services").
. "$REPO/station/lib/common.sh"
install_bin lasdpc-uxplay lasdpc-uxplay-build.sh
/usr/local/bin/lasdpc-uxplay-build.sh
for u in uxplay.service lasdpc-media.target; do
  install_user_unit "$REPO/remote/systemd/user/$u"
done
session_running && userctl systemctl --user daemon-reload || true
