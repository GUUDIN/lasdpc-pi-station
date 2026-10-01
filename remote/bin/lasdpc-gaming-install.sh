#!/usr/bin/env bash
# ============================================================
# Etapa 4 — instalação do perfil GAMING (AUTO-CONTIDA, roda na Pi como root).
# RetroArch (apt) + cores apt (NES/SNES/Genesis-SMS/GB) + parallel_n64 (buildbot)
# + ES-DE 3.4.1 (AppImage AArch64). Idempotente. Destacável via systemd-run.
#
# DECISÃO DE ARQUITETURA: a proposta original era RetroArch via Flatpak, mas:
#  - RetroArch está no apt do Trixie (1.20.0), sem sandbox e mais simples;
#  - instalar core N64 headless no Flatpak é problemático.
# Por isso: RetroArch via apt + cores apt + core N64 do buildbot oficial libretro.
# mupen64plus_next NÃO está no buildbot aarch64 → usamos parallel_n64 (disponível).
# N64 segue best-effort; caminho principal p/ Ocarina é o SoH (Etapa 5) e ares.
#
# Status: /var/log/lasdpc/gaming.status
# ============================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
mkdir -p /var/log/lasdpc
STATUS=/var/log/lasdpc/gaming.status
echo "RUNNING $(date -Iseconds)" > "$STATUS"

SRV=/srv/lasdpc-pi-station
ESDE_DIR=/opt/es-de
ESDE_APPIMAGE="$ESDE_DIR/ES-DE_aarch64.AppImage"
ESDE_URL="https://gitlab.com/es-de/emulationstation-de/-/package_files/288156935/download"
ESDE_VERSION="3.4.1"
ARCH_TRIPLET="$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo aarch64-linux-gnu)"
CORE_DIR="/usr/lib/${ARCH_TRIPLET}/libretro"
LASDPC_USER="${LASDPC_USER:-lasdpc}"
USER_HOME="$(getent passwd "$LASDPC_USER" | cut -d: -f6)"

echo ">> espaço livre: $(df -h / | tail -1 | awk '{print $4}')"

echo ">> RetroArch + cores (apt)"
apt-get update -qq
apt-get install -y retroarch \
  libretro-nestopia libretro-snes9x libretro-genesisplusgx libretro-gambatte \
  mesa-utils unzip

echo ">> Core N64 parallel_n64 (buildbot libretro aarch64 — não há no apt)"
mkdir -p "$CORE_DIR"
if [ ! -f "$CORE_DIR/parallel_n64_libretro.so" ]; then
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/c.zip" "https://buildbot.libretro.com/nightly/linux/aarch64/latest/parallel_n64_libretro.so.zip"; then
    unzip -o "$tmp/c.zip" -d "$CORE_DIR" >/dev/null && echo "   parallel_n64 instalado em $CORE_DIR"
  else
    echo "   WARN: download do parallel_n64 falhou — N64 via RetroArch indisponível (use ares/SoH)"
  fi
  rm -rf "$tmp"
else
  echo "   parallel_n64 já presente"
fi

echo ">> ES-DE AppImage v$ESDE_VERSION"
mkdir -p "$ESDE_DIR"
if [ ! -f "$ESDE_APPIMAGE" ]; then
  curl -fsSL -o "$ESDE_APPIMAGE.part" "$ESDE_URL" && mv "$ESDE_APPIMAGE.part" "$ESDE_APPIMAGE"
  chmod 0755 "$ESDE_APPIMAGE"
fi
SHA="$(sha256sum "$ESDE_APPIMAGE" | awk '{print $1}')"
printf 'ES-DE %s\nsha256 %s\nurl %s\n' "$ESDE_VERSION" "$SHA" "$ESDE_URL" > "$ESDE_DIR/VERSION"
echo "   ES-DE pronto (sha256=$SHA)"

echo ">> Diretórios de ROMs/saves/config em $SRV"
mkdir -p "$SRV"/roms/{n64,nes,snes,gb,gbc,gba,megadrive,mastersystem,psx} \
         "$SRV"/saves "$SRV"/config/retroarch
# READMEs de transferência legal (sem ROMs versionadas)
cat > "$SRV/roms/README.txt" <<TXT
Coloque aqui SOMENTE ROMs/jogos LEGAIS (backups próprios ou homebrew livre).
Estrutura por sistema: n64/ nes/ snes/ gb/ gbc/ gba/ megadrive/ mastersystem/ psx/
Transferência: rsync/scp/SFTP via Tailscale. Não versionar ROMs no Git.
TXT
chown -R "$LASDPC_USER:$LASDPC_USER" "$SRV/roms" "$SRV/saves" "$SRV/config"

echo ">> Pré-seed do ES-DE (ROMs em $SRV/roms)"
ESHOME="$USER_HOME/ES-DE/settings"
mkdir -p "$ESHOME"
if [ ! -f "$ESHOME/es_settings.xml" ]; then
  cat > "$ESHOME/es_settings.xml" <<XML
<?xml version="1.0"?>
<string name="ROMDirectory" value="$SRV/roms" />
<string name="MediaDirectory" value="$SRV/config/es-de-media" />
<string name="SaveGamesDirectory" value="$SRV/saves" />
<bool name="StartupOnFirstSystem" value="false" />
XML
fi
chown -R "$LASDPC_USER:$LASDPC_USER" "$USER_HOME/ES-DE"

echo "DONE $(date -Iseconds)" > "$STATUS"
echo "GAMING-INSTALL-COMPLETE"
