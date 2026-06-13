#!/usr/bin/env bash
# ============================================================
# lasdpc-soh-build.sh — instala deps, clona e compila Ship of Harkinian
# no Raspberry Pi 4 (Debian Trixie arm64).
#
# Requer: sudo NOPASSWD (usa sudo para apt e install).
# Instala em: /opt/soh/
# ROM: o usuário copia manualmente para /srv/lasdpc-pi-station/roms/n64/
#       e executa /opt/soh/soh.elf para extrair os assets na primeira vez.
#
# Executar como lasdpc (não como root).
# ============================================================
set -euo pipefail

LOG=/var/log/lasdpc/soh-build.log
mkdir -p /var/log/lasdpc
exec > >(tee -a "$LOG") 2>&1

SOH_DIR=/opt/soh
SOH_REPO=https://github.com/HarbourMasters/Shipwright.git
SOH_BRANCH=develop
BUILD_DIR=/tmp/soh-build

stamp(){ echo "[$(date '+%H:%M:%S')] $*"; }
stamp "=== Ship of Harkinian build iniciado ==="

# ── 1. Dependências ──────────────────────────────────────────
stamp "Instalando dependências de build..."
sudo apt-get install -y --no-install-recommends \
  cmake \
  libsdl2-dev \
  libsdl2-mixer-dev \
  libsdl2-net-dev \
  libpng-dev \
  libzip-dev \
  libbz2-dev \
  libspdlog-dev \
  libboost-dev \
  libboost-filesystem-dev \
  libboost-system-dev \
  libgles2-mesa-dev \
  libassimp-dev \
  libstb-dev \
  libssl-dev \
  nlohmann-json3-dev \
  libtinyxml2-dev \
  libopusfile-dev \
  python3-full \
  2>/dev/null

stamp "Dependências instaladas."

# ── 2. Clone / update ────────────────────────────────────────
if [ -d "$BUILD_DIR/.git" ]; then
  stamp "Repositório já presente — atualizando..."
  git -C "$BUILD_DIR" fetch --depth=1 origin "$SOH_BRANCH"
  git -C "$BUILD_DIR" checkout "$SOH_BRANCH"
  git -C "$BUILD_DIR" reset --hard "origin/$SOH_BRANCH"
  git -C "$BUILD_DIR" submodule update --init --recursive --depth=1
else
  stamp "Clonando Ship of Harkinian (branch $SOH_BRANCH)..."
  git clone --depth=1 --branch "$SOH_BRANCH" --recurse-submodules \
    --shallow-submodules "$SOH_REPO" "$BUILD_DIR"
fi
stamp "Clone/update concluído."

# ── 3. Configure ─────────────────────────────────────────────
CMAKE_BUILD=$BUILD_DIR/build
stamp "Configurando com cmake..."
cmake -S "$BUILD_DIR" -B "$CMAKE_BUILD" \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$SOH_DIR" \
  -DBUILD_SHARED_LIBS=OFF \
  -DUSE_OPENGLES=ON \
  -Dnlohmann_json_DIR=/usr/share/cmake/nlohmann_json \
  -DCMAKE_PREFIX_PATH="/usr/share/cmake;/usr/lib/aarch64-linux-gnu/cmake"

stamp "CMake configurado."

# ── 4. Build ─────────────────────────────────────────────────
CORES=$(nproc)
stamp "Compilando com $CORES cores (pode levar 30-60 min)..."
ninja -C "$CMAKE_BUILD" -j"$CORES"
stamp "Build concluído."

# ── 5. Install ───────────────────────────────────────────────
stamp "Instalando em $SOH_DIR..."
sudo mkdir -p "$SOH_DIR"
sudo ninja -C "$CMAKE_BUILD" install
# Garante executável acessível
[ -f "$SOH_DIR/soh.elf" ] || { stamp "ERRO: soh.elf não encontrado após install"; exit 1; }
sudo chmod +x "$SOH_DIR/soh.elf"
stamp "Instalado: $(ls -lh "$SOH_DIR/soh.elf")"

# ── 6. Wrapper ───────────────────────────────────────────────
sudo tee /usr/local/bin/lasdpc-soh > /dev/null << 'WRAPPER'
#!/usr/bin/env bash
# Abre Ship of Harkinian (Ocarina of Time port).
# Coloque a ROM legal em /srv/lasdpc-pi-station/roms/n64/ e rode uma vez para extrair.
ROM_DIR=/srv/lasdpc-pi-station/roms/n64
cd /opt/soh
exec /opt/soh/soh.elf "$@"
WRAPPER
sudo chmod +x /usr/local/bin/lasdpc-soh

stamp "=== Ship of Harkinian instalado com sucesso ==="
stamp "Próximo passo: copiar ROM legal de Ocarina of Time para $ROM_DIR"
stamp "e executar: lasdpc-mode games  (ou lasdpc-soh diretamente)"
