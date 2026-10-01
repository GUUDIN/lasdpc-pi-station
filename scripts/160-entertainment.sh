#!/usr/bin/env bash
# ============================================================
# 160 — Entretenimento: Video (mpv+yt-dlp), Musica (Spotify), Jogo (RetroArch).
# Instala e configura tudo de forma idempotente para replicar a estacao.
#  - mpv + yt-dlp (binario atual) + deno (JS runtime exigido pelo YouTube)
#  - fonte de emoji colorido (icones do menu)
#  - binarios lasdpc-mpv / lasdpc-play / lasdpc-retroarch (+ setup)
#  - Spotify Connect (raspotify) renomeado para "TV LASDPC"
#  - timer semanal de update do yt-dlp
#  - RetroArch: Vulkan/Ozone + parallel-rdp + controle N64 + playlist/thumbs
# Requer: perfil base + kiosk ja instalados; sudo NOPASSWD na Pi.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 160 — entretenimento em $PI_HOST"

log ">> Pacotes (mpv, fonte emoji, inputstream-adaptive, unzip)"
pi_ssh "sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends \
  mpv fonts-noto-color-emoji kodi-inputstream-adaptive unzip && fc-cache -f >/dev/null 2>&1"

log ">> yt-dlp (binario oficial, mais atual que o apt)"
pi_ssh "sudo curl -fsSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
  -o /usr/local/bin/yt-dlp && sudo chmod 755 /usr/local/bin/yt-dlp && /usr/local/bin/yt-dlp --version"

log ">> deno (JS runtime exigido pelo YouTube/yt-dlp)"
pi_ssh 'A=aarch64-unknown-linux-gnu
  sudo curl -fsSL "https://github.com/denoland/deno/releases/latest/download/deno-${A}.zip" -o /tmp/deno.zip
  sudo unzip -o /tmp/deno.zip -d /usr/local/bin/ >/dev/null && sudo chmod 755 /usr/local/bin/deno
  /usr/local/bin/deno --version | head -1'

log ">> Binarios de midia + setup do RetroArch"
for b in lasdpc-mpv lasdpc-play lasdpc-retroarch lasdpc-retroarch-setup.sh; do
  pi_rsync -a "$PROJECT_DIR/remote/bin/$b" "$PI_USER@$PI_HOST:/tmp/$b"
  pi_ssh "sudo mv /tmp/$b /usr/local/bin/$b && sudo chmod 755 /usr/local/bin/$b"
done
# helpers python (playlist/thumbnails) usados pelo setup
for p in make_n64_playlist.py fetch_thumbs.py; do
  pi_rsync -a "$PROJECT_DIR/remote/launcher/$p" "$PI_USER@$PI_HOST:/tmp/$p"
done

log ">> Spotify Connect (raspotify) renomeado para 'TV LASDPC'"
pi_ssh 'if grep -q LIBRESPOT_NAME /etc/raspotify/conf 2>/dev/null; then
    sudo sed -i "s|.*LIBRESPOT_NAME.*|LIBRESPOT_NAME=\"TV LASDPC\"|" /etc/raspotify/conf
  else echo "LIBRESPOT_NAME=\"TV LASDPC\"" | sudo tee -a /etc/raspotify/conf >/dev/null; fi
  sudo systemctl restart raspotify && echo "   raspotify = TV LASDPC"'

log ">> Timer semanal de update do yt-dlp"
pi_rsync -a "$PROJECT_DIR/remote/systemd/yt-dlp-update.service" "$PI_USER@$PI_HOST:/tmp/"
pi_rsync -a "$PROJECT_DIR/remote/systemd/yt-dlp-update.timer" "$PI_USER@$PI_HOST:/tmp/"
pi_ssh "sudo mv /tmp/yt-dlp-update.service /tmp/yt-dlp-update.timer /etc/systemd/system/ && \
  sudo systemctl daemon-reload && sudo systemctl enable --now yt-dlp-update.timer && \
  echo '   timer: '\$(systemctl is-enabled yt-dlp-update.timer)"

log ">> Configurando RetroArch (Vulkan/Ozone, controle N64, playlist, thumbs)"
pi_ssh "export XDG_RUNTIME_DIR=/run/user/\$(id -u); /usr/local/bin/lasdpc-retroarch-setup.sh"

ok "Entretenimento instalado. Modos: Video (tv), Musica (musica), Jogo (games)."
warn "ROMs N64 legais devem estar em $REMOTE_DATA/roms/n64/ (.z64). Recarregue a sessao se necessario."
