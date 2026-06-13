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

O menu contem a entrada `Emulador`:

```sh
lasdpc-mode games
```

Comportamento (atualizado na Etapa 4):

1. Por padrao abre `ares` (multi-sistema, inclui N64).
2. ES-DE so e usado se `LASDPC_GAMES_FRONTEND=esde` em `~/.config/lasdpc/session.env`
   — ver abaixo: o AppImage oficial do ES-DE **nao renderiza no Pi 4**.
3. Se `emulationstation` existir, e usado como ultimo fallback.
4. Ao sair do emulador, volta automaticamente para `menu`.

> **Validacao on-screen do modo `games` (ares/ES-DE) e MANUAL-PENDENTE** — exige
> operador no lab com TV+gamepad. Os TCs automatizados (instalacao/presenca) passam.

Diretorio criado para ROMs legais de N64:

```text
/srv/lasdpc-pi-station/roms/n64
```

Para copiar sua ROM legal de Ocarina of Time:

```sh
rsync -avh --progress ./Ocarina-of-Time.z64 lasdpc@100.84.255.77:/srv/lasdpc-pi-station/roms/n64/
```

Depois abra `Emulador` no menu e carregue o arquivo pelo ares.

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
|---|---|---|
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
