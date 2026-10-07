#!/usr/bin/env bash
# ============================================================
# lasdpc-uxplay-build.sh — compila o UxPlay (receptor AirPlay) fixado numa versao
# e instala em /usr/local/bin/uxplay. Roda na Pi (sudo para dependencias/instalacao).
#
# Por que nao o pacote do Debian (1.62, 2023): de la para ca o UxPlay corrigiu
# compatibilidade com iOS (inclusive o TEARDOWN do iOS 27), falhas de seguranca
# (CVE-2025-60458; buffer overflow na 1.73.7) e melhorou HLS (app do YouTube).
# Idempotente: nao recompila se a versao fixada ja estiver instalada.
# ============================================================
set -euo pipefail
VERSION="1.73.7"
SHA256="65feb8732de666a7161a9e562aa603a7f5fe0ebb890c2a30c5e1a9c85c76309f"
URL="https://github.com/FDH2/UxPlay/archive/refs/tags/v${VERSION}.tar.gz"

if /usr/local/bin/uxplay -v 2>/dev/null | grep -q "version ${VERSION}"; then
  echo "UxPlay ${VERSION} ja instalado"; exit 0
fi

echo ">> dependencias (build + GStreamer com waylandsink, v4l2 e pulse)"
sudo apt-get -o DPkg::Lock::Timeout=1200 install -y --no-install-recommends cmake build-essential pkg-config libssl-dev \
  libplist-dev libavahi-compat-libdnssd-dev avahi-daemon libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-pulseaudio
# o pacote antigo do Debian teria precedencia no PATH de alguns scripts
sudo apt-get -o DPkg::Lock::Timeout=1200 remove -y uxplay 2>/dev/null || true

tmp="$(mktemp -d)"
curl -fsSL -o "$tmp/uxplay.tar.gz" "$URL"
echo "$SHA256  $tmp/uxplay.tar.gz" | sha256sum -c --quiet
tar xzf "$tmp/uxplay.tar.gz" -C "$tmp"
cmake -S "$tmp/UxPlay-${VERSION}" -B "$tmp/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
make -C "$tmp/build" -j3
sudo install -m 0755 "$tmp/build/uxplay" /usr/local/bin/uxplay
rm -rf "$tmp"
/usr/local/bin/uxplay -v
