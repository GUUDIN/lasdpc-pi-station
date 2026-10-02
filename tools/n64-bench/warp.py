#!/usr/bin/env python3
"""warp.py ORIGEM.state ENTRADA DESTINO.state
Copia um savestate do OoT NTSC 1.2 pedindo ao jogo um warp para ENTRADA (hex, tabela
do decomp zeldaret/oot): PlayState(0x801C8D60).nextEntranceIndex(+0x11E1A) = ENTRADA e
.transitionTrigger(+0x11E15) = 0x14 (TRANS_TRIGGER_START). No 1o quadro apos carregar,
o proprio jogo faz a transicao, como numa porta."""
import sys, ram
PLAY = 0x801C8D60
def put8(raw, base, addr, val):
    off = base + ((addr & 0x7FFFFF) ^ 3)   # RDRAM em palavras host-endian
    raw[off] = val
src, entr, dst = sys.argv[1], int(sys.argv[2], 16), sys.argv[3]
rawb, base, m = ram.rdram(src)
raw = bytearray(rawb)
a = PLAY + 0x11E1A
put8(raw, base, a, entr >> 8); put8(raw, base, a + 1, entr & 0xFF)
put8(raw, base, PLAY + 0x11E15, 0x14)
open(dst, "wb").write(raw)   # RetroArch aceita estado sem RZIP
print(f"warp -> 0x{entr:03X}: {dst}")
