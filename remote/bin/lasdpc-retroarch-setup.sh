#!/usr/bin/env bash
# ============================================================
# lasdpc-retroarch-setup.sh — configura o RetroArch para o Pi 4 (roda na Pi,
# como usuario lasdpc). Idempotente.
#  - video Vulkan (usa a GPU V3D real; o decode GL/v4l2 da problema)
#  - menu Ozone, fullscreen
#  - N64 via parallel_n64 + parallel-rdp (Vulkan)
#  - controle de teclado jogavel p/ OoT (movimento no analogico) + anti-saida
#  - playlist N64 + thumbnails
# ============================================================
set -u
CFG="$HOME/.config/retroarch/retroarch.cfg"
COREOPTS="$HOME/.config/retroarch/retroarch-core-options.cfg"
mkdir -p "$(dirname "$CFG")" "$HOME/.config/retroarch/playlists"
touch "$CFG"
HERE="$(cd "$(dirname "$0")" && pwd)"

LIBRETRO_DIR="$(dirname "$(find /usr/lib -name 'parallel_n64_libretro.so' 2>/dev/null | head -1)")"
LIBRETRO_DIR="${LIBRETRO_DIR:-/usr/lib/aarch64-linux-gnu/libretro}"

setcfg(){ local k="$1" v="$2"
  if grep -q "^$k " "$CFG"; then sed -i "s|^$k .*|$k = \"$v\"|" "$CFG"; else echo "$k = \"$v\"" >> "$CFG"; fi; }

# --- aparencia / comportamento ---
setcfg menu_driver ozone
setcfg video_driver vulkan
setcfg video_fullscreen true
setcfg video_windowed_fullscreen true
setcfg video_smooth true
setcfg menu_mouse_enable true
setcfg menu_pause_libretro false
setcfg pause_nonactive false
setcfg quit_press_twice true
setcfg savestate_auto_save true
setcfg savestate_auto_load true
setcfg input_menu_toggle_gamepad_combo 2
setcfg assets_directory /usr/share/libretro/assets
setcfg libretro_directory "$LIBRETRO_DIR"
setcfg libretro_info_path /usr/share/libretro/info
setcfg playlist_directory "$HOME/.config/retroarch/playlists"

# --- controle de teclado jogavel (OoT): movimento no ANALOGICO esquerdo ---
setcfg input_player1_l_x_minus left
setcfg input_player1_l_x_plus  right
setcfg input_player1_l_y_minus up
setcfg input_player1_l_y_plus  down
setcfg input_player1_a x          # A: pular/acao
setcfg input_player1_b z          # B: espada/cancelar
setcfg input_player1_start enter  # Start
setcfg input_player1_l2 lshift    # Z trigger (trava alvo)
setcfg input_player1_l f
setcfg input_player1_r v
setcfg input_player1_r_y_minus i  # C-buttons
setcfg input_player1_r_y_plus  k
setcfg input_player1_r_x_minus j
setcfg input_player1_r_x_plus  l
# anti-saida acidental: sai so via Super+Esc (sistema) ou menu (F1)
setcfg input_exit_emulator nul
setcfg input_menu_toggle f1

# --- N64: parallel-rdp via Vulkan ---
if [ ! -f "$COREOPTS" ] || ! grep -q '^parallel-n64-gfxplugin' "$COREOPTS"; then
  {
    echo 'parallel-n64-gfxplugin = "parallel"'
    echo 'parallel-n64-parallel-rdp-upscaling = "1x"'
    echo 'parallel-n64-screensize = "640x480"'
  } >> "$COREOPTS"
fi

# --- playlist N64 + thumbnails (helpers em launcher/ ou /tmp) ---
run_py(){ local f="$1" d
  for d in "$HERE" /opt/lasdpc-pi-station/launcher /tmp; do
    [ -f "$d/$f" ] && { python3 "$d/$f"; return; }
  done
  echo "   (aviso: $f nao encontrado — pulei)"; }
run_py make_n64_playlist.py
run_py fetch_thumbs.py

echo "RetroArch configurado (Vulkan/Ozone, controle N64, playlist+thumbs)."
