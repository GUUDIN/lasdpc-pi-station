# n64-bench — medir desempenho N64 por area, sem jogar

Ferramentas usadas para afinar o Zelda OoT (ver `docs/gaming.md`). Rodam na Pi, na sessao grafica.

- `bench.py NOME QUADROS [chave=valor...]` — roda o jogo **sem limitador** e mede fps de
  emulacao (60 = velocidade real; acima disso e folga). Base = `profiles/n64/core.opt`.
  `AUTOLOAD=true` comeca do estado em `states/`.
- `play.py NOME OPT ROTEIRO` — velocidade real + roteiro de teclas (`tap`, `hold`, `shot`)
  via teclado virtual uinput (`vkbd.py`, precisa de `python3-evdev` e sudo).
- `ram.py` — extrai a RDRAM de um savestate RZIP do Mupen64Plus-Next.
- `warp.py ORIGEM ENTRADA DESTINO` — **OoT NTSC 1.2**: grava `nextEntranceIndex` e
  `transitionTrigger=0x14` no PlayState (0x801C8D60) de um savestate; ao carregar, o jogo
  faz a transicao sozinho. IDs de entrada: tabela do decomp zeldaret/oot
  (`include/tables/entrance_table.h`), ex.: 0x0DB Kakariko, 0x0CD Hyrule Field.
- `area.sh NOME ENTRADA` — warp a partir de `states.forest/`, espera a cena e salva
  `states.NOME/`.

- `lat.py NOME [chave=valor]` — latencia em **quadros** com o jogo pausado (comando de rede
  do RetroArch + avanco quadro a quadro): quando o Link muda na RAM e quando a tela muda.
  Nao enxerga filas que so existem em tempo real.
- `rtlat.py NOME [chave=valor]` — latencia **em tempo real** (ms): segura Shift (Z-target) e
  cronometra ate as faixas pretas aparecerem na tela composta (wf-recorder numa regiao).
  Subtraia ~160 ms da captura (`calib.py`) e ~29 quadros (~480 ms) do proprio Z-target.
- `calib.py` — mede o atraso fixo da captura fechando a janela num instante conhecido.

Estados e capturas nao sao versionados (contem a RAM do jogo). Para comecar: crie um save
com `play.py` + `AUTOSAVE=true` ate ter o Link controlavel e copie `states/` para
`states.forest/`.

**Armadilha:** nao use `--max-frames-ss` no RetroArch — o screenshot final derruba o
renderizador em thread durante a rodada inteira e subestima tudo em ~50%.
