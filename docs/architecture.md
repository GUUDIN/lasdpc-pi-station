# Arquitetura

## Visao geral

A LASDPC Pi Station e uma Raspberry Pi 4 Model B Rev 1.5, 8 GB, rodando Debian GNU/Linux 13 (trixie) arm64. Ela combina tres superficies:

- Tela local HDMI em Wayland/labwc, com menu central e modos mutuamente exclusivos.
- Stack IoT permanente em Docker, independente do modo visual.
- Administracao remota por SSH/Tailscale e VNC.

O modo inicial validado e `menu`. A tela HDMI conectada foi detectada como `HDMI-A-2`, 1920x1080 a 60 Hz.

## Enderecos

| Interface | Endereco | Uso |
|---|---:|---|
| Tailscale | `100.84.255.77` | SSH, VNC e administracao remota principal |
| MagicDNS | `lasdpc-pi-display-01-1.tail499ac4.ts.net` | Alternativa ao IP Tailscale |
| WLAN/LAN | `10.0.1.218/22` | Acesso dentro da rede do laboratorio |
| Hostname | `lasdpc-pi-display-01` | Nome local da estacao |

Nao ha servico HTTP na porta 80. Use portas explicitas, por exemplo `http://100.84.255.77:8080`.

## Modos visuais

| Modo | Comando | Aplicacao |
|---|---|---|
| Menu | `lasdpc-mode menu` | Menu central local em Chromium kiosk (`localhost:8090`) |
| Dashboard | `lasdpc-mode dashboard` | Homepage IoT em Chromium kiosk (`localhost:8080`) |
| Media | `lasdpc-mode media` | Receiver AirPlay audio via UxPlay + Spotify Connect via Raspotify |
| YouTube | `lasdpc-mode youtube` | YouTube TV em Chromium kiosk para pareamento por codigo no celular |
| Desktop | `lasdpc-mode desktop` | Desktop labwc normal |
| Games | `lasdpc-mode games` | EmulationStation se existir; caso contrario `ares` |

O runner `lasdpc-session` e iniciado pelo autostart do usuario labwc. O autostart global do Raspberry Pi OS continua responsavel por painel, desktop e kanshi; o autostart do projeto adiciona apenas o runner para evitar barras duplicadas.

Ele le `~/.config/lasdpc/mode` e mantem o app do modo atual. Ao sair do YouTube ou do emulador, o runner volta automaticamente para `menu`.

O modo `dashboard` usa `DASHBOARD_URL` em `~/.config/lasdpc/session.env`. A lista editavel pelo menu fica em `~/.config/lasdpc/dashboards.json`.

## Stack IoT

Compose remoto: `/opt/lasdpc-pi-station/docker/compose.yml`.
Dados persistentes: `/srv/lasdpc-pi-station`.
Segredos: `/opt/lasdpc-pi-station/docker/.env`, `root:root`, `0600`, fora do Git.

| Container | Porta | Dados |
|---|---:|---|
| `lasdpc-mosquitto` | 1883 | `/srv/lasdpc-pi-station/mosquitto` |
| `lasdpc-influxdb` | 8086 | `/srv/lasdpc-pi-station/influxdb` |
| `lasdpc-nodered` | 1880 | `/srv/lasdpc-pi-station/node-red/data` |
| `lasdpc-grafana` | 3000 | `/srv/lasdpc-pi-station/grafana` |
| `lasdpc-homepage` | 8080 | `/srv/lasdpc-pi-station/homepage/config` |

Todos usam restart `unless-stopped`, healthchecks e log rotation Docker.

## Servicos systemd

| Unit | Funcao |
|---|---|
| `docker.service` | Runtime dos containers |
| `tailscaled.service` | Acesso Tailscale |
| `wayvnc.service` | VNC em Wayland, porta 5900 |
| `lasdpc-launcher.service` | Menu central HTTP local, porta 8090 |
| `lasdpc-healthcheck.timer` | Healthcheck a cada 15 minutos |
| `fstrim.timer` | TRIM semanal; validado com sucesso no microSD novo |

`smartmontools.service` foi desativado porque microSD nao expoe SMART util.

## Fluxo de boot

1. Debian inicia `tailscaled`, `docker`, `wayvnc` e `lasdpc-launcher`.
2. Autologin abre sessao Wayland/labwc do usuario `lasdpc`.
3. Autostart do labwc executa `lasdpc-session`.
4. `lasdpc-session` le o modo persistido e abre menu/dashboard/Kodi ou deixa desktop livre.
5. Stack IoT sobe em paralelo e fica ativa em todos os modos.
