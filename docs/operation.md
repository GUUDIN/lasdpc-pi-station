# Operacao

## Acesso

SSH principal:

```sh
ssh -i ~/.ssh/id_ed25519 lasdpc@100.84.255.77
```

VNC:

```text
100.84.255.77:5900
```

Use Tailscale como caminho primario. O IP LAN `10.0.1.218` so funciona quando a maquina de controle estiver na rede do laboratorio.

## URLs

| Servico | URL via Tailscale |
|---|---|
| Menu central da tela | apenas local na Pi: `http://localhost:8090` |
| Homepage IoT | `http://100.84.255.77:8080` |
| Grafana | `http://100.84.255.77:3000` |
| Node-RED | `http://100.84.255.77:1880` |
| InfluxDB | `http://100.84.255.77:8086` |
| MQTT | `100.84.255.77:1883` |

`http://100.84.255.77` sem porta nao responde porque nao existe servico na porta 80.

## Troca de modos

```sh
lasdpc-mode menu
lasdpc-mode dashboard
lasdpc-mode media
lasdpc-mode desktop
lasdpc-mode games
```

O modo atual fica em:

```sh
cat ~/.config/lasdpc/mode
```

`media` abre Kodi. Ao sair do Kodi, a sessao volta automaticamente ao menu.

`games` abre EmulationStation se existir; no Debian/Trixie atual abre `ares`, instalado via apt, para emulacao multi-sistema. ROMs legais podem ficar em `/srv/lasdpc-pi-station/roms`, com N64 em `/srv/lasdpc-pi-station/roms/n64`.

## Status cotidiano

```sh
lasdpc-status
systemctl --failed
sudo docker ps
vcgencmd get_throttled
vcgencmd measure_temp
df -h
free -h
```

Status final validado:

- `systemctl --failed`: 0 units.
- Docker: 5/5 containers healthy.
- Throttling: `throttled=0x0`.
- Temperatura durante validacao: cerca de 66-67 C.
- Espaco raiz: 58 GB total, 46 GB livres.
- Memoria: 7.6 GiB total, cerca de 6.5 GiB disponivel.

## Docker

Na Pi:

```sh
cd /opt/lasdpc-pi-station/docker
sudo docker compose ps
sudo docker compose logs -f
sudo docker compose pull
sudo docker compose up -d
```

No Mac, pelos scripts:

```sh
cd /Users/pedro/Development/lasdpc-pi-station
cd scripts
./40-iot-stack.sh status
./40-iot-stack.sh logs
```

Para pull de imagens em microSD, prefira um container por vez.

## Audio HDMI

O sink PipeWire padrao foi ajustado para HDMI:

```sh
XDG_RUNTIME_DIR=/run/user/1000 wpctl status
XDG_RUNTIME_DIR=/run/user/1000 wpctl set-default 45
```

O conector ativo validado foi `vc4hdmi1`. Teste ALSA direto:

```sh
speaker-test -D plughw:CARD=vc4hdmi1,DEV=0 -c 2 -t sine -f 880 -l 1
```

## Atualizacao

Para atualizacoes longas, execute destacado via systemd para sobreviver a quedas de rede:

```sh
sudo systemd-run --unit=lasdpc-upgrade --collect /bin/bash -c \
  'mkdir -p /var/log/lasdpc; apt-get update && apt-get upgrade -y; echo DONE > /var/log/lasdpc/upgrade.status' \
  >> /var/log/lasdpc/upgrade.log 2>&1
```

Antes de reboot apos atualizacao:

```sh
cat /var/log/lasdpc/upgrade.status
sudo dpkg --audit
sudo apt-get -f install
```
