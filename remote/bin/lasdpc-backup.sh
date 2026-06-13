#!/usr/bin/env bash
# ============================================================
# lasdpc-backup.sh — backup diário de configurações da estação.
# Copia para /srv/lasdpc-pi-station/backups/YYYY-MM-DD/
# Retém os 7 backups mais recentes.
# ============================================================
set -euo pipefail

DEST=/srv/lasdpc-pi-station/backups/$(date +%F)
mkdir -p "$DEST"

stamp(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
stamp "Backup iniciado → $DEST"

# Configs de usuário (sempre acessíveis)
rsync -a --relative \
  /home/lasdpc/.config/lasdpc/ \
  /srv/lasdpc-pi-station/homepage/config/ \
  /home/lasdpc/.local/share/ares/settings.bml \
  "$DEST/" 2>/dev/null || true

# Configs de sistema (best-effort; falha silenciosa se sem permissão)
rsync -a --relative \
  /etc/xdg/labwc/rc.xml \
  /etc/ufw/ufw.conf \
  /etc/ufw/before.rules \
  /etc/ufw/after.rules \
  "$DEST/" 2>/dev/null || true

# Mosquitto passwd (root-owned; best-effort via sudo)
sudo cp /srv/lasdpc-pi-station/mosquitto/config/passwd \
  "$DEST/mosquitto-passwd.bak" 2>/dev/null || true

stamp "Arquivos copiados: $(find "$DEST" -type f | wc -l)"

# Limpa backups com mais de 7 dias
find /srv/lasdpc-pi-station/backups -maxdepth 1 -type d -mtime +7 | sort | while read -r old; do
  [ "$old" = "/srv/lasdpc-pi-station/backups" ] && continue
  stamp "Removendo backup antigo: $old"
  rm -rf "$old"
done

stamp "Backup concluído."
