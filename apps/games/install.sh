#!/usr/bin/env bash
# App Jogos: RetroArch (Vulkan/Ozone) + cores, core N64 rapido (mupen64plus_next
# GLES3), perfis por jogo e lista de jogos do menu. ROMs: /srv/lasdpc-pi-station/roms/<sistema>
. "$REPO/station/lib/common.sh"
apt_ensure libretro-nestopia libretro-snes9x libretro-genesisplusgx libretro-gambatte python3-pil
if ! command -v retroarch >/dev/null 2>&1; then
  apt_ensure retroarch
fi
retroarch --features 2>/dev/null | grep -qiE 'vulkan.*: *yes' \
  || warn "RetroArch sem Vulkan (ex.: apt do Bookworm): o N64 por parallel-rdp nao roda; ver docs/troubleshooting.md"

install_bin lasdpc-retroarch lasdpc-retroarch-setup.sh lasdpc-games-launch lasdpc-n64-core-build.sh
for s in n64 snes nes megadrive mastersystem gb gbc gba psx; do
  install -d -o "$SESSION_USER" -g "$SESSION_USER" "$DATA_DIR/roms/$s"
done
# core N64: compilado na Pi na 1a vez (~30 min; idempotente pelo commit fixado)
sudo -u "$SESSION_USER" /usr/local/bin/lasdpc-n64-core-build.sh
# configuracao do RetroArch do usuario (teclado, atalhos, playlist, perfis por jogo)
sudo -u "$SESSION_USER" env HOME="$SESSION_HOME" XDG_RUNTIME_DIR="/run/user/$SESSION_UID" \
  /usr/local/bin/lasdpc-retroarch-setup.sh
