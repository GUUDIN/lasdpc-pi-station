#!/usr/bin/env bash
# ============================================================
# packaging/publish-apt.sh — publica o pacote lasdpc-station no repositorio APT
# servido pelo GitHub Pages (branch gh-pages): https://guudin.github.io/lasdpc-pi-station
#   dists/stable/{InRelease,Release,Release.gpg}, dists/stable/main/binary-{arm64,all}/Packages
#   pool/main/lasdpc-station_<versao>_all.deb
#   lasdpc-station.deb (ultima versao, link fixo para a 1a instalacao) + chave publica
# Assina com a chave "LASDPC Station APT" (gpg local de quem publica).
# Uso: packaging/publish-apt.sh [--push]
# ============================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$ROOT/.apt-site"
KEY="LASDPC Station APT"
DEB="$("$ROOT/packaging/build-deb.sh")"

# o site e um repositorio separado (so a branch gh-pages), nunca o projeto inteiro
URL="$(git -C "$ROOT" remote get-url origin)"
if [ ! -d "$SITE/.git" ]; then
  if git ls-remote --exit-code --heads "$URL" gh-pages >/dev/null 2>&1; then
    git clone -q --branch gh-pages --single-branch "$URL" "$SITE"
  else
    git init -q -b gh-pages "$SITE" && git -C "$SITE" remote add origin "$URL"
  fi
fi

cd "$SITE"
install -d pool/main dists/stable/main/binary-arm64 dists/stable/main/binary-all
cp "$DEB" pool/main/
cp "$DEB" lasdpc-station.deb
cp "$ROOT/packaging/lasdpc-archive-keyring.gpg" lasdpc-archive-keyring.gpg
for arch in arm64 all; do
  apt-ftparchive packages pool > "dists/stable/main/binary-$arch/Packages"
  gzip -9kf "dists/stable/main/binary-$arch/Packages"
done
# gera fora de dists/ (senao o Release lista a si mesmo) e depois move
rm -f dists/stable/Release dists/stable/InRelease dists/stable/Release.gpg
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="LASDPC" -o APT::FTPArchive::Release::Label="LASDPC Station" \
  -o APT::FTPArchive::Release::Suite=stable -o APT::FTPArchive::Release::Codename=stable \
  -o APT::FTPArchive::Release::Components=main -o APT::FTPArchive::Release::Architectures="arm64 all" \
  release dists/stable > /tmp/lasdpc-Release
mv /tmp/lasdpc-Release dists/stable/Release
gpg --batch --yes -u "$KEY" --clearsign -o dists/stable/InRelease dists/stable/Release
gpg --batch --yes -u "$KEY" -abs -o dists/stable/Release.gpg dists/stable/Release
touch .nojekyll
cat > index.html <<'HTML'
<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>LASDPC Station — APT</title>
<body style="font-family:system-ui;max-width:760px;margin:40px auto;line-height:1.5">
<h1>LASDPC Station</h1>
<p>Instalar numa Raspberry Pi (Raspberry Pi OS 64-bit):</p>
<pre>curl -fsSLo /tmp/lasdpc-station.deb https://guudin.github.io/lasdpc-pi-station/lasdpc-station.deb
sudo apt install /tmp/lasdpc-station.deb</pre>
<p>O instalador verifica o cartão SD e pergunta quais apps instalar. Depois, o pacote se atualiza
pelo apt e a estação pelo canal <code>stable</code> do repositório.</p>
<p><a href="https://github.com/GUUDIN/lasdpc-pi-station">Código no GitHub</a> ·
<a href="https://github.com/GUUDIN/lasdpc-pi-station/blob/main/docs/fleet.md">Documentação da frota</a></p>
</body></html>
HTML
git add -A
git -c user.name="${GIT_AUTHOR_NAME:-GUUDIN}" -c user.email="${GIT_AUTHOR_EMAIL:-pedrogudin@gmail.com}" \
  commit -qm "apt: $(basename "$DEB")" || echo "(nada novo para publicar)"
if [ "${1:-}" = "--push" ]; then
  git push -q -u origin gh-pages && echo "publicado: https://guudin.github.io/lasdpc-pi-station"
else
  echo "pronto em $SITE (rode com --push para publicar)"
fi
