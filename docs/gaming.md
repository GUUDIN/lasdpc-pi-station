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

Comportamento:

1. Se `emulationstation` existir, abre EmulationStation.
2. Caso contrario, abre `ares`.
3. Ao sair do emulador, volta automaticamente para `menu`.

Diretorio criado para ROMs legais de N64:

```text
/srv/lasdpc-pi-station/roms/n64
```

Para copiar sua ROM legal de Ocarina of Time:

```sh
rsync -avh --progress ./Ocarina-of-Time.z64 lasdpc@100.84.255.77:/srv/lasdpc-pi-station/roms/n64/
```

Depois abra `Emulador` no menu e carregue o arquivo pelo ares.

## Alternativa recomendada

Para uma experiencia console dedicada, ainda e melhor usar uma unidade separada com Batocera ou Recalbox. Isso evita misturar dependencias de emulacao com o sistema principal IoT/kiosk.

Procedimento seguro:

1. Desligar a Pi.
2. Trocar para cartao/SSD dedicado de jogos.
3. Instalar Batocera/Recalbox nessa unidade separada.
4. Manter o microSD atual preservado para dashboard, IoT, Kodi e administracao.

## Limites esperados da Pi 4

Sistemas 8/16-bit e muitos consoles 32-bit tendem a funcionar bem. N64, Dreamcast, PSP e Saturn variam por jogo, emulador, resolucao e refrigeracao. Nao foi feito overclock inicial.

## Conteudo legal

Nao baixe ROMs, BIOS comerciais ou jogos protegidos. A infraestrutura so deve receber arquivos fornecidos legalmente pelo laboratorio/usuario.
