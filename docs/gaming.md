# Jogos e Emulacao

## Estado atual

RetroPie nao foi instalado. O preflight bloqueou corretamente a instalacao porque a Pi roda Debian/Raspberry Pi OS 13 Trixie, enquanto RetroPie-Setup ainda nao suporta essa base.

Para ter emulacao sem dual boot, foi instalado o `ares` a partir do repositorio oficial Debian. Ele e um emulador multi-sistema e inclui Nintendo 64. O modo `games` abre `ares` quando EmulationStation nao esta instalado.

Nao rode:

```sh
make retropie
```

Sem antes repetir e revisar:

```sh
make retropie-check
```

Relatorio existente:

```text
logs/retropie-preflight-20260612-130135.md
```

## Modo Games

O tile **Jogo** do menu central abre a lista de jogos (uma capa por ROM encontrada em
`/srv/lasdpc-pi-station/roms/<sistema>/`, com o core certo por sistema). Escolher um
jogo abre o RetroArch direto nele; o botao "Abrir o menu completo do RetroArch" (ou
`lasdpc-mode games` por SSH) abre o menu Ozone sem jogo.

Enquanto carrega, o overlay `lasdpc-loading` fica na tela com o nome do jogo, uma
barra animada, a etapa atual (lida do log do RetroArch pelo `lasdpc-retroarch`) e os
segundos decorridos. Ele so sai quando o RetroArch termina de inicializar; se o
RetroArch fechar antes, mostra "Nao foi possivel abrir o jogo" e volta ao menu
(log em `~/.config/lasdpc/retroarch-last.log`). Com o core N64 rapido o Zelda OoT
fica pronto em ~3 s.

- Fallbacks opt-in: `LASDPC_GAMES_FRONTEND=ares|esde` em `~/.config/lasdpc/session.env`
  (ES-DE **nao renderiza no Pi 4**, ver abaixo).
- Ao sair do RetroArch (menu F1 → Sair) ou com `Super+Esc`, volta para o menu central.

### N64: use o core mupen64plus_next (GLES3)

O `parallel_n64` do buildbot so renderiza rapido via parallel-rdp (Vulkan compute).
Na V3D do Pi 4 o Zelda OoT roda a ~13 FPS com tela preta/cinza por minutos — parece
travado. Os plugins GL dele exigem OpenGL desktop e o RetroArch desta estacao e
compilado com OpenGL ES. Solucao: `make n64-core` compila o `mupen64plus_next`
(GLideN64, `platform=rpi4_64`, ~30 min) e instala em `/usr/lib/<triplet>/libretro`.
O menu central e a playlist N64 passam a preferi-lo automaticamente (o RetroArch troca
sozinho para o driver `glcore` enquanto o jogo roda). Validado em 2026-10-01: OoT
abre em ~3 s e roda a abertura a 45-60 FPS.

### Perfis por jogo (`remote/launcher/profiles/`)

`game_profiles.py` roda a cada abertura do RetroArch e aplica:

- `n64/core.opt` — base do Mupen64Plus-Next para o Pi 4: **resolucao nativa 320x240 +
  renderizador em thread**. Benchmark sem limitador (60 = velocidade real), Zelda OoT,
  13 areas alcancadas por warp (`tools/n64-bench`):

  | Area | Padrao (640x480) | Afinado |
  |---|---|---|
  | Kakariko (pior) | 46.6 | 90.4 |
  | Desert Colossus | 48.6 | 94.0 |
  | Death Mountain Crater | 48.2 | 94.9 |
  | Lake Hylia | 50.2 | 96.6 |
  | Zora's Domain | 50.6 | 99.0 |
  | Hyrule Field | 50.3 | 100.0 |
  | Lon Lon Ranch | 51.1 | 100.1 |
  | Hyrule Castle | 52.6 | 99.9 |
  | Gerudo Valley | 52.7 | 101.8 |
  | Death Mountain Trail | 52.7 | 102.0 |
  | Market | 53.5 | 101.8 |
  | Lost Woods | 65.6 | 116.4 |
  | Temple of Time | 67.8 | 116.4 |

  O gargalo e o fill rate da V3D (640x480 → 320x240 sozinho leva Kakariko de 47 a 75) e a
  thread principal do emulador (o renderizador em thread leva de 75 a 94). Copia de
  profundidade, framebuffer, CountPerOp, memoria extra e resampler de audio nao mudaram
  o resultado alem do ruido. Visualmente quase igual na TV.
- `n64/<jogo>.opt` — ajustes do titulo, casando pelo nome interno da ROM (`# match:`),
  em qualquer ordem de bytes (.z64/.v64/.n64). O RetroArch usa o .opt do jogo *no lugar*
  do .opt do core, entao o arquivo gerado leva base + ajustes.
- `n64/keyboard.cfg` — override de teclado do core: neste core o A do N64 e o B do
  RetroPad, entao o mapeamento global deixava X = C-baixo e Z = A.

**Zelda OoT** (`ocarina-of-time.opt`): emulacao de framebuffer obrigatoria (fundo do menu
de pausa, oclusao do sol). Validado jogando por script (teclado virtual uinput): criar
save, cenas iniciais, sair da casa, Floresta Kokiri e menu de pausa, a ~60 fps. Quedas do
contador para ~45 so nas transicoes de area (o jogo para de gerar quadros, nao e lentidao).
O cache de shaders do GLideN64 (desligado em builds GLES) foi testado e nao mudou nada.

Teclado (N64): setas = analogico, X = A, Z = B, Shift = Z (trava-alvo), V = R (escudo),
I/J/K/L = botoes C, Enter = Start, F = L, F1 = menu do RetroArch. Os atalhos padrao do
RetroArch em `k`/`l`/`f`/`i` (avancar quadro, avanco rapido, fullscreen, netplay) foram
desligados: o `k` congelava o jogo ao apertar C-baixo.

Copiar ROM legal:

```sh
rsync -avh --progress ./Ocarina-of-Time.z64 lasdpc@100.84.255.77:/srv/lasdpc-pi-station/roms/n64/
```

## Etapa 4 — RetroArch + cores + ES-DE (resultado real)

Instalado por `make gaming-install` (`scripts/120-gaming-install.sh`, idempotente, destacado):

- **RetroArch 1.20.0** (apt — NAO Flatpak; mais simples e sem sandbox no Trixie).
- **Cores via apt**: `nestopia` (NES), `snes9x` (SNES), `genesis_plus_gx` (Mega Drive/Master System), `gambatte` (GB/GBC).
- **Core N64**: `parallel_n64` do buildbot oficial libretro (aarch64). `mupen64plus_next` NAO esta no buildbot aarch64.
- **ES-DE 3.4.1** AppImage AArch64 em `/opt/es-de` (sha256 fixado em `/opt/es-de/VERSION`).

Validacao automatizada: `make gaming-check` (`scripts/121-gaming-check.sh`) — **PASS**
(RetroArch + ES-DE binario + 5 cores + dirs `/srv` + N64 disponivel + >=3 GB).

### ⚠️ ES-DE NAO renderiza no Raspberry Pi 4 (incompatibilidade de GL)

Testado in-session (Wayland/labwc) e o ES-DE falha ao criar o contexto grafico:

```text
GLXBadFBConfig                 (caminho X11/XWayland)
EGL_BAD_MATCH em eglCreateContext  (caminho Wayland/EGL)
```

Causa: o AppImage oficial do ES-DE usa **OpenGL desktop 3.3**, mas o V3D do Pi 4
fornece apenas **OpenGL 3.1** (e OpenGL ES 3.1). Tentativas com `SDL_VIDEODRIVER=wayland`
e `GALLIUM_DRIVER=zink` (GL-sobre-Vulkan) nao resolveram porque o AppImage empacota a
propria stack GL. **Por isso o modo `games` usa `ares` por padrao**, e o ES-DE fica
apenas como opt-in (`LASDPC_GAMES_FRONTEND=esde`) para futura investigacao.

Caminhos para destravar o ES-DE (a validar on-screen, fora do escopo headless):

- Build do ES-DE com renderer **OpenGL ES** (nao o AppImage desktop padrao); ou
- Outro frontend que use GLES no Pi 4 (EmulationStation GLES, Pegasus); ou
- Manter `ares`/RetroArch direto como frontend.

RetroArch (apt) usa drivers `gl`/`glcore`/`vulkan` e tende a funcionar no Pi 4 — pode
ser usado diretamente (`retroarch`) como interface de jogos por gamepad enquanto o
frontend dedicado nao e resolvido.

## Alternativa recomendada

Para a imagem principal Debian/Trixie com dashboard, desktop e menu, a melhor direcao e trocar o uso direto do `ares` por um frontend de TV, preferencialmente ES-DE ou Pegasus, e deixar os emuladores por sistema como dependencias opcionais. O `ares` continua util como emulador multi-sistema instalado por apt, mas a UX dele e de aplicativo desktop, nao de console de sala.

Opcoes avaliadas:

| Opcao | Encaixe no projeto | Observacao |
| --- | --- | --- |
| ES-DE | Melhor candidato para modo `games` na imagem atual | Frontend moderno, controle por gamepad, AppImage AArch64 oficial, suporte amplo a sistemas |
| Pegasus | Alternativa leve e customizavel | Tem builds para Raspberry Pi e compatibilidade com metadados EmulationStation |
| Batocera | Melhor experiencia dedicada de retrogaming | Excelente se a estacao for de jogos, mas e outra imagem/OS |
| Recalbox | Alternativa dedicada com Kodi | Tambem exige tratar a estacao como console dedicado |
| RetroPie | Nao recomendado nesta base | Suporte Trixie ainda nao e uma base segura para esta imagem |

Para uma experiencia console dedicada, ainda e melhor usar uma unidade separada com Batocera ou Recalbox. Isso evita misturar dependencias de emulacao com o sistema principal IoT/kiosk.

Procedimento seguro:

1. Desligar a Pi.
2. Trocar para cartao/SSD dedicado de jogos.
3. Instalar Batocera/Recalbox nessa unidade separada.
4. Manter o microSD atual preservado para dashboard, IoT, Kodi e administracao.

## Limites esperados da Pi 4

Sistemas 8/16-bit e muitos consoles 32-bit tendem a funcionar bem. N64, Dreamcast, PSP e Saturn variam por jogo, emulador, resolucao e refrigeracao. Nao foi feito overclock inicial.

Para Ocarina of Time especificamente, a meta tecnica deve ser validada com ROM legal no hardware real antes de declarar suporte. A Pi 4 pode rodar N64 em alguns cenarios, mas desempenho e audio variam bastante conforme core/emulador, resolucao e driver grafico.

## Conteudo legal

Nao baixe ROMs, BIOS comerciais ou jogos protegidos. A infraestrutura so deve receber arquivos fornecidos legalmente pelo laboratorio/usuario.
