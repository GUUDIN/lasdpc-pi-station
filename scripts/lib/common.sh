#!/usr/bin/env bash
# ============================================================
# Biblioteca comum dos scripts do LASDPC Pi Station.
# Carrega .env, define helpers de log, SSH e segurança.
# Sourced por todos os scripts: . "$(dirname "$0")/lib/common.sh"
# ============================================================
set -euo pipefail

# --- Raízes do projeto ---
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$LIB_DIR/.." && pwd)"
PROJECT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"

# --- Cores (desligadas se não for TTY) ---
if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'; C_BLU=$'\033[34m'; C_RST=$'\033[0m'
else
  C_RED=''; C_GRN=''; C_YLW=''; C_BLU=''; C_RST=''
fi

log()   { printf '%s[%s]%s %s\n' "$C_BLU" "$(date +%H:%M:%S)" "$C_RST" "$*"; }
ok()    { printf '%s  [OK] %s%s\n' "$C_GRN" "$*" "$C_RST"; }
warn()  { printf '%s  [!] %s%s\n' "$C_YLW" "$*" "$C_RST" >&2; }
err()   { printf '%s  [X] %s%s\n' "$C_RED" "$*" "$C_RST" >&2; }
die()   { err "$*"; exit 1; }

# --- Carrega .env (sem expor segredos no log) ---
load_env() {
  local envfile="${1:-$PROJECT_DIR/.env}"
  if [ ! -f "$envfile" ]; then
    die "Arquivo .env não encontrado em $envfile — copie de .env.example e preencha PI_HOST/PI_USER."
  fi
  set -a
  # shellcheck disable=SC1090
  . "$envfile"
  set +a
  : "${PI_HOST:?Defina PI_HOST no .env}"
  : "${PI_USER:?Defina PI_USER no .env}"
  : "${PI_PORT:=22}"
  : "${PI_SSH_KEY:=$HOME/.ssh/id_ed25519}"
  : "${REMOTE_BASE:=/opt/lasdpc-pi-station}"
  : "${REMOTE_DATA:=/srv/lasdpc-pi-station}"
  : "${REMOTE_BACKUPS:=/var/backups/lasdpc-pi-station}"
  # Expande ~ no caminho da chave
  PI_SSH_KEY="${PI_SSH_KEY/#\~/$HOME}"
}

# --- Opções SSH seguras (NUNCA StrictHostKeyChecking=no) ---
# accept-new: confia na 1ª vez registrando fingerprint, mas alerta se mudar.
ssh_opts() {
  local opts=(-p "$PI_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=15)
  if [ -f "$PI_SSH_KEY" ]; then
    opts+=(-o IdentitiesOnly=yes -i "$PI_SSH_KEY")
  fi
  printf '%s\n' "${opts[@]}"
}

# Executa comando remoto (read-only por padrão; o chamador decide o que envia)
pi_ssh() {
  local opts; mapfile -t opts < <(ssh_opts)
  ssh "${opts[@]}" "${PI_USER}@${PI_HOST}" "$@"
}

# rsync sobre SSH com as mesmas opções
pi_rsync() {
  local opts; mapfile -t opts < <(ssh_opts)
  rsync -e "ssh ${opts[*]}" "$@"
}

# Confirmação interativa (idempotência/segurança em ações sensíveis)
confirm() {
  local prompt="${1:-Confirmar?} [s/N] " ans
  read -r -p "$prompt" ans || true
  case "$ans" in s|S|sim|y|Y) return 0 ;; *) return 1 ;; esac
}

# Timestamp padrão para backups/relatórios
ts() { date +%Y%m%d-%H%M%S; }
