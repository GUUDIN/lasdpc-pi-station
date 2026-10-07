#!/usr/bin/env bash
# App YouTube: YouTube TV no Chromium kiosk + h264ify (decoder de hardware),
# uBlock Origin Lite e ytads (sem anuncios). Ver docs/operation.md#youtube.
. "$REPO/station/lib/common.sh"
install_bin lasdpc-youtube lasdpc-ubol-install.sh
for ext in h264ify-extension ytads-extension; do
  sync_dir "$REPO/remote/kiosk/$ext/" "$BASE_DIR/kiosk/$ext/"
done
/usr/local/bin/lasdpc-ubol-install.sh
