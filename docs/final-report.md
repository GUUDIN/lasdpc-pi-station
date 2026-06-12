# Relatorio final - LASDPC Pi Station

Data: 2026-06-12

## Hardware e sistema

- Equipamento: Raspberry Pi 4 Model B Rev 1.5, 8 GB.
- Armazenamento: microSD SanDisk 64 GB novo. O microSD original falhou por corrupcao ext4 e foi substituido.
- SO: Debian GNU/Linux 13 (trixie), arm64, kernel `6.12.75+rpt-rpi-v8`.
- Hostname: `lasdpc-pi-display-01`.
- Timezone/locale/teclado: `America/Sao_Paulo`, `pt_BR.UTF-8`, `br/abnt2`.
- Grafico: Wayland/labwc com autologin do usuario `lasdpc`.
- Tela validada: HDMI-A-2, 1920x1080 a 60 Hz.

## Enderecos e acesso

- Tailscale: `100.84.255.77`.
- MagicDNS: `lasdpc-pi-display-01-1.tail499ac4.ts.net`.
- LAN laboratorio: `10.0.1.218/22`.
- SSH: `ssh -i ~/.ssh/id_ed25519 lasdpc@100.84.255.77`.
- VNC: `100.84.255.77:5900`.
- Porta 80: sem servico; use portas explicitas.

## Componentes instalados

- Docker Engine `29.5.3` e Compose `v5.1.4`.
- Mosquitto, InfluxDB 2, Node-RED, Grafana OSS e Homepage via Docker.
- Chromium kiosk com menu central e dashboard.
- Kodi `21.3`.
- Tailscale, UFW, WayVNC.
- Healthcheck periodico `lasdpc-healthcheck.timer`.

## Componentes nao instalados

- RetroPie/EmulationStation: bloqueados porque RetroPie-Setup nao suporta Trixie. Relatorio: `logs/retropie-preflight-20260612-130135.md`.
- ares: instalado via apt como emulador multi-sistema compativel com Debian Trixie, incluindo N64.
- ROMs/BIOS: nao baixados e nao fornecidos.

## URLs e portas

| Servico | Porta | URL |
|---|---:|---|
| Homepage IoT | 8080 | `http://100.84.255.77:8080` |
| Grafana | 3000 | `http://100.84.255.77:3000` |
| Node-RED | 1880 | `http://100.84.255.77:1880` |
| InfluxDB | 8086 | `http://100.84.255.77:8086` |
| Mosquitto MQTT | 1883 | `100.84.255.77:1883` |
| VNC | 5900 | `100.84.255.77:5900` |
| Menu local | 8090 | `http://localhost:8090` na Pi |

## Systemd

- `docker.service`: enabled.
- `tailscaled.service`: enabled.
- `wayvnc.service`: enabled.
- `ufw.service`: enabled.
- `lasdpc-launcher.service`: enabled.
- `lasdpc-healthcheck.timer`: enabled.
- `fstrim.timer`: enabled e validado.
- `smartmontools.service`: desativado/resetado por incompatibilidade com microSD.

## Containers

Validacao final: 5/5 healthy.

- `lasdpc-mosquitto`
- `lasdpc-influxdb`
- `lasdpc-nodered`
- `lasdpc-grafana`
- `lasdpc-homepage`

## Diretorios

- Codigo remoto: `/opt/lasdpc-pi-station`.
- Dados persistentes: `/srv/lasdpc-pi-station`.
- Backups: `/var/backups/lasdpc-pi-station`.
- Segredos Docker: `/opt/lasdpc-pi-station/docker/.env`, fora do Git, `0600`.

## Modos e controles

```sh
lasdpc-mode menu
lasdpc-mode dashboard
lasdpc-mode media
lasdpc-mode desktop
lasdpc-restart-kiosk
lasdpc-status
```

Modo inicial/final validado: `menu`.

Kodi abre em `media` e, ao sair, retorna ao `menu`. `games` abre o ares quando EmulationStation nao esta instalado. Foi corrigida uma corrida em `lasdpc-mode` que podia matar apps recem-lancados.

## Audio e video

- Video HDMI validado por captura Wayland.
- Audio HDMI selecionado como default no PipeWire.
- Teste de tom bem-sucedido em `plughw:CARD=vc4hdmi1,DEV=0`.

## Saude final

- `systemctl --failed`: 0 units.
- `dpkg --audit`: limpo.
- `apt-get -f install`: sem pendencias.
- Throttling: `throttled=0x0`.
- Temperatura durante validacao: cerca de 66-67 C.
- Disco: 58 GB total, 46 GB livres em `/`.
- Memoria: 7.6 GiB total, cerca de 6.5 GiB disponivel.

## Pendencias

- Avaliar janela de manutencao para `apt full-upgrade` de kernel/eeprom: ha 5 pacotes upgradable que `apt upgrade` normal nao removeu.
- Apagar no admin console do Tailscale o no antigo/stale `lasdpc-pi-display-01` para recuperar o nome sem sufixo.
- Para jogos dedicados, considerar unidade Batocera/Recalbox; para uso integrado no Debian atual, usar ares e copiar ROMs legais para `/srv/lasdpc-pi-station/roms`.
