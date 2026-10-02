#!/usr/bin/env python3
"""Aplica os perfis de desempenho/controle dos jogos no RetroArch.

Roda a cada abertura do RetroArch (lasdpc-retroarch), entao ROM nova ganha o
perfil sozinha. Para N64 (core Mupen64Plus-Next):
  - profiles/n64/core.opt     -> opcoes do core para todos os jogos N64
  - profiles/n64/<jogo>.opt   -> ajustes do titulo; casa pelo nome interno no
    cabecalho da ROM ("# match: TEXTO"), nao pelo nome do arquivo
  - profiles/n64/keyboard.cfg -> override de teclado do core

O RetroArch usa o arquivo de opcoes do jogo NO LUGAR do arquivo do core, por isso
o .opt de cada jogo leva a base + os ajustes do titulo. As chaves dos perfis sao
reaplicadas a cada abertura; as demais opcoes (ajustadas no menu) sao mantidas.
"""
import os, re

HERE = os.path.dirname(os.path.abspath(__file__))
PROFILES = os.path.join(HERE, "profiles", "n64")
ROMDIR = "/srv/lasdpc-pi-station/roms/n64"
CORE_CFG_DIR = os.path.expanduser("~/.config/retroarch/config/Mupen64Plus-Next")
LINE = re.compile(r'^\s*([A-Za-z0-9_-]+)\s*=\s*"(.*)"\s*$')


def read_kv(path):
    out = {}
    try:
        with open(path) as f:
            for line in f:
                m = LINE.match(line)
                if m:
                    out[m.group(1)] = m.group(2)
    except FileNotFoundError:
        pass
    return out


def merge_write(path, values):
    """Atualiza so as chaves dadas, preservando o resto do arquivo."""
    current = read_kv(path)
    if all(current.get(k) == v for k, v in values.items()):
        return False
    current.update(values)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        for k in sorted(current):
            f.write(f'{k} = "{current[k]}"\n')
    os.replace(tmp, path)
    return True


def rom_name(path):
    """Nome interno (cabecalho 0x20..0x33) em qualquer ordem de bytes (.z64/.v64/.n64)."""
    with open(path, "rb") as f:
        head = f.read(0x40)
    if len(head) < 0x40:
        return ""
    magic = head[:4]
    if magic == b"\x37\x80\x40\x12":  # .v64: pares de bytes trocados
        head = bytes(b for i in range(0, 0x40, 2) for b in (head[i + 1], head[i]))
    elif magic == b"\x40\x12\x37\x80":  # .n64: little-endian 32 bits
        head = b"".join(head[i:i + 4][::-1] for i in range(0, 0x40, 4))
    return head[0x20:0x34].decode("ascii", "replace").strip().upper()


def game_profiles():
    profiles = []
    for fn in sorted(os.listdir(PROFILES)):
        if not fn.endswith(".opt") or fn == "core.opt":
            continue
        path = os.path.join(PROFILES, fn)
        with open(path) as f:
            m = re.search(r"^#\s*match:\s*(.+)$", f.read(), re.M)
        if m:
            profiles.append((m.group(1).strip().upper(), fn, read_kv(path)))
    return profiles


def main():
    if not os.path.isdir(PROFILES):
        return
    base = read_kv(os.path.join(PROFILES, "core.opt"))
    changed = []
    if merge_write(os.path.join(CORE_CFG_DIR, "Mupen64Plus-Next.opt"), base):
        changed.append("core")
    kb = read_kv(os.path.join(PROFILES, "keyboard.cfg"))
    if kb and merge_write(os.path.join(CORE_CFG_DIR, "Mupen64Plus-Next.cfg"), kb):
        changed.append("teclado")
    profiles = game_profiles()
    if os.path.isdir(ROMDIR):
        for fn in sorted(os.listdir(ROMDIR)):
            if not fn.lower().endswith((".z64", ".v64", ".n64")):
                continue
            name = rom_name(os.path.join(ROMDIR, fn))
            for match, pfile, values in profiles:
                if match in name:
                    target = os.path.join(CORE_CFG_DIR, os.path.splitext(fn)[0] + ".opt")
                    if merge_write(target, {**base, **values}):
                        changed.append(f"{fn} <- {pfile}")
                    break
    for c in changed:
        print("perfil aplicado:", c)


if __name__ == "__main__":
    main()
