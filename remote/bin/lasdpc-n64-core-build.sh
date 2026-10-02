#!/usr/bin/env bash
# ============================================================
# lasdpc-n64-core-build.sh — compila o core N64 mupen64plus_next (GLideN64,
# GLES3) para o Pi 4 e instala no diretorio de cores do RetroArch.
# Roda na Pi como o usuario da estacao (usa sudo so para instalar). ~30 min.
#
# Por que: o parallel_n64 do buildbot so tem render rapido via parallel-rdp
# (Vulkan compute), que na V3D do Pi 4 roda Zelda OoT a ~13 FPS com tela preta
# (parece travado). Seus plugins GL exigem OpenGL desktop, e o RetroArch desta
# estacao e compilado com OpenGL ES. O mupen64plus_next nao existe no buildbot
# aarch64 nem no apt, entao compilamos com platform=rpi4_64 (GLES3 + dynarec).
# Idempotente: nao recompila se o .so do commit fixado ja estiver instalado.
# ============================================================
set -euo pipefail
REPO="https://github.com/libretro/mupen64plus-libretro-nx.git"
COMMIT="12edd2c74a517ff86dfa8cfc71ad75e4c10486d5"   # 2026-10-01, testado no Pi 4
SRC="${HOME}/src/mupen64plus-libretro-nx"
ARCH_TRIPLET="$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo aarch64-linux-gnu)"
CORE_DIR="/usr/lib/${ARCH_TRIPLET}/libretro"
STAMP="$CORE_DIR/mupen64plus_next_libretro.so.commit"

if [ -f "$CORE_DIR/mupen64plus_next_libretro.so" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$COMMIT" ]; then
  echo "mupen64plus_next ($COMMIT) ja instalado em $CORE_DIR"
  exit 0
fi

echo ">> dependencias de build"
sudo apt-get install -y --no-install-recommends git build-essential libgles-dev libegl-dev zlib1g-dev libpng-dev

echo ">> fonte em $SRC @ $COMMIT"
mkdir -p "$(dirname "$SRC")"
if [ ! -d "$SRC/.git" ]; then
  git clone "$REPO" "$SRC"
fi
git -C "$SRC" fetch --depth 1 origin "$COMMIT"
git -C "$SRC" checkout -q "$COMMIT"

echo ">> compilando (platform=rpi4_64: GLES3 + dynarec aarch64)"
# -j3 deixa um nucleo livre para a estacao continuar responsiva
make -C "$SRC" platform=rpi4_64 GLES3=1 -j3

echo ">> instalando em $CORE_DIR"
sudo install -m 0644 "$SRC/mupen64plus_next_libretro.so" "$CORE_DIR/mupen64plus_next_libretro.so"
echo "$COMMIT" | sudo tee "$STAMP" >/dev/null
echo "mupen64plus_next instalado."
