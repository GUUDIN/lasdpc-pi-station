# ============================================================
# station/lib/common.sh — funcoes do agente da estacao (lasdpc-apply e os
# install.sh dos apps). Roda NA Pi, como root. Variaveis exportadas pelo
# lasdpc-apply: REPO, SESSION_USER, SESSION_UID, SESSION_HOME, OS_CODENAME.
# ============================================================
set -euo pipefail
BASE_DIR=/opt/lasdpc-pi-station
DATA_DIR=/srv/lasdpc-pi-station

log()  { printf '[lasdpc %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[lasdpc %s] AVISO: %s\n' "$(date +%H:%M:%S)" "$*" >&2; }

# instala pacotes que ainda faltam (apt-get update so se precisar)
apt_ensure() {
  local missing=() p
  for p in "$@"; do dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'ok installed' || missing+=("$p"); done
  [ ${#missing[@]} -eq 0 ] && return 0
  log "apt: instalando ${missing[*]}"
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
}

# copia so se mudou (instalacao atomica: arquivo novo + rename)
install_file() {  # install_file <origem> <destino> [modo] [dono]
  local src="$1" dst="$2" mode="${3:-0644}" owner="${4:-root:root}"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then return 1; fi
  install -D -m "$mode" -o "${owner%%:*}" -g "${owner##*:}" "$src" "$dst.lasdpc-new"
  mv -f "$dst.lasdpc-new" "$dst"
  return 0
}
install_bin() { local f; for f in "$@"; do install_file "$REPO/remote/bin/$f" "/usr/local/bin/$f" 0755 || true; done; }

sync_dir() {  # sync_dir <origem/> <destino/> [dono]
  install -d "$2"
  rsync -a --delete "$1" "$2"
  [ -n "${3:-}" ] && chown -R "$3" "$2"
  return 0
}

# systemctl --user do usuario da sessao (funciona como root, com ou sem login)
userctl() {
  sudo -u "$SESSION_USER" env XDG_RUNTIME_DIR="/run/user/$SESSION_UID" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$SESSION_UID/bus" "$@"
}
session_running() { [ -S "/run/user/$SESSION_UID/bus" ]; }

install_user_unit() {  # install_user_unit <arquivo do repo> -> ~/.config/systemd/user/
  install_file "$1" "$SESSION_HOME/.config/systemd/user/$(basename "$1")" 0644 "$SESSION_USER:$SESSION_USER" || true
}
install_system_unit() {  # retorna 0 se mudou
  install_file "$1" "/etc/systemd/system/$(basename "$1")" 0644
}

# glibc da Pi (Bookworm 2.36, Trixie 2.41)
glibc_at_least() { [ "$(printf '%s\n' "$1" "$(ldd --version | head -1 | grep -oE '[0-9]+\.[0-9]+$')" | sort -V | head -1)" = "$1" ]; }
