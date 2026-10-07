#!/usr/bin/env bash
# area.sh NOME ENTRADA -> warp a partir da floresta, espera a cena, salva estado em states.NOME
set -e; cd "$(dirname "$0")"
N="$1"; E="$2"; S="Mupen64Plus-Next/Legend of Zelda, The - Ocarina of Time.state.auto"
rm -rf states && mkdir -p states/Mupen64Plus-Next
python3 warp.py "states.forest/$S" "$E" "states/$S" >/dev/null
printf '9 shot arrive\n10 quit\n' > area.txt
# copia: o RetroArch reescreve o arquivo de opcoes ao fechar (nunca passe o do repo)
cp ../../remote/launcher/profiles/n64/core.opt area.opt
AUTOLOAD=true AUTOSAVE=true RA_EXTRA="$(cat keys.txt)" ./play.py "area-$N" area.opt area.txt >/dev/null
rm -rf "states.$N" && cp -r states "states.$N"
