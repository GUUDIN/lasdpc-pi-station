#!/usr/bin/env python3
"""Baixa thumbnails (boxart/title/snap) dos jogos N64 do repo libretro
e salva com o nome que casa com o label da playlist do RetroArch."""
import os, sys, urllib.parse, urllib.request

BASE = "https://thumbnails.libretro.com/Nintendo%20-%20Nintendo%2064"
THUMBDIR = os.path.expanduser("~/.config/retroarch/thumbnails/Nintendo - Nintendo 64")

# label da playlist  ->  candidatos de nome No-Intro no repo libretro
GAMES = {
    "The Legend of Zelda: Ocarina of Time": [
        "Legend of Zelda, The - Ocarina of Time (USA)",
        "Legend of Zelda, The - Ocarina of Time (USA) (Rev 2)",
        "Legend of Zelda, The - Ocarina of Time (USA) (Rev 1)",
    ],
    "The Legend of Zelda: Majora's Mask": [
        "Legend of Zelda, The - Majora's Mask (USA)",
    ],
    "Mario Kart 64": ["Mario Kart 64 (USA)"],
    "Super Mario 64": ["Super Mario 64 (USA)"],
    "Super Smash Bros.": ["Super Smash Bros. (USA)"],
}

# o RetroArch troca caracteres invalidos de filename por "_"
def sanitize(label):
    for ch in '&*/:`<>?\\|':
        label = label.replace(ch, "_")
    return label

TYPES = ["Named_Boxarts", "Named_Titles", "Named_Snaps"]

def try_download(url, dest):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=20) as r:
            if r.status == 200:
                data = r.read()
                if len(data) > 1000:  # nao salvar paginas de erro
                    with open(dest, "wb") as f:
                        f.write(data)
                    return True
    except Exception:
        pass
    return False

total = 0
for label, candidates in GAMES.items():
    fname = sanitize(label) + ".png"
    for ttype in TYPES:
        os.makedirs(os.path.join(THUMBDIR, ttype), exist_ok=True)
        dest = os.path.join(THUMBDIR, ttype, fname)
        got = False
        for cand in candidates:
            url = f"{BASE}/{ttype}/{urllib.parse.quote(cand)}.png"
            if try_download(url, dest):
                got = True
                total += 1
                print(f"  OK {ttype}: {label}")
                break
        if not got:
            print(f"  -- {ttype}: {label} (nao encontrado)")

print(f"\n{total} thumbnails baixadas em {THUMBDIR}")
