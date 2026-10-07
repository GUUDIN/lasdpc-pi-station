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

## Dashboards

O menu central tem a entrada `Dashboards`. Por ela e possivel selecionar a URL padrao do modo `dashboard` e cadastrar outras URLs sem SSH.

Opcoes padrao:

| Nome | URL |
|---|---|
| IoT local | `http://localhost:8080` |
| Andromeda | `http://andromeda.lasdpc.icmc.usp.br:60107/` |

Observacao: a porta `60107` do Andromeda foi validada como HTTP. A URL `https://andromeda.lasdpc.icmc.usp.br:60107/` falha por TLS (`wrong version number`) a partir da Pi.

Arquivos persistentes:

```text
~/.config/lasdpc/session.env
~/.config/lasdpc/dashboards.json
```

No painel:

- `Usar`: troca o dashboard padrao sem abrir imediatamente.
- `Abrir`: troca o dashboard padrao e entra no modo `dashboard`.

## Troca de modos

```sh
lasdpc-mode menu
lasdpc-mode dashboard
lasdpc-mode media
lasdpc-mode youtube
lasdpc-mode desktop
lasdpc-mode games
```

O modo atual fica em:

```sh
cat ~/.config/lasdpc/mode
```

`media` liga os receivers de midia: Spotify Connect fica sempre ativo via Raspotify, e AirPlay audio fica ativo enquanto o modo media estiver ligado. Ao sair de `media`, o UxPlay para.

`youtube` abre `https://www.youtube.com/tv` em Chromium kiosk com perfil dedicado. No Android ou iPhone, use o app do YouTube e o fluxo de pareamento por codigo de TV. Isto nao e Chromecast nativo; e o caminho suportavel para YouTube sem dongle Chromecast/Android TV.

`games` abre EmulationStation se existir; no Debian/Trixie atual abre `ares`, instalado via apt, para emulacao multi-sistema. ROMs legais podem ficar em `/srv/lasdpc-pi-station/roms`, com N64 em `/srv/lasdpc-pi-station/roms/n64`.

Para uma instalacao minima de TV do laboratorio, use apenas `desktop` + `dashboard` + menu central. `media` e `games` devem ser tratados como perfis opcionais por estacao.

### YouTube

Um unico tile **YouTube** abre a interface de TV do YouTube (`youtube.com/tv`) no Chromium
kiosk (`lasdpc-youtube`, modo `youtube`). Extensoes carregadas:

- `h264ify` — forca H.264, o unico codec que o Pi 4 decodifica por hardware (`/dev/video10`).
- `ubol` — uBlock Origin Lite (MV3; o Chromium >= 139 nao carrega mais o uBO classico),
  instalado por `lasdpc-ubol-install.sh` com versao e sha256 fixados.
- `ytads-extension` — remove `adPlacements`/`playerAds`/`adSlots` das respostas do player
  (tecnica do json-prune do uBO). O uBO Lite sozinho **nao** bloqueia os anuncios do
  YouTube TV (testado no modo otimizado e no completo).
- `escape-extension` — botao "← Menu" ao mexer o mouse. No YouTube, Esc/Backspace ficam com
  o app (sao o "voltar" dele); para sair use `Super+Esc` ou o botao.

Medido em 2026-10-07 (Chromium 154, `tools/yt-bench/ytprobe.py`, 3 videos populares):
1080p, 0-0,6% de quadros perdidos, ~25% de CPU, nenhum anuncio (sem a extensao: anuncio de
11-16 s em 3 de 3). **Nao** adicione `--use-gl=egl` nem flags `AcceleratedVideoDecode*`: no
Chromium da Pi elas desligavam o decoder de hardware (1080p por software, ~220% de CPU,
15-50% de quadros perdidos).

Celular: no YouTube da TV, Configuracoes → Vincular com codigo de TV; no app, digite o codigo
e use Transmitir. Os modos antigos `tv` (busca + mpv) e `ytcast` (receptor DIAL) continuam
disponiveis por SSH (`lasdpc-play`, `lasdpc-mode ytcast`), mas sairam do menu.

### Navegacao

- **Menu central:** mouse, setas/Tab + Enter, ou controle (direcional + A). Esc,
  Backspace ou B fecham a janela aberta. Energia pede uma 2a confirmacao no botao.
- **Musica / YouTube (celular):** botao "← Menu", Esc, Backspace ou B voltam ao menu.
- **Dashboards (kiosk):** Esc volta ao menu, Backspace volta uma pagina, Home abre o
  dashboard local; ao mexer o mouse aparece um botao "← Menu" no canto. As setas ficam
  livres para a propria pagina.
- **Qualquer app:** `Super+Esc` volta ao menu.

## Midia e Android

O Android e suportado por dois caminhos praticos:

- Spotify: selecionar `TV LASDPC <hostname>` no Spotify Connect.
- YouTube: abrir `YouTube na TV` no menu, parear o celular pelo codigo exibido no YouTube TV e controlar pelo app do YouTube.

O projeto nao promete Google Cast/Chromecast generico em Linux. Para Cast nativo universal, use um Chromecast/Android TV fisico conectado na TV.

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
