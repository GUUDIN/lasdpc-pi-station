#!/usr/bin/env bash
# ============================================================
# packaging/build-deb.sh — gera dist/lasdpc-station_<versao>_all.deb
# O pacote e o "instalador": telas de escolha (debconf), verificacao do cartao
# (lasdpc-sdcheck) e registro do repositorio APT (para o proprio pacote se
# atualizar). O codigo da estacao vem do git no canal escolhido.
# ============================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.0.$(git -C "$ROOT" rev-list --count HEAD)}"
STAGE="$(mktemp -d)"; chmod 0755 "$STAGE"; trap 'rm -rf "$STAGE"' EXIT
APT_URL="https://guudin.github.io/lasdpc-pi-station"

install -d "$STAGE/DEBIAN" "$STAGE/usr/bin" "$STAGE/usr/share/keyrings" "$STAGE/etc/apt/sources.list.d"
sed "s/@VERSION@/$VERSION/" "$ROOT/packaging/debian/control.in" > "$STAGE/DEBIAN/control"
for f in templates config postinst postrm; do install -m 0755 "$ROOT/packaging/debian/$f" "$STAGE/DEBIAN/$f"; done
chmod 0644 "$STAGE/DEBIAN/templates"
install -m 0755 "$ROOT/remote/bin/lasdpc-sdcheck" "$STAGE/usr/bin/lasdpc-sdcheck"
install -m 0644 "$ROOT/packaging/lasdpc-archive-keyring.gpg" "$STAGE/usr/share/keyrings/lasdpc-archive-keyring.gpg"
echo "deb [signed-by=/usr/share/keyrings/lasdpc-archive-keyring.gpg] $APT_URL stable main" \
  > "$STAGE/etc/apt/sources.list.d/lasdpc-station.list"
echo "/etc/apt/sources.list.d/lasdpc-station.list" > "$STAGE/DEBIAN/conffiles"

install -d "$ROOT/dist"
OUT="$ROOT/dist/lasdpc-station_${VERSION}_all.deb"
dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$OUT" >/dev/null
echo "$OUT"
