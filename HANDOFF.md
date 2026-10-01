# HANDOFF — LASDPC Pi Station

Estado salvo em 2026-06-19 (entretenimento + redesign do menu).

## Atualizacao 2026-06-24 — YouTube 1080p HW + Cast pelo celular

- `remote/bin/lasdpc-mpv`: caminho validado no Pi 4 agora e
  `--vo=dmabuf-wayland --hwdec=v4l2m2m`, forçando H.264/`avc1` ate 1080p.
  O antigo `v4l2m2m-copy` copiava frames para RAM e travava em 1080p60; o
  zero-copy estabilizou a reproducao. Ha fallback automatico para software se o
  caminho HW falhar.
- VP9/AV1 continuam impossiveis por hardware no BCM2711: o silicio do Pi 4 tem
  blocos para H.264 e H.265/HEVC, nao para VP9/AV1. YouTube acima de 1080p tende
  a exigir VP9/AV1, entao o teto realista desta estacao e 1080p H.264.
- `remote/bin/lasdpc-mode`: `kill_kodi()` robusto mata `kodi-standalone` e
  `kodi.bin` para evitar Kodi orfao vazando por tras dos modos.
- Novo modo `ytcast`: o celular pareia como YouTube TV, mas quem toca o video e
  o `mpv` acelerado por hardware. Arquivos principais:
  `remote/ytcast/index.js`, `remote/bin/lasdpc-ytcast`,
  `remote/launcher/ytcast.html`, `scripts/170-ytcast.sh`.
- Ajuste posterior: durante playback, o `lasdpc-session` mata o Chromium da tela
  ociosa `ytcast.html` para nao roubar CPU/GPU por tras do `mpv`. O perfil
  default do cast passou a ser `LASDPC_YTCAST_QUALITY=1080`: exige H.264
  >=1080p ate o teto `MAXH` (padrao 1080). Validado para a live
  `ioH5k4ss_tY`: `format=301 height=1080 fps=60 vcodec=avc1.4D402A`.
  Para voltar a priorizar fluidez/temperatura, usar
  `LASDPC_YTCAST_QUALITY=smooth`; para qualidade maxima ate `MAXH`, usar
  `LASDPC_YTCAST_QUALITY=max`.
- Validado na Pi: `lasdpc-mode ytcast` permanece estavel, Chromium abre
  `ytcast.html`, receiver Node escuta em `*:3232`, e `/api/ytcast/code` retorna
  codigo de pareamento. A sessao grafica precisou ser relancada para carregar o
  `lasdpc-session` novo.
- Correcao posterior do cast: remover `--ytdl-raw-options=...write-auto-subs...`
  do `remote/ytcast/index.js`; no mpv 0.40 do Pi ela abortava com
  `Expected '=' and a value` antes de abrir o video. Teste direto com as flags
  atuais ficou rodando ate `timeout` (`rc=124`), indicando que o mpv abriu.
- `remote/ytcast/index.js` agora registra status/log persistente em
  `~/.config/lasdpc/ytcast_status.json` e `ytcast.log`, e usa data store em
  arquivo (`ytcast_store.json`) para manter `app.pid`/MDX estaveis sem o
  `node-persist` quebrado.
- `remote/bin/lasdpc-session` relanca o receiver se o Node morrer, mata receivers
  orfaos antes de subir outro e limpa Chromium `chromium-ytcast` antigo para nao
  duplicar CPU/GPU. Isso tambem evita `DialServerError EADDRINUSE` em `*:3232`.
- Transicoes de app: novo `remote/bin/lasdpc-loading` gera uma imagem fullscreen
  e a exibe com `mpv --ontop --title="LASDPC Loading"`. `lasdpc-mode` inicia o
  loading antes de matar o app atual; `lasdpc-session` remove o loading depois
  que o app alvo foi lancado. Isso reduz/evita o desktop vazio entre menu,
  musica, dashboard, jogos, Kodi, TV e ytcast. Para o cast, o estado
  `ytcast_state=loading` tambem mostra o loading enquanto o mpv resolve/abre o
  video.
- Limite de integracao: `yt-cast-receiver` nao expoe controle de qualidade ou
  captions do app do YouTube. A API do player implementavel so cobre play,
  pause/resume, stop, seek, volume e fila. Qualidade/crop/captions precisam ser
  politica local do mpv/yt-dlp, nao controle nativo do app.
- Para diagnosticar lives HLS com imagem deslocada, o receiver aceita knobs
  opcionais via `session.env`: `LASDPC_YTCAST_VIDEO_ZOOM`,
  `LASDPC_YTCAST_VIDEO_PAN_X`, `LASDPC_YTCAST_VIDEO_PAN_Y`. Nao deixar esses
  valores ligados por padrao: o teste com `VIDEO_ZOOM=0.263034` e
  `VIDEO_PAN_Y=-0.17` piorou o enquadramento e foi revertido ao vivo
  (`video-zoom=0`, `video-pan-x=0`, `video-pan-y=0`) e removido do
  `session.env`.
- Firewall ainda nao foi alterado nesta sessao. Se o app do YouTube nao descobrir
  "TV LASDPC" automaticamente, liberar no UFW: `1900/udp` (SSDP), `3232/tcp`
  (DIAL) e, se necessario para descoberta local, `5353/udp` (mDNS). O pareamento
  manual por codigo deve funcionar pela tela `ytcast.html`.

## Atualizacao 2026-06-19 — Entretenimento completo + UX do menu

Reproduzivel via `make entertainment` (script `160-entertainment.sh`, idempotente).

### Menu redesenhado (UX)
- `remote/launcher/index.html` reescrito: 5 apps grandes (Dashboard, Video, Musica,
  Jogo, Desktop) + barra de sistema discreta (Ajustes, Como usar, Energia).
  Config (URLs dashboard / AirPlay) movida para painel "Ajustes"; energia num painel
  com confirmacao. Resolve o "tudo misturado".
- Fonte `fonts-noto-color-emoji` instalada (icones do menu renderizavam como quadrados).
- Navegacao setas/gamepad; sair de qualquer app = Super+Esc.

### Video / YouTube (modo `tv`) — mpv + yt-dlp, SEM API key
- `lasdpc-mpv` (mpv) + `lasdpc-play` + endpoints `/api/tv/{channels,search,play}` no
  `server.py`. Painel "Video" com atalhos de canais (URL oficial `@CazeTV/live` etc) +
  busca por texto (ytsearch). Tile abre o painel.
- **DECODE POR SOFTWARE** (`--hwdec=no`): o `hwdec=v4l2m2m` deste Pi/Wayland da TELA AZUL
  (mapping DRM dmabuf falha). H.264 720p por software = 0 drops (liso). 1080p60 dropa
  (~20%) — 720p e o teto fluido. Forca avc1 via yt-dlp (controle de codec que o
  navegador nao dava; o YouTube TV no Chromium ficava preso em 480p/VP9 e travado).
- `deno` instalado (yt-dlp exige JS runtime) + timer `yt-dlp-update.timer` (semanal).

### Musica / Spotify (modo `musica`)
- Raspotify renomeado para **"TV LASDPC"**. Modo `musica` abre tela de espera
  `musica.html` (Chromium kiosk) com instrucoes; audio sai pelo HDMI via Spotify Connect.

### Jogo / Zelda OoT (modo `games`) — RetroArch, NAO Ship of Harkinian
- **SoH abandonado** (build falhou 2x + so roda OoT). OoT roda no **RetroArch** via
  `parallel_n64` + **parallel-rdp (Vulkan)** — renderiza perfeito (Vulkan funciona; o GL/
  v4l2 nao). `lasdpc-retroarch-setup.sh` configura: Vulkan/Ozone, fullscreen, playlist N64
  (5 jogos) + thumbnails, e CONTROLE de teclado jogavel: movimento no ANALOGICO (setas),
  A=X B=Z Start=Enter trava-alvo=Shift; `input_exit_emulator=nul` (sai so via Super+Esc).
- N64 generico (ares/mupen/GLideN64) NAO funciona no Pi4 (exige OpenGL desktop). Vulkan
  (parallel-rdp) e o caminho.

### Limites de hardware confirmados (Pi 4)
- Sem decode HW de VP9/AV1; H.264 ate 1080p (mas 1080p60 dropa). Video fluido = 720p.
- N64: so via Vulkan/parallel-rdp. Emuladores GL desktop falham.
- `hwdec=v4l2m2m` no mpv = tela azul; usar software decode.

---

## Atualizacao 2026-06-13 (estado anterior) — Etapas 2/5/6 em progresso

## Atualizacao 2026-06-13 — Etapas 2/5/6 em progresso

### Etapa 2 — UxPlay video corrigido

- `lasdpc-uxplay`: `UXPLAY_VIDEO_SINK` era `0` (audio-only per docs). Corrigido para `waylandsink`.
- UxPlay agora usa: `-vs waylandsink -fs -s 1920x1080@60 -nc`.
- TC-2.x AirPlay video: MANUAL-PENDENTE (exige device Apple fisico).

### Etapa 5 — Ship of Harkinian (OoT port)

- Script: `remote/bin/lasdpc-soh-build.sh` — clone + cmake + ninja + install `/opt/soh/soh.elf`.
- Deps descobertas iterativamente: `libsdl2-net-dev` adicionado (cmake falhou sem ela).
- cmake fix: `-Dnlohmann_json_DIR=/usr/share/cmake/nlohmann_json` (path fora do search default).
- Build iniciado 2026-06-13 ~09:57; cmake configurado em 217s; ninja compilando 1635 targets.
- **Build a correr agora** — NAO reiniciar a Pi enquanto o build nao terminar.
- Apos build: testar `/opt/soh/soh.elf`; usuario deve copiar ROM legal de OoT para
  `/srv/lasdpc-pi-station/roms/n64/` antes do primeiro uso.

### Etapa 6 — Operacionalizacao

- **Tile "Como usar"** (helpPanel): confirmado visualmente no screenshot 2026-06-13.
  Grid 3x3 completa: IoT / Dashboards / Midia / YouTube / Emulador / Desktop / Como usar / Reiniciar / Desligar.
- **Backup diario**: `lasdpc-backup.service` + `lasdpc-backup.timer` deployados e ativos.
  Proximo disparo: 2026-06-14 03:04 (3h da manha + randomized 10 min). Retem 7 dias.
- **Reboot final**: CONCLUIDO (2026-06-13 ~14:00).
  - throttled=0x0, 0 failed units, 5/5 Docker healthy, temp 57.9°C.
  - Bug descoberto: Chromium pedia unlock gnome-keyring a cada reboot.
    Fix: `--password-store=basic` em `lasdpc-kiosk`. Launcher confirmado sem dialog.

## Atualizacao 2026-06-13 — Etapa 4 CONCLUIDA (gaming fullscreen confirmado)

- `make gaming-install` + `make gaming-check` (scripts 120/121): **AUTO PASS**.
  Instalados: RetroArch 1.20 (apt) + cores apt (nestopia/snes9x/genesis_plus_gx/gambatte)
  - `parallel_n64` (buildbot, N64) + ES-DE 3.4.1 AppImage (`/opt/es-de`).
- **ES-DE NAO renderiza no Pi 4**: exige OpenGL desktop 3.3, o V3D entrega 3.1
  (GLXBadFBConfig / EGL_BAD_MATCH). `SDL_VIDEODRIVER=wayland` e `GALLIUM_DRIVER=zink`
  nao resolvem (AppImage empacota a stack GL). Detalhes em `docs/gaming.md`.
- Por isso `lasdpc-mode games` usa **ares** por padrao; ES-DE so via
  `LASDPC_GAMES_FRONTEND=esde` (opt-in). `lasdpc-mode` ganhou `kill_esde()`.
- **TC-4.4 CONFIRMADO** (screenshot grim 2026-06-13): ares v134 abre fullscreen
  1920x1080 sem decoracoes. Requer `GDK_BACKEND=wayland` + regra `ToggleFullscreen`
  no labwc (`/etc/xdg/labwc/rc.xml`, rastreado em `remote/kiosk/labwc-rc.xml`).
- `lasdpc-mode` ganhou `kill_ares()` (SIGTERM + SIGKILL fallback; ares ignorava SIGTERM).
- **MANUAL-PENDENTE**: gamepad + ROM real + desempenho N64 (TC-4.5 a 4.8).
- Commits: `2f83b08`, `9ddb5e6`, `45dd609`, `b88e9b8` (fullscreen).

Proximas frentes: Etapa 2 (AirPlay video), Etapa 5 (Ship of Harkinian),
Etapa 6 (operacionalizacao).

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
| --- | --- |
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
