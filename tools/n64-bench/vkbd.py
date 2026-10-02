#!/usr/bin/env python3
"""Teclado virtual uinput (roda como root). Le comandos do FIFO: 'tap KEY_X' / 'hold KEY_X ms'."""
import sys, time
from evdev import UInput, ecodes as e
keys = [getattr(e, n) for n in dir(e) if n.startswith("KEY_")]
ui = UInput({e.EV_KEY: list(set(k for k in keys if isinstance(k, int) and k < 0x2ff))}, name="lasdpc-bench-kbd")
time.sleep(1.0)
for line in open(sys.argv[1]):
    parts = line.split()
    if not parts: continue
    if parts[0] == "quit": break
    k = getattr(e, parts[1]); ms = int(parts[2]) if len(parts) > 2 else 100
    ui.write(e.EV_KEY, k, 1); ui.syn(); time.sleep(ms / 1000)
    ui.write(e.EV_KEY, k, 0); ui.syn(); time.sleep(0.08)
ui.close()
