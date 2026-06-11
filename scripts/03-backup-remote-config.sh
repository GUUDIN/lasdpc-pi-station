#!/usr/bin/env bash
# ============================================================
# 03 — Backup prévio dos arquivos que poderão ser modificados.
# Cria diretório remoto com timestamp, copia originais e gera
# manifesto com SHA-256, dono, grupo, permissões e data.
# Não compacta ROMs/mídia. Idempotente (cada execução = novo timestamp).
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

STAMP="$(ts)"
RBACKUP="${REMOTE_BACKUPS}/${STAMP}"
log "Criando backup remoto em $RBACKUP"

# Lista de arquivos/dirs candidatos (copiados só se existirem)
read -r -d '' TARGETS <<'EOF' || true
/boot/firmware/config.txt
/boot/config.txt
/boot/firmware/cmdline.txt
/boot/cmdline.txt
/etc/fstab
/etc/hostname
/etc/hosts
/etc/timezone
/etc/default/keyboard
/etc/asound.conf
/etc/docker/daemon.json
/etc/systemd/timesyncd.conf
EOF

# Script remoto: cria dir, copia existentes, gera manifesto
REMOTE=$(cat <<REOF
set -e
sudo mkdir -p "$RBACKUP"
MAN="$RBACKUP/MANIFEST.txt"
echo "# Manifesto de backup — $STAMP" | sudo tee "\$MAN" >/dev/null
echo "# caminho | sha256 | dono | grupo | permissoes | data" | sudo tee -a "\$MAN" >/dev/null
copy_one() {
  local f="\$1"
  [ -e "\$f" ] || return 0
  local dest="$RBACKUP\$f"
  sudo mkdir -p "\$(dirname "\$dest")"
  sudo cp -a "\$f" "\$dest"
  local sha owner grp perms
  sha=\$(sudo sha256sum "\$f" 2>/dev/null | awk '{print \$1}')
  owner=\$(stat -c '%U' "\$f"); grp=\$(stat -c '%G' "\$f"); perms=\$(stat -c '%a' "\$f")
  echo "\$f | \$sha | \$owner | \$grp | \$perms | \$(date -Iseconds)" | sudo tee -a "\$MAN" >/dev/null
  echo "  copiado: \$f"
}
$(while IFS= read -r f; do [ -n "$f" ] && echo "copy_one \"$f\""; done <<<"$TARGETS")
# Diretórios de config de usuário (autostart, chromium, kodi, retroarch) — só metadados leves
for d in "\$HOME/.config/autostart" "\$HOME/.config/lxsession" "\$HOME/.kodi/userdata" "\$HOME/.config/retroarch" "/opt/retropie/configs"; do
  if [ -e "\$d" ]; then
    sudo mkdir -p "$RBACKUP\$d"
    sudo cp -a "\$d/." "$RBACKUP\$d/" 2>/dev/null || true
    echo "  copiado(dir): \$d"
  fi
done
echo "Backup concluído em $RBACKUP"
sudo ls -la "$RBACKUP"
REOF
)

pi_ssh "$REMOTE" 2>&1 | tee "$LOG_DIR/backup-remoto-$STAMP.log"
ok "Backup remoto concluído. Manifesto em $RBACKUP/MANIFEST.txt"
log "Para trazer uma cópia local opcional:"
log "  ./scripts/backup-all.sh   (ou make backup)"
