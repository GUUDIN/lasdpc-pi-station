#!/usr/bin/env bash
# ============================================================
# 170 — YouTube Cast (celular -> TV): receptor Lounge/DIAL que toca no mpv com
# decode por HARDWARE. Reaproveita o pipeline do lasdpc-mpv (avc1 + dmabuf-wayland
# + v4l2m2m). O app do YouTube no celular ve a Pi como "TV LASDPC".
#  - Node.js (apt) + npm install do remote/ytcast em /opt/lasdpc-pi-station/ytcast
#  - binario lasdpc-ytcast
#  - lasdpc-mode / lasdpc-session atualizados (modo "ytcast")
#  - launcher (index.html + server.py + ytcast.html) re-sincronizado
# Idempotente. Requer: perfil base + kiosk + launcher (etapas 70/110) ja instalados.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

YTCAST_DIR="$REMOTE_BASE/ytcast"
LAUNCHER="$REMOTE_BASE/launcher"

log "Etapa 170 — YouTube Cast em $PI_HOST"

log ">> Node.js + npm (apt)"
pi_ssh "sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends nodejs npm && node --version && npm --version"

log ">> App do receptor para $YTCAST_DIR"
pi_ssh "sudo mkdir -p $YTCAST_DIR && sudo chown $PI_USER:$PI_USER $YTCAST_DIR"
pi_rsync -a "$PROJECT_DIR/remote/ytcast/" "$PI_USER@$PI_HOST:$YTCAST_DIR/"

log ">> Dependencias npm (yt-cast-receiver) — produção"
pi_ssh "cd $YTCAST_DIR && npm install --omit=dev --no-audit --no-fund && echo '   node_modules: '\$(ls node_modules 2>/dev/null | wc -l)' pacotes'"

log ">> Binario lasdpc-ytcast"
pi_rsync -a "$PROJECT_DIR/remote/bin/lasdpc-ytcast" "$PI_USER@$PI_HOST:/tmp/lasdpc-ytcast"
pi_ssh "sudo install -o root -g root -m 0755 /tmp/lasdpc-ytcast /usr/local/bin/lasdpc-ytcast"

log ">> lasdpc-mode / lasdpc-session / kiosk / loading (modo ytcast)"
for b in lasdpc-mode lasdpc-session lasdpc-kiosk lasdpc-loading lasdpc-mpv; do
  pi_rsync -a "$PROJECT_DIR/remote/bin/$b" "$PI_USER@$PI_HOST:/tmp/$b"
  pi_ssh "sudo install -o root -g root -m 0755 /tmp/$b /usr/local/bin/$b"
done

log ">> Launcher (menu + server + tela ociosa ytcast.html)"
pi_ssh "sudo mkdir -p $LAUNCHER && sudo chown $PI_USER:$PI_USER $LAUNCHER"
pi_rsync -a "$PROJECT_DIR/remote/launcher/" "$PI_USER@$PI_HOST:$LAUNCHER/"
pi_ssh "sudo systemctl restart lasdpc-launcher && sleep 1 && systemctl is-active lasdpc-launcher"

ok "YouTube Cast instalado. No menu: 'YouTube (celular)'. No celular, transmita para 'TV LASDPC'."
warn "Firewall: o ufw precisa liberar mDNS (5353/udp) e a porta DIAL 3232/tcp p/ o celular achar a TV."
