#!/usr/bin/env bash
# ============================================================
# install.sh — transforma um Raspberry Pi OS recem-gravado numa LASDPC Station.
#
#   sudo apt-get install -y git
#   sudo git clone https://github.com/GUUDIN/lasdpc-pi-station.git /opt/lasdpc-pi-station/repo
#   sudo /opt/lasdpc-pi-station/repo/install.sh --nome tv-lab-02 --apps "games airplay"
#
# Opcoes:
#   --nome NOME       nome da estacao (padrao: hostname)
#   --apps "A B"      apps opcionais (obrigatorios: dashboard youtube spotify desktop)
#                     disponiveis: games airplay kodi
#   --canal CANAL     stable (padrao) ou main
#   --usuario USER    usuario da sessao grafica (padrao: o do uid 1000)
#   --dashboard URL   painel do modo Dashboard
#
# Cria /etc/lasdpc/station.conf (so se ainda nao existir), poe o checkout no canal
# e roda o lasdpc-apply. A partir dai o lasdpc-update.timer mantem a Pi atualizada.
# Ver docs/fleet.md.
# ============================================================
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "rode com sudo"; exit 1; }
REPO="$(cd "$(dirname "$0")" && pwd)"
NAME="$(hostname)"; APPS=""; CHANNEL="stable"; USER_NAME=""; DASH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --nome) NAME="$2"; shift 2 ;;
    --apps) APPS="$2"; shift 2 ;;
    --canal) CHANNEL="$2"; shift 2 ;;
    --usuario) USER_NAME="$2"; shift 2 ;;
    --dashboard) DASH="$2"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "opcao desconhecida: $1"; exit 2 ;;
  esac
done
USER_NAME="${USER_NAME:-$(id -nu 1000)}"
id "$USER_NAME" >/dev/null 2>&1 || { echo "usuario $USER_NAME nao existe"; exit 1; }
for a in $APPS; do
  [ -f "$REPO/apps/$a/app.json" ] || { echo "app desconhecido: $a (ver $REPO/apps/)"; exit 1; }
done

install -d -m 0755 /etc/lasdpc
if [ ! -f /etc/lasdpc/station.conf ]; then
  cat > /etc/lasdpc/station.conf <<CONF
# Configuracao desta estacao (fora do repositorio; o lasdpc-update nao mexe aqui).
STATION_NAME="$NAME"
# canal de atualizacao: stable (recomendado) ou main
CHANNEL="$CHANNEL"
# apps opcionais habilitados (obrigatorios estao sempre ligados): games airplay kodi
APPS="$APPS"
# usuario da sessao grafica
SESSION_USER="$USER_NAME"
# painel do modo Dashboard (pode ser trocado em Ajustes, no menu)
DASHBOARD_URL="${DASH:-http://localhost:8080}"
# saida de audio: hdmi (a TV) ou keep (nao mexer)
AUDIO_OUTPUT="hdmi"
CONF
  echo "criado /etc/lasdpc/station.conf"
else
  echo "/etc/lasdpc/station.conf ja existe; mantido (edite-o para mudar apps/canal)"
fi

# checkout no canal escolhido (o lasdpc-update segue esse canal daqui em diante)
if [ -d "$REPO/.git" ] && [ "$REPO" = /opt/lasdpc-pi-station/repo ]; then
  git -C "$REPO" fetch --quiet origin "$CHANNEL" && git -C "$REPO" checkout --quiet --detach FETCH_HEAD
fi
"$REPO/station/bin/lasdpc-apply" --repo "$REPO"
echo
echo "LASDPC Station instalada. Reinicie para entrar no modo estacao: sudo reboot"
echo "Spotify oficial: gere a chave (conta Premium) e rode: sudo lasdpc-soloist-setkey"
