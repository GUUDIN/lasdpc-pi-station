# HANDOFF — LASDPC Pi Station

Estado salvo em 2026-06-12, fim da sessao Codex.

## Atualizacao 2026-06-13 — Etapa 4 (gaming) concluida com ressalva

- `make gaming-install` + `make gaming-check` (scripts 120/121): **AUTO PASS**.
  Instalados: RetroArch 1.20 (apt) + cores apt (nestopia/snes9x/genesis_plus_gx/gambatte)
  + `parallel_n64` (buildbot, N64) + ES-DE 3.4.1 AppImage (`/opt/es-de`).
- **ES-DE NAO renderiza no Pi 4**: exige OpenGL desktop 3.3, o V3D entrega 3.1
  (GLXBadFBConfig / EGL_BAD_MATCH). `SDL_VIDEODRIVER=wayland` e `GALLIUM_DRIVER=zink`
  nao resolvem (AppImage empacota a stack GL). Detalhes em `docs/gaming.md`.
- Por isso `lasdpc-mode games` usa **ares** por padrao; ES-DE so via
  `LASDPC_GAMES_FRONTEND=esde` (opt-in). `lasdpc-mode` ganhou `kill_esde()`.
- **MANUAL-PENDENTE** (operador fora do lab): validar on-screen o modo `games`
  (ares render + gamepad + desempenho N64). TCs manuais nao executados.
- Commits: `2f83b08` (scaffolding), `9ddb5e6` (+x), `45dd609` (resultado/incompat).

Proximas frentes sugeridas: Etapa 5 (Ship of Harkinian p/ Ocarina — melhor caminho N64),
Etapa 2 (AirPlay video best-effort) e Etapa 6 (operacionalizacao). Frontend de jogos
no Pi4 segue em aberto: avaliar ES-DE build GLES, EmulationStation GLES/Pegasus, ou
RetroArch direto.

## Acesso

- Projeto local: `/Users/pedro/Development/lasdpc-pi-station`
- Branch: `main`
- SSH Tailscale: `ssh -i ~/.ssh/id_ed25519 lasdpc@100.84.255.77`
- MagicDNS: `lasdpc-pi-display-01-1.tail499ac4.ts.net`
- VNC: `100.84.255.77:5900` via RealVNC Viewer
- Usuario: `lasdpc`, sudo NOPASSWD
- LAN, quando no laboratorio: `10.0.1.218`

Nao use `http://100.84.255.77` sem porta: nao ha servico na porta 80.

## Estado validado

- Hardware: Raspberry Pi 4 Model B Rev 1.5, 8 GB.
- SO: Debian GNU/Linux 13 Trixie, arm64, kernel `6.12.75+rpt-rpi-v8`.
- Grafico: Wayland/labwc com autologin.
- Tela HDMI: `HDMI-A-2`, 1920x1080 @ 60 Hz.
- Docker: 5/5 containers healthy.
- `systemctl --failed`: 0 units.
- `vcgencmd get_throttled`: `throttled=0x0`.
- Temperatura observada: ~66-69 C.
- Armazenamento: microSD SanDisk 64 GB novo. O microSD original falhou por corrupcao ext4 e foi substituido.
- Modo observado no fim desta sessao: `desktop` (nao forcei voltar para menu).

## Servicos e URLs

| Funcao | Porta/URL |
|---|---|
| VNC | `100.84.255.77:5900` |
| Homepage/dashboard IoT | `http://100.84.255.77:8080` |
| Grafana | `http://100.84.255.77:3000` |
| Node-RED | `http://100.84.255.77:1880` |
| InfluxDB | `http://100.84.255.77:8086` |
| MQTT Mosquitto | `100.84.255.77:1883` |
| Menu central local | `http://localhost:8090` na propria Pi |

Systemd relevante:

- `docker.service`
- `tailscaled.service`
- `wayvnc.service`
- `ufw.service`
- `lasdpc-launcher.service`
- `lasdpc-healthcheck.timer`
- `fstrim.timer`

`smartmontools.service` foi desativado/resetado porque microSD nao expoe SMART util.

## Modos

```sh
lasdpc-mode menu
lasdpc-mode dashboard
lasdpc-mode media
lasdpc-mode games
lasdpc-mode desktop
```

- `menu`: Chromium kiosk em `http://localhost:8090`.
- `dashboard`: Chromium kiosk em `DASHBOARD_URL`, hoje `http://localhost:8080`.
- `media`: Kodi standalone; ao sair, volta ao menu.
- `games`: abre EmulationStation se existir; caso contrario abre `ares`.
- `desktop`: desktop labwc normal.

Arquivo de configuracao do dashboard:

```text
/home/lasdpc/.config/lasdpc/session.env
```

Conteudo atual esperado:

```text
DASHBOARD_URL=http://localhost:8080
MENU_URL=http://localhost:8090
```

## UX do kiosk corrigida

Problema visto: no modo dashboard, usuario entrou em link externo quebrado e ficou preso em `404 Not Found`, sem barra de navegacao.

Solucao aplicada:

- Extensao local invisivel do Chromium instalada em `/opt/lasdpc-pi-station/kiosk/escape-extension`.
- Repositorio local: `remote/kiosk/escape-extension/`.
- No dashboard/site externo:
  - `ArrowLeft` volta pagina.
  - `Esc` abre menu central.
  - `Home` volta para dashboard principal.
- No menu central, setas continuam navegando cards.

Tambem removido bookmark quebrado do Redmine em:

```text
/srv/lasdpc-pi-station/homepage/config/bookmarks.yaml
```

## Kodi

- Instalado: Kodi `21.3`, pacote `3:21.3+dfsg-1+rpt2`.
- Validado: abre em `lasdpc-mode media`, e ao sair volta para menu.
- Corrigida corrida em `lasdpc-mode` que podia matar o Kodi recem-lancado.

## Emulador / N64

RetroPie continua bloqueado corretamente: RetroPie-Setup nao suporta Debian/Raspberry Pi OS 13 Trixie.

Alternativa integrada instalada:

- `ares` instalado via apt: `ares 134+dfsg-1+b2`.
- Diretório de ROMs legais: `/srv/lasdpc-pi-station/roms/n64`.
- `lasdpc-mode games` abre `ares`.
- Override necessario para a Pi:

```sh
MESA_GL_VERSION_OVERRIDE=3.3 MESA_GLSL_VERSION_OVERRIDE=330 ares
```

Esse override foi fixado em `/usr/local/bin/lasdpc-session` e no repo em `remote/bin/lasdpc-session`.

Validado: ares abre sem erro OpenGL, fecha e retorna ao menu. Performance de Ocarina of Time ainda nao foi testada porque nenhuma ROM foi fornecida.

Copiar ROM legal:

```sh
rsync -avh --progress ./Ocarina-of-Time.z64 lasdpc@100.84.255.77:/srv/lasdpc-pi-station/roms/n64/
```

Depois abrir **Emulador** no menu e carregar pelo menu `Load` do ares.

## Alteracoes locais pendentes no Git

Ha alteracoes nao commitadas em:

- `README.md`
- `docs/*.md`
- `docs/final-report.md` novo
- `remote/bin/lasdpc-kiosk`
- `remote/bin/lasdpc-mode`
- `remote/bin/lasdpc-session`
- `remote/launcher/index.html`
- `remote/systemd/lasdpc-launcher.service`
- `remote/kiosk/escape-extension/` novo

Principais correcoes:

- `lasdpc-mode`: evita matar app-alvo recem-lancado e gerencia `ares`.
- `lasdpc-kiosk`: carrega extensao invisivel, desativa traducao, e faz fallback se `systemd-inhibit` falhar.
- `lasdpc-session`: `games` abre `ares` se nao houver EmulationStation.
- `lasdpc-launcher.service`: `StartLimitIntervalSec`/`StartLimitBurst` movidos para `[Unit]`.
- `remote/launcher/index.html`: botao `Reiniciar` usa SVG inline correto; `Jogos` virou `Emulador`.

## Pendencias

- Testar Ocarina of Time com ROM legal real no ares.
- Se ares ficar lento para N64, proxima alternativa e Mupen64Plus/Parallel mais performatico, mas os pacotes Mupen64Plus do Debian Trixie arm64 estao inconsistentes: metapacotes dependem de plugins sem candidato instalavel.
- 5 pacotes kernel/eeprom continuam upgradable por exigirem `apt full-upgrade`: `linux-headers-rpi-*`, `linux-image-rpi-*`, `rpi-eeprom`.
- Apagar no admin Tailscale o no antigo/stale `lasdpc-pi-display-01` para recuperar o nome sem sufixo.
- Nao baixar ROMs/BIOS protegidos.
