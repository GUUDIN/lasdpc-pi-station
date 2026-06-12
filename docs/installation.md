# Instalacao

Este documento registra a instalacao real da LASDPC Pi Station em 2026-06-12.

## Base validada

- Hardware: Raspberry Pi 4 Model B Rev 1.5, 8 GB.
- Sistema: Debian GNU/Linux 13 (trixie), kernel `6.12.75+rpt-rpi-v8`, arm64.
- Sessao grafica: Wayland/labwc com autologin do usuario `lasdpc`.
- Armazenamento: microSD SanDisk 64 GB novo, raiz com 58 GB, 46 GB livres apos instalacao.
- Timezone: `America/Sao_Paulo`.
- Locale: `pt_BR.UTF-8`.
- Teclado: `br/abnt2`.

O microSD original falhou por corrupcao ext4 e baixa taxa de escrita. Ele foi substituido antes da validacao final.

## Ordem de execucao

As fases foram executadas por scripts idempotentes do repositorio:

```sh
make preflight
make ssh-test
make inspect
make backup
make base
make docker
make iot
make kiosk
make kodi
make launcher
make hardening
make status
```

RetroPie nao foi instalado. O preflight bloqueou a instalacao porque RetroPie-Setup nao suporta Debian/Raspberry Pi OS Trixie neste momento.

## Docker

Docker foi instalado via repositorio oficial para Debian Trixie arm64.

Versoes validadas:

- Docker Engine `29.5.3`.
- Docker Compose `v5.1.4`.

O usuario `lasdpc` nao foi adicionado ao grupo `docker`; scripts administrativos usam `sudo docker`.

## Kiosk e launcher

Artefatos instalados:

- `/usr/local/bin/lasdpc-mode`
- `/usr/local/bin/lasdpc-kiosk`
- `/usr/local/bin/lasdpc-session`
- `/usr/local/bin/lasdpc-restart-kiosk`
- `/usr/local/bin/lasdpc-status`
- `/opt/lasdpc-pi-station/launcher/server.py`
- `/etc/systemd/system/lasdpc-launcher.service`

A politica `/etc/chromium/policies/managed/lasdpc-kiosk.json` define `TranslateEnabled=false`, evitando overlay de traducao no dashboard.

## Kodi

Kodi foi instalado pelos pacotes do Raspberry Pi OS/Debian:

- Kodi `21.3`, pacote `3:21.3+dfsg-1+rpt2`.
- `kodi --standalone` abre corretamente no modo `media`.
- Ao sair do Kodi, o modo volta para `menu`.

## Hardening

SSH foi configurado para:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
```

UFW esta ativo com entrada negada por padrao, `tailscale0` liberado e portas da LAN permitidas para `10.0.0.0/22`.

## Pendencia de pacotes

`dpkg --audit` esta limpo e `apt-get -f install` nao tem pendencias. `apt list --upgradable` ainda mostra kernel/eeprom:

- `linux-headers-rpi-2712`
- `linux-headers-rpi-v8`
- `linux-image-rpi-2712`
- `linux-image-rpi-v8`
- `rpi-eeprom`

Eles nao foram trocados por `apt upgrade` normal. Planeje janela de manutencao para `sudo apt full-upgrade` se desejar atualizar kernel/eeprom.
