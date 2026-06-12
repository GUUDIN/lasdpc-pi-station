#!/usr/bin/env bash
# ============================================================
# MASTER de redeploy AUTO-CONTIDO (roda na Pi como root, destacado).
# Encadeia: base -> docker -> iot -> kodi. Para no 1º erro.
# Status global em /var/log/lasdpc/redeploy.status
# Cada fase também tem seu próprio .status / .log.
# ============================================================
set -uo pipefail
mkdir -p /var/log/lasdpc
M=/var/log/lasdpc/redeploy.status
BIN=/home/lasdpc/lasdpc-deploy/remote/bin

phase(){
  local name="$1" script="$2"
  echo "RUNNING $name $(date -Iseconds)" > "$M"
  echo "===== FASE: $name ====="
  if bash "$BIN/$script" >> "/var/log/lasdpc/${name}.log" 2>&1; then
    echo "   $name OK"
  else
    echo "FAILED $name $(date -Iseconds)" > "$M"
    echo "   $name FALHOU (ver /var/log/lasdpc/${name}.log)"
    exit 1
  fi
}

phase base   lasdpc-base-complete.sh
phase docker  lasdpc-docker.sh
phase iot     lasdpc-iot-deploy.sh
phase kodi    lasdpc-kodi-install.sh

echo "DONE $(date -Iseconds)" > "$M"
echo "REDEPLOY-COMPLETE"
