#!/usr/bin/env bash
# ============================================================
# Pull SEQUENCIAL das imagens da stack IoT + compose up -d.
# Roda destacado (systemd-run) na Pi como root. Resistente a Wi-Fi.
# Sequencial para não sobrecarregar a extração no microSD lento.
# Status em /var/log/lasdpc/iot-pull.status
# ============================================================
set -uo pipefail
mkdir -p /var/log/lasdpc
STATUS=/var/log/lasdpc/iot-pull.status
echo "RUNNING $(date -Iseconds)" > "$STATUS"

OPT=/opt/lasdpc-pi-station/docker
IMAGES=(
  "eclipse-mosquitto:2.0"
  "influxdb:2.7"
  "nodered/node-red:4.0"
  "grafana/grafana-oss:11.3.1"
  "ghcr.io/gethomepage/homepage:v0.9.13"
)

# Encerra qualquer compose/pull preso
pkill -f "compose.*up -d" 2>/dev/null || true
sleep 2

for img in "${IMAGES[@]}"; do
  if docker image inspect "$img" >/dev/null 2>&1; then
    echo ">> já presente: $img"; continue
  fi
  ok=0
  for try in 1 2 3 4 5; do
    echo ">> pull ($try/5): $img"
    if timeout 600 docker pull "$img"; then ok=1; break; fi
    echo "   falhou, retry em 10s..."; sleep 10
  done
  [ "$ok" = 1 ] || { echo "FAILED pull $img $(date -Iseconds)" > "$STATUS"; exit 1; }
done

echo ">> Todas as imagens presentes. Validando compose..."
cd "$OPT"
docker compose --env-file "$OPT/.env" -f "$OPT/compose.yml" config >/dev/null || { echo "FAILED compose-config $(date -Iseconds)" > "$STATUS"; exit 1; }

echo ">> Subindo containers"
docker compose --env-file "$OPT/.env" -f "$OPT/compose.yml" up -d

sleep 8
docker compose --env-file "$OPT/.env" -f "$OPT/compose.yml" ps
echo "DONE $(date -Iseconds)" > "$STATUS"
echo "IOT-PULL-COMPLETE"
