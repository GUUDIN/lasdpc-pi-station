#!/usr/bin/env python3
"""Gera a playlist N64 do RetroArch a partir das ROMs em roms/n64."""
import json, os, re, sys

# mupen64plus_next (GLideN64/GLES3, compilado para o Pi 4) roda OoT a 60 FPS;
# parallel_n64 (parallel-rdp/Vulkan) fica preso a ~13 FPS na V3D -> so fallback.
CORES = [
    (os.path.expanduser("~/.config/retroarch/cores/mupen64plus_next_libretro.so"), "Nintendo - Nintendo 64 (Mupen64Plus-Next)"),
    ("/usr/lib/aarch64-linux-gnu/libretro/mupen64plus_next_libretro.so", "Nintendo - Nintendo 64 (Mupen64Plus-Next)"),
    ("/usr/lib/aarch64-linux-gnu/libretro/parallel_n64_libretro.so", "Nintendo - Nintendo 64 (ParaLLEl N64)"),
]
core, core_name = next((c for c in CORES if os.path.isfile(c[0])), CORES[-1])
romdir = "/srv/lasdpc-pi-station/roms/n64"
plpath = os.path.expanduser("~/.config/retroarch/playlists/Nintendo - Nintendo 64.lpl")

# rotulos limpos (sem tags de regiao/versao)
labels = {
    "Legend of Zelda, The - Ocarina of Time (U) (V1.2) [!].z64": "The Legend of Zelda: Ocarina of Time",
    "Legend of Zelda, The - Majora's Mask (USA).z64": "The Legend of Zelda: Majora's Mask",
    "Mario Kart 64 (USA).z64": "Mario Kart 64",
    "Super Mario 64 (USA).z64": "Super Mario 64",
    "Super Smash Bros. (USA).z64": "Super Smash Bros.",
}

def clean_label(fn):
    """'Legend of Zelda, The - Ocarina of Time (U).z64' -> 'The Legend of Zelda: Ocarina of Time'
    (mesmo nome das thumbnails do RetroArch e do menu central)."""
    name = re.sub(r"\s*[\(\[][^\)\]]*[\)\]]", "", os.path.splitext(fn)[0]).strip()
    m = re.match(r"^(.*?), (The|A|An)( - .*)?$", name)
    if m:
        name = f"{m.group(2)} {m.group(1)}{m.group(3) or ''}"
    return name.replace(" - ", ": ", 1)

items = []
for fn in sorted(os.listdir(romdir)):
    if not fn.lower().endswith((".z64", ".n64", ".v64")):
        continue
    items.append({
        "path": os.path.join(romdir, fn),
        "label": labels.get(fn, clean_label(fn)),
        "core_path": core,
        "core_name": core_name,
        "crc32": "00000000|crc",
        "db_name": "Nintendo - Nintendo 64.lpl",
    })

pl = {
    "version": "1.5",
    "default_core_path": core,
    "default_core_name": core_name,
    "label_display_mode": 0,
    "right_thumbnail_mode": 3,
    "left_thumbnail_mode": 2,
    "items": items,
}

os.makedirs(os.path.dirname(plpath), exist_ok=True)
with open(plpath, "w") as f:
    json.dump(pl, f, indent=2, ensure_ascii=False)

print(f"playlist criada com {len(items)} jogos em {plpath}:")
for it in items:
    print("  -", it["label"])
