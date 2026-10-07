# yt-bench — testar o YouTube TV da estacao

`ytprobe.py NOME VIDEO_ID [SEGUNDOS] [--ytads] [--sem-ubol]` abre o YouTube TV como o
`lasdpc-youtube` (perfil temporario, DevTools na porta 9222), entra como convidado com o
teclado virtual uinput (`../n64-bench/vkbd.py`) e amostra o `<video>`: duracao do que toca
(anuncio = curto), resolucao e quadros perdidos. `GPUFLAGS="..."` testa flags extras.
Para ver se o decoder de hardware esta em uso durante a reproducao:
`sudo ls -l /proc/<pid do chromium>/fd | grep /dev/video10`.
