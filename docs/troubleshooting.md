# Troubleshooting

## `100.84.255.77` mostra resposta invalida ou nao abre

Nao ha servidor na porta 80. Use portas explicitas:

```text
http://100.84.255.77:8080  # Homepage IoT
http://100.84.255.77:3000  # Grafana
http://100.84.255.77:1880  # Node-RED
http://100.84.255.77:8086  # InfluxDB
```

O menu da TV roda na propria Pi em `http://localhost:8090`.

## Tela preta ou sem imagem

Verifique HDMI e sessao:

```sh
wlr-randr
pgrep -a -u lasdpc 'labwc|chromium|kodi|wayvnc'
cat ~/.config/lasdpc/mode
```

Captura da tela Wayland:

```sh
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 grim /tmp/screen.png
```

O estado validado detectou `HDMI-A-2`, 1920x1080 a 60 Hz.

## Menu nao volta apos Kodi

Verifique o runner e o modo:

```sh
cat ~/.config/lasdpc/mode
pgrep -a -u lasdpc 'kodi|chromium|lasdpc-session'
journalctl -t lasdpc-session -n 100 --no-pager
```

Foi corrigida uma corrida em `lasdpc-mode`: o script nao deve matar o app-alvo do novo modo. A versao corrigida esta em `/usr/local/bin/lasdpc-mode` e `remote/bin/lasdpc-mode`.

## Barra de traducao no dashboard

No Chromium >= ~140 as flags `--disable-translate`/`--disable-features=Translate,TranslateUI`
nao escondem mais a barra; o que vale e a politica (instalada por `make launcher`):

```sh
cat /etc/chromium/policies/managed/lasdpc-kiosk.json
```

Valor esperado:

```json
{"TranslateEnabled": false}
```

Reinicie o kiosk:

```sh
lasdpc-mode dashboard
```

## Spotify: "TV LASDPC" nao aparece no celular

O Spotify Connect roda como servico do usuario (`lasdpc-spotify.service`, librespot do pacote
raspotify), nao como o servico de sistema da raspotify. Checklist:

```sh
systemctl --user status lasdpc-spotify                       # ativo?
avahi-browse -rtp _spotify-connect._tcp | grep wlan0         # anunciado com o IP da rede?
curl -s "http://$(hostname -I | cut -d' ' -f1):5354/?action=getInfo"   # responde "TV LASDPC"?
```

Causas ja vistas:

- **Nao instalado**: na migracao para o Bookworm o `make media-install` nao tinha rodado.
- **Servico de sistema da raspotify**: roda isolado com ALSA direto e briga com o PipeWire da
  sessao pelo HDMI (aparece mas nao toca, ou cai). Deve ficar `disabled`.
- **IPs do Docker**: o mDNS interno do librespot anunciava tambem 172.17/18/19.x (bridges do
  Docker), que o celular nao alcanca. Use `--zeroconf-backend avahi` (ja no unit).
- **Rede**: o celular precisa estar na **mesma rede** da Pi (10.0.0.0/22). Wi-Fi com isolamento
  de clientes (eduroam, redes de convidados) bloqueia a descoberta. Depois que alguem conecta
  uma vez na mesma rede, o login fica em cache e a TV passa a aparecer na lista de dispositivos
  da conta.
- **Saida de audio**: o padrao precisa ser o HDMI (`wpctl status`; `wpctl set-default <id>`),
  senao o som sai pelo conector de fone.

## Containers fora do ar

```sh
cd /opt/lasdpc-pi-station/docker
sudo docker compose ps
sudo docker compose logs --tail=100 SERVICE
sudo docker compose up -d
```

Verifique espaco e saude:

```sh
df -h
sudo docker system df
systemctl --failed
```

## Audio HDMI sem som

Verifique o sink padrao:

```sh
XDG_RUNTIME_DIR=/run/user/1000 wpctl status
```

O sink esperado e `Audio interno Digital Stereo (HDMI)`. Ajuste:

```sh
XDG_RUNTIME_DIR=/run/user/1000 wpctl set-default 45
XDG_RUNTIME_DIR=/run/user/1000 wpctl set-volume @DEFAULT_AUDIO_SINK@ 60%
```

Teste direto no conector ativo:

```sh
speaker-test -D plughw:CARD=vc4hdmi1,DEV=0 -c 2 -t sine -f 880 -l 1
```

## Temperatura alta ou throttling

```sh
vcgencmd measure_temp
vcgencmd get_throttled
```

`throttled=0x0` e o estado bom. Se houver bits ativos ou temperatura sustentada acima de 80 C, melhorar ventilacao/fonte antes de carga pesada.

## Erros ext4 ou I/O

O microSD original falhou e foi substituido. Se reaparecerem erros como `bad block bitmap checksum`, `I/O error` ou remount read-only:

1. Pare writes pesados.
2. Copie `/var/log/syslog`, `journalctl -k` e dados importantes.
3. Suspeite do armazenamento ou fonte.
4. Prepare novo cartao/SSD e restaure backup.

## Pi 4 com Raspberry Pi OS 12 (Bookworm) — jogos/N64

Validado em 2026-10-01 numa Pi 4 8 GB com Bookworm + labwc 0.8.1.

- **RetroArch do apt (1.14) nao tem Vulkan** (`retroarch --features` → `Vulkan: no`),
  e o N64 (parallel_n64 + parallel-rdp) exige Vulkan. Solucao: compilar o RetroArch
  1.20.0 com `--enable-vulkan --enable-wayland` e instalar em `/usr/local`
  (precisa de `libvulkan-dev libx11-xcb-dev libwayland-dev wayland-protocols ...`).
- **Fullscreen do RetroArch** e feito pelo labwc (`windowRule identifier="com.libretro.RetroArch"`
  + `video_fullscreen=false`). A regra antiga `identifier="retroarch"` nunca casava com o
  app_id Wayland real (`com.libretro.RetroArch`).
- **Crash ao entrar em fullscreen** (`Failed to create swapchain (VkResult -1)` + segfault):
  no fullscreen o wlroots oferece direct scanout e o Mesa realoca a swapchain como buffer
  de scanout (CMA contigua). Com a CMA fragmentada (ex.: app Electron/Chromium renderizando
  em `/dev/dri/card1`) a alocacao falha. Correcao: em `~/.config/labwc/environment`
  adicionar `WLR_SCENE_DISABLE_DIRECT_SCANOUT=1` e reiniciar a sessao.
  Confirmado: em labwc aninhado (sem scanout) o N64 roda fullscreen a 60 FPS.
- ES-DE 3.4.1: URL de download retorna 404 (irrelevante — ES-DE nao roda no Pi 4).
- Scripts aceitam usuario diferente de `lasdpc` (`PI_USER` no `.env`).
- `remote/kiosk/labwc-rc.xml` e do Trixie: tema `PiXtrix`, fonte `Nunito Sans` e campo
  `icon` do windowSwitcher nao existem no Bookworm/labwc 0.8.1. Nesta Pi o rc.xml instalado
  usa `PiXflat`/`PibotoLt` e so o campo `title` (re-aplicar apos `make kiosk-config`).
- Receptor Microsoft 2.4GHz v8.0 (045e:0745): scroll hi-res quebrado. Quirk em
  `/etc/libinput/local-overrides.quirks` com `AttrEventCodeDisable=REL_WHEEL_HI_RES;REL_HWHEEL_HI_RES;`
  (libinput 1.22 nao aceita a sintaxe nova `AttrEventCode=-...`).
- **N64 "travado" (tela cinza/preta, RetroArch a 100% de CPU)**: e o parallel_n64 com
  parallel-rdp, que na V3D do Pi 4 nao passa de ~13 FPS. Rode `make n64-core`
  (mupen64plus_next GLES3); ver [gaming.md](gaming.md#n64-use-o-core-mupen64plus_next-gles3).
