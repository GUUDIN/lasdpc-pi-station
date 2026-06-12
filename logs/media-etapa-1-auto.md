# Etapa 1 — Perfil media audio — TCs automatizados

Data: 2026-06-12

## Instalação

`make media-install` executado com sucesso em duas rodadas idempotentes após correções de compatibilidade. Pacotes na Pi:

- `uxplay` via Debian Trixie: 1.71.1-1
- `avahi-daemon`/`avahi-utils`: 0.8-16
- `raspotify`: 0.48.1~librespot.v0.8.0-ea81314, .deb arm64 oficial validado por SHA256

## Checks automatizados

`make media-check` retornou exit 0 com:

- TC-1.2 PASS: `raspotify` ativo.
- TC-1.3 PASS: anúncios mDNS `_spotify-connect._tcp` e `_raop._tcp` com `TV LASDPC`.
- TC-1.4 PASS: `lasdpc-media.target` e `uxplay.service` ativos após `lasdpc-mode media`.
- TC-1.5 PASS: `uxplay.service` inativo após retorno para `lasdpc-mode menu`.
- TC-1.6 PASS: journal do UxPlay sem erros fatais.

## Decisão técnica

UxPlay usa `UXPLAY_VIDEO_SINK=0` por padrão nesta etapa. Isso valida AirPlay áudio e evita a falha observada com `waylandsink` (`dnssd_register_raop failed`). A validação de vídeo/Wayland fica para a Etapa 2.

## Pendências

- TC-1.7 MANUAL: operador testar AirPlay de música por 5 min.
- TC-1.8 MANUAL: operador testar Spotify Connect por 5 min com conta Premium.
- TC-1.9 AUTO: reboot e repetição de Raspotify/mDNS após boot.

## TC-1.9 pós-reboot

Após `sudo systemctl reboot`, a Pi voltou via Tailscale e os checks passaram:

- `raspotify`: active.
- `_spotify-connect._tcp`: anunciado como `TV LASDPC lasdpc-pi-display-01`.
- `lasdpc-mode media`: `lasdpc-media.target` active e `uxplay.service` active.
- `_raop._tcp`: anunciado como `D83ADD11113F@TV LASDPC lasdpc-pi-display-01`.
- `lasdpc-mode menu`: `uxplay.service` volta para inactive.
- Docker IoT: 5/5 healthy após estabilização.
- Menu: HTTP 200.
- Tailscale: conectado.
- Throttling: `throttled=0x0`.
- Temperatura pós-check: 64.7 C.

TC-1.9: PASS.

Pendências restantes da Etapa 1:

- TC-1.7 MANUAL: AirPlay de música por 5 min.
- TC-1.8 MANUAL: Spotify Connect por 5 min com conta Premium.
