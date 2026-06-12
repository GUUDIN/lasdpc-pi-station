#!/usr/bin/env bash
# ============================================================
# 40 — Stack IoT (Mosquitto/Node-RED/Grafana/InfluxDB2/Homepage).
# Subcomandos: (vazio|up) | down | status | logs | update | secrets
# Envia compose+configs p/ /opt, dados em /srv, segredos gerados na Pi (.env 600),
# valida 'docker compose config' ANTES de subir. Idempotente. Usa sudo docker.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env
CMD="${1:-up}"

OPT="$REMOTE_BASE/docker"          # /opt/lasdpc-pi-station/docker
SRV="$REMOTE_DATA"                 # /srv/lasdpc-pi-station
DC="sudo docker compose --env-file $OPT/.env -f $OPT/compose.yml"

dc_remote() { pi_ssh "cd $OPT && $DC $*"; }

case "$CMD" in
  up)
    log "Etapa 8 — subindo stack IoT em $PI_HOST"

    log ">> Criando diretórios de dados em $SRV (permissões por serviço)"
    pi_ssh "set -e
      sudo mkdir -p $OPT \
        $SRV/mosquitto/config $SRV/mosquitto/data $SRV/mosquitto/log \
        $SRV/node-red/data $SRV/influxdb/data $SRV/influxdb/config \
        $SRV/grafana/data $SRV/grafana/provisioning/datasources \
        $SRV/homepage/config
      sudo chown -R 1883:1883 $SRV/mosquitto || true
      sudo chown -R 1000:1000 $SRV/node-red || true
      sudo chown -R 472:472   $SRV/grafana || true
      sudo chown -R 1000:1000 $SRV/homepage || true
    "

    log ">> Enviando compose + configs"
    pi_rsync -a "$PROJECT_DIR/docker/compose.yml" "$PI_USER@$PI_HOST:/tmp/compose.yml"
    pi_ssh "sudo mv /tmp/compose.yml $OPT/compose.yml"
    pi_rsync -a "$PROJECT_DIR/docker/mosquitto/config/mosquitto.conf" "$PI_USER@$PI_HOST:/tmp/mosquitto.conf"
    pi_ssh "sudo mv /tmp/mosquitto.conf $SRV/mosquitto/config/mosquitto.conf && sudo chown 1883:1883 $SRV/mosquitto/config/mosquitto.conf"
    pi_rsync -a "$PROJECT_DIR/docker/homepage/config/" "$PI_USER@$PI_HOST:/tmp/hpcfg/"
    pi_ssh "sudo cp /tmp/hpcfg/*.yaml $SRV/homepage/config/ && sudo chown -R 1000:1000 $SRV/homepage/config && rm -rf /tmp/hpcfg"

    log ">> Gerando .env com segredos (só se não existir) — fora do Git, chmod 600"
    pi_ssh "set -e
      if [ ! -f $OPT/.env ]; then
        GFP=\$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)
        INFP=\$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)
        INFT=\$(openssl rand -hex 32)
        MQP=\$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)
        sudo tee $OPT/.env >/dev/null <<EOF
TZ=$PI_TIMEZONE
DATA_ROOT=$SRV
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=\$GFP
INFLUX_USERNAME=admin
INFLUX_PASSWORD=\$INFP
INFLUX_ORG=lasdpc
INFLUX_BUCKET=iot
INFLUX_ADMIN_TOKEN=\$INFT
INFLUX_RETENTION=30d
MOSQUITTO_USERNAME=iot
MOSQUITTO_PASSWORD=\$MQP
EOF
        sudo chmod 600 $OPT/.env
        echo '   .env criado com segredos fortes'
      else
        echo '   .env já existe (mantido)'
      fi
    "

    log ">> Criando arquivo de senha do Mosquitto (sem anônimo)"
    pi_ssh "set -e
      eval \$(sudo grep -E '^MOSQUITTO_' $OPT/.env)
      if [ ! -f $SRV/mosquitto/config/passwd ]; then
        sudo docker run --rm -v $SRV/mosquitto/config:/mosquitto/config eclipse-mosquitto:2.0 \
          mosquitto_passwd -b -c /mosquitto/config/passwd \"\$MOSQUITTO_USERNAME\" \"\$MOSQUITTO_PASSWORD\"
        sudo chown 1883:1883 $SRV/mosquitto/config/passwd
        echo '   passwd criado'
      else echo '   passwd já existe'; fi
    "

    log ">> Provisionando datasource InfluxDB no Grafana"
    pi_ssh "set -e
      eval \$(sudo grep -E '^INFLUX_' $OPT/.env)
      sudo tee $SRV/grafana/provisioning/datasources/influxdb.yaml >/dev/null <<EOF
apiVersion: 1
datasources:
  - name: InfluxDB
    type: influxdb
    access: proxy
    url: http://influxdb:8086
    jsonData:
      version: Flux
      organization: \$INFLUX_ORG
      defaultBucket: \$INFLUX_BUCKET
    secureJsonData:
      token: \$INFLUX_ADMIN_TOKEN
EOF
      sudo chown -R 472:472 $SRV/grafana/provisioning
    "

    log ">> Validando 'docker compose config' (NÃO sobe se inválido)"
    if ! dc_remote config >/dev/null 2>"$LOG_DIR/iot-config-err.txt"; then
      err "compose config inválido:"; cat "$LOG_DIR/iot-config-err.txt"; exit 1
    fi
    ok "compose config válido"

    log ">> Subindo containers (pull + up -d)"
    dc_remote up -d 2>&1 | tee "$LOG_DIR/iot-up-$(ts).log"
    sleep 5
    log ">> Status"
    dc_remote ps
    ok "Stack IoT no ar. Portas LAN: Node-RED 1880 | Grafana 3000 | InfluxDB 8086 | Mosquitto 1883 | Homepage 8080"
    warn "Senhas iniciais em $OPT/.env na Pi (chmod 600). Veja com: ./scripts/40-iot-stack.sh secrets"
    ;;
  down)    log "Parando stack IoT"; dc_remote down ;;
  status)  dc_remote ps ;;
  logs)    dc_remote logs --tail=80 ;;
  update)  log "Atualizando imagens"; dc_remote pull && dc_remote up -d ;;
  secrets) pi_ssh "sudo cat $OPT/.env" ;;
  *) die "Subcomando inválido: $CMD (use: up|down|status|logs|update|secrets)" ;;
esac
