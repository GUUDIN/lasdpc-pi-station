# HANDOFF — LASDPC Pi Station (para continuar a configuração)

> Documento de transferência de sessão. Estado em **2026-06-12 ~14:00 -03**.
> Continuação prevista em outro agente (Codex). Tudo idempotente; pode reexecutar.

## TL;DR do que falta AGORA
1. **`apt upgrade` está rodando DESTACADO na Pi** (systemd unit `lasdpc-upgrade`, ~198 pacotes).
   **NÃO reinicie a Pi** até `cat /var/log/lasdpc/upgrade.status` mostrar `DONE` e `sudo dpkg --audit` estar limpo.
2. Depois: **reboot de validação (Etapa 18)** + **relatório final** + preencher `docs/*.md` (ainda são esqueleto).
3. Limpeza rápida: `smartmontools.service` está falhando (microSD não tem SMART) →
   `sudo systemctl disable --now smartmontools.service && sudo systemctl reset-failed smartmontools.service`
   (no cartão antigo também desativamos `fstrim.timer`; conferir se reapareceu).

## Acesso
- **Tailscale (primário agora):** `ssh lasdpc@100.84.255.77` (MagicDNS `lasdpc-pi-display-01-1.tail499ac4.ts.net`).
  O `.env` já está com `PI_HOST=100.84.255.77`.
- **LAN (só dentro do lab):** `10.0.1.218`.
- **Usuário:** `lasdpc` · **chave:** `~/.ssh/id_ed25519` · **sudo:** NOPASSWD (`/etc/sudoers.d/010-lasdpc-nopasswd`).
- **VNC (tela):** RealVNC Viewer → `100.84.255.77:5900`, login `lasdpc` + senha (wayvnc, TLS+PAM).
- Nó Tailscale **antigo** `lasdpc-pi-display-01` (100.120.120.57) está offline/stale → **apagar no admin console** pra reaver o nome limpo (o atual ficou com sufixo `-1`).

## Hardware/OS (contexto crítico)
- Raspberry Pi 4 Model B **Rev 1.5, 8GB**. **Debian 13 Trixie** (Raspberry Pi OS), kernel 6.12, **arm64**.
- Compositor **Wayland/labwc**, desktop com autologin (usuário lasdpc).
- **microSD NOVO 64GB SanDisk (Malásia)** — saudável, escrita **~27 MB/s**.
  - ⚠️ O **cartão original FALHOU** (corrupção ext4 "bad block bitmap checksum" + "Data will be lost", 3.3 MB/s, Verify falhava na gravação). Foi **substituído**. Se reaparecerem erros ext4, suspeitar de novo do armazenamento.

## O que JÁ está feito (e validado)
- **Base (Etapa 4):** hostname `lasdpc-pi-display-01`, tz `America/Sao_Paulo`, locale `pt_BR.UTF-8`, teclado `br/abnt2`, pacotes básicos, journald limitado (100M). *(apt upgrade completo estava pendente → rodando agora.)*
- **Docker (Etapa 7):** Engine **29.5.3** + Compose **v5.1.4** (repo oficial, trixie/arm64). Log rotation. Usuário NÃO está no grupo docker (scripts usam `sudo docker`).
- **IoT (Etapa 8):** 5/5 containers **healthy** — `lasdpc-mosquitto`(1883), `lasdpc-influxdb`(8086), `lasdpc-nodered`(1880), `lasdpc-grafana`(3000), `lasdpc-homepage`(8080).
  - Compose: `/opt/lasdpc-pi-station/docker/compose.yml` · dados: `/srv/lasdpc-pi-station/*` · **segredos: `/opt/lasdpc-pi-station/docker/.env` (chmod 600, root)** — ver com `sudo cat`.
  - Mosquitto sem anônimo (user `iot`). Grafana admin via .env. InfluxDB org `lasdpc`, bucket `iot`.
- **Kiosk/modos (Etapas 5/6/12):** comandos `lasdpc-mode {dashboard|menu|media|games|desktop}`, `lasdpc-restart-kiosk`, `lasdpc-status` em `/usr/local/bin`. Runner `lasdpc-session` no autostart do labwc (`~/.config/labwc/autostart`). Menu central web em `localhost:8090` (`lasdpc-launcher.service`). Fallback local. **Modo inicial = `menu`.** Estado em `~/.config/lasdpc/mode`, `session.env` (DASHBOARD_URL=http://localhost:8080).
  - ⚠️ **Ainda NÃO validado visualmente na tela** — a sessão de modos ativa de fato no próximo reboot/reload do labwc. Validar via VNC após o reboot.
- **Kodi (Etapa 9):** instalado (build RPi 21.x) + joystick + inputstream-adaptive. Volta ao menu ao sair (lasdpc-session).
- **RetroPie (Etapa 10):** **BLOQUEADO** — Trixie não é suportado pelo RetroPie-Setup (até Bookworm). Relatório em `logs/retropie-preflight-*.md`. Alternativa documentada: unidade dedicada com Batocera/Recalbox, sem tocar no OS. **NÃO rodar `make retropie`.**
- **Healthcheck (Etapa 14):** `lasdpc-healthcheck.sh` + `lasdpc-healthcheck.timer` (15 min).
- **VNC:** wayvnc habilitado (`sudo raspi-config nonint do_vnc 0`), porta 5900.
- **Hardening (Etapa 13):** SSH key-only + sem root (`/etc/ssh/sshd_config.d/10-lasdpc-hardening.conf`). **ufw** ativo: `tailscale0` liberado, `41641/udp`, SSH+VNC+IoT só da LAN `10.0.0.0/22`. unattended-upgrades (segurança). Backstop de auto-revert do ufw foi usado e cancelado.
  - ⚠️ Portas publicadas pelo Docker **contornam o ufw** (DOCKER chain). Proteção real: NAT + Tailscale.

## Próximos passos (ordem)
1. Esperar `lasdpc-upgrade` → `DONE`; `sudo dpkg --audit` limpo; `sudo apt-get -f install`.
2. Desativar `smartmontools.service` (e conferir `fstrim.timer`).
3. **Reboot de validação:** `ssh ... 'sudo reboot'`; reconectar via Tailscale (`100.84.255.77` volta sozinho — tailscaled enabled). Verificar:
   - `systemctl --failed`, `docker ps` (5/5), `vcgencmd get_throttled/measure_temp`, `df -h`, `free -h`.
   - Tela via VNC: deve abrir no **menu** (mode=menu). Testar `lasdpc-mode dashboard|media|desktop|menu`.
   - Áudio HDMI, retorno ao menu ao sair do Kodi.
4. **Relatório final** (modelo no prompt do projeto, "Forma de execução").
5. Preencher `docs/architecture|installation|operation|troubleshooting|gaming|rom-transfer|security|recovery.md` (hoje são esqueleto).

## Armadilhas técnicas (aprendidas nesta sessão)
- O **Bash tool roda sob zsh** no Mac; **não** faça `. scripts/lib/common.sh` direto (usa `BASH_SOURCE`). Os scripts `./scripts/*.sh` rodam certo pelo shebang. zsh não faz word-splitting de variáveis (`$SSH cmd` falha) — chame `ssh` direto.
- **Bash do Mac é 3.2** (sem `mapfile`/`declare -A`). `common.sh` já foi adaptado.
- **Operações longas na Pi → DESTACAR** (Wi-Fi/Tailscale caem). Padrão usado:
  `sudo systemd-run --unit=X --collect /bin/bash -c "mkdir -p /var/log/lasdpc; exec bash /caminho/script.sh >> /var/log/lasdpc/X.log 2>&1"` e poll de `X.status`.
  **Criar `/var/log/lasdpc` ANTES** do redirect (senão falha).
- Pull de imagens Docker: fazer **sequencial** (`docker pull` um a um) — paralelo sobrecarrega a extração no SD.
- Scripts auto-contidos (rodam como root na Pi) em `remote/bin/`: `lasdpc-base-complete.sh`, `lasdpc-docker.sh`, `lasdpc-iot-deploy.sh`, `lasdpc-kodi-install.sh`, `lasdpc-redeploy.sh` (master). Foram enviados pra `/home/lasdpc/lasdpc-deploy/` na Pi.

## Comandos úteis
- Status geral: `ssh lasdpc@100.84.255.77 lasdpc-status`
- Logs de fase: `ssh lasdpc@100.84.255.77 'tail -f /var/log/lasdpc/upgrade.log'`
- IoT: `cd scripts && ./40-iot-stack.sh {up|down|status|logs|secrets}` (usa `.env` → Tailscale)
- Make: `make help` (mas vários alvos chamam scripts que SSHam via `.env`)
