#!/usr/bin/env bash
# ============================================================
# IoT deploy AUTO-CONTIDO (roda na Pi como root, destacado).
# Copia configs de ~/lasdpc-deploy, gera segredos, pull SEQUENCIAL, sobe.
# Idempotente. Status em /var/log/lasdpc/iot.status
# ============================================================
set -uo pipefail
mkdir -p /var/log/lasdpc
STATUS=/var/log/lasdpc/iot.status
echo "RUNNING $(date -Iseconds)" > "$STATUS"

SRC=/home/lasdpc/lasdpc-deploy/docker
OPT=/opt/lasdpc-pi-station/docker
SRV=/srv/lasdpc-pi-station
TZ=America/Sao_Paulo

echo ">> Diretórios + permissões"
mkdir -p "$OPT" \
  "$SRV"/mosquitto/{config,data,log} "$SRV"/node-red/data \
  "$SRV"/influxdb/{data,config} "$SRV"/grafana/{data,provisioning/datasources} \
  "$SRV"/homepage/config
cp "$SRC/compose.yml" "$OPT/compose.yml"
cp "$SRC/mosquitto/config/mosquitto.conf" "$SRV/mosquitto/config/mosquitto.conf"
cp "$SRC"/homepage/config/*.yaml "$SRV/homepage/config/"
chown -R 1883:1883 "$SRV/mosquitto"
chown -R 1000:1000 "$SRV/node-red" "$SRV/homepage"
chown -R 472:472   "$SRV/grafana"

echo ">> .env (segredos) — só se não existir"
if [ ! -f "$OPT/.env" ]; then
  rnd(){ openssl rand -base64 18 | tr -d '/+=' | head -c 20; }
  cat > "$OPT/.env" <<EOF
TZ=$TZ
DATA_ROOT=$SRV
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=$(rnd)
INFLUX_USERNAME=admin
INFLUX_PASSWORD=$(rnd)
INFLUX_ORG=lasdpc
INFLUX_BUCKET=iot
INFLUX_ADMIN_TOKEN=$(openssl rand -hex 32)
INFLUX_RETENTION=30d
MOSQUITTO_USERNAME=iot
MOSQUITTO_PASSWORD=$(rnd)
EOF
  chmod 600 "$OPT/.env"
fi

echo ">> Pull SEQUENCIAL das imagens"
for img in eclipse-mosquitto:2.0 influxdb:2.7 nodered/node-red:4.0 grafana/grafana-oss:11.3.1 ghcr.io/gethomepage/homepage:v0.9.13; do
  docker image inspect "$img" >/dev/null 2>&1 && { echo "   já: $img"; continue; }
  for t in 1 2 3 4 5; do echo "   pull ($t/5): $img"; timeout 700 docker pull "$img" && break; sleep 10; done
  docker image inspect "$img" >/dev/null 2>&1 || { echo "FAILED pull $img" > "$STATUS"; exit 1; }
done

echo ">> Mosquitto passwd (sem anônimo)"
eval "$(grep -E '^MOSQUITTO_' "$OPT/.env")"
if [ ! -f "$SRV/mosquitto/config/passwd" ]; then
  docker run --rm -v "$SRV/mosquitto/config:/mosquitto/config" eclipse-mosquitto:2.0 \
    mosquitto_passwd -b -c /mosquitto/config/passwd "$MOSQUITTO_USERNAME" "$MOSQUITTO_PASSWORD"
  chown 1883:1883 "$SRV/mosquitto/config/passwd"
fi

echo ">> Grafana datasource (InfluxDB)"
eval "$(grep -E '^INFLUX_' "$OPT/.env")"
cat > "$SRV/grafana/provisioning/datasources/influxdb.yaml" <<EOF
apiVersion: 1
datasources:
  - name: InfluxDB
    type: influxdb
    access: proxy
    url: http://influxdb:8086
    jsonData:
      version: Flux
      organization: $INFLUX_ORG
      defaultBucket: $INFLUX_BUCKET
    secureJsonData:
      token: $INFLUX_ADMIN_TOKEN
EOF
chown -R 472:472 "$SRV/grafana/provisioning"

echo ">> Validando compose"
cd "$OPT"
docker compose --env-file "$OPT/.env" -f "$OPT/compose.yml" config >/dev/null || { echo "FAILED compose-config" > "$STATUS"; exit 1; }

echo ">> Subindo containers"
docker compose --env-file "$OPT/.env" -f "$OPT/compose.yml" up -d
sleep 8
docker compose --env-file "$OPT/.env" -f "$OPT/compose.yml" ps

echo "DONE $(date -Iseconds)" > "$STATUS"
echo "IOT-DEPLOY-COMPLETE"
