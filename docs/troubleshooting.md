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

O kiosk usa:

```text
--disable-translate
--disable-features=Translate,TranslateUI
```

E politica:

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
