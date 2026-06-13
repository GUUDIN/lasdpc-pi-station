# Etapa 3 — YouTube na TV — checks automatizados

Data: 2026-06-13

## Implementado

- Novo modo `lasdpc-mode youtube`.
- Novo launcher `/usr/local/bin/lasdpc-youtube` versionado em `remote/bin/lasdpc-youtube`.
- Chromium kiosk em `https://www.youtube.com/tv`.
- Perfil dedicado: `~/.config/lasdpc/chromium-youtube-tv`.
- User-agent configurável por `YOUTUBE_TV_UA` em `~/.config/lasdpc/session.env`.
- Tile `YouTube na TV` no menu central.
- Retorno para `menu` mata o perfil Chromium dedicado sem deixar órfãos.

## Checks automatizados

`make youtube-check` retornou exit 0 com:

- TC-3.1-profile PASS: Chromium abriu com `--user-data-dir=.../chromium-youtube-tv`.
- TC-3.1-url PASS: processo abriu `https://www.youtube.com/tv`.
- TC-3.7-ua PASS: `--user-agent=` aplicado.
- TC-3.6 PASS: `lasdpc-mode menu` remove processos do perfil YouTube.
- TC-3.6-menu PASS: menu local `localhost:8090` responde apos sair.

## Pendências manuais

- TC-3.2: Android YouTube app -> conectar com código de TV -> reproduzir video.
- TC-3.3: iPhone YouTube app -> conectar com código de TV -> reproduzir video.
- TC-3.4: controlar play/pause/seek/fila por 5 min.
- TC-3.5: monitorar temperatura/throttling durante video 1080p.

## Observação

Isto não implementa Chromecast/Google Cast nativo. O caminho suportado para Android YouTube é pareamento por código no YouTube TV.
