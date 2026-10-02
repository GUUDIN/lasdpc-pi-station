#!/usr/bin/env python3
"""bench.py NOME QUADROS [chave=valor ...] -> fps de emulacao SEM limitador (60 = velocidade real).
Base: profiles/n64/core.opt; chaves mupen64plus-* viram opcoes do core, as demais vao para o
retroarch.cfg. AUTOLOAD=true carrega states/ (ver area.sh). NAO use --max-frames-ss: o
screenshot do RetroArch derruba o renderizador em thread durante a rodada inteira (~50%)."""
import os, re, subprocess, sys, time, shutil
B = os.path.dirname(os.path.abspath(__file__))
name, frames, kvs = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
CORE = "/usr/lib/aarch64-linux-gnu/libretro/mupen64plus_next_libretro.so"
ROM = "/srv/lasdpc-pi-station/roms/n64/Legend of Zelda, The - Ocarina of Time.z64"
opt = open(os.path.join(B, "..", "..", "remote", "launcher", "profiles", "n64", "core.opt")).read()
cfg_extra = []
for kv in kvs:
    k, v = kv.split("=", 1)
    if k.startswith("mupen64plus-"):
        if re.search(rf'^{re.escape(k)} = ', opt, re.M):
            opt = re.sub(rf'^{re.escape(k)} = .*$', f'{k} = "{v}"', opt, flags=re.M)
        else:
            opt += f'{k} = "{v}"\n'
    else:
        cfg_extra.append(f'{k} = "{v}"')
optp = os.path.join(B, f"{name}.opt"); open(optp, "w").write(opt)
cfgp = os.path.join(B, f"{name}.cfg")
open(cfgp, "w").write("\n".join([
    f'core_options_path = "{optp}"', 'game_specific_options = "false"', 'global_core_options = "true"',
    'savestate_auto_load = "' + os.environ.get('AUTOLOAD', 'false') + '"', 'savestate_auto_save = "false"',
    f'savestate_directory = "{B}/states"', f'savefile_directory = "{B}/saves"', 'video_vsync = "false"',
    'audio_sync = "false"', 'fps_show = "false"', 'menu_show_load_content_animation = "false"',
    'video_frame_delay = "0"', 'config_save_on_exit = "false"', *cfg_extra]) + "\n")
env = dict(os.environ, XDG_RUNTIME_DIR=f"/run/user/{os.getuid()}", WAYLAND_DISPLAY="wayland-0")
ss = os.path.join(B, f"{name}.png")
p = subprocess.Popen(["retroarch", "--verbose", f"--appendconfig={cfgp}", f"--max-frames={frames}",
                      "-L", CORE, ROM],
                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
t0 = time.time(); ts = None; log = []
for line in p.stdout:
    log.append(line)
    if ts is None and "Loading favourites file" in line:
        ts = time.time()
p.wait(); te = time.time()
open(os.path.join(B, f"{name}.log"), "w").writelines(log)
if ts is None:
    print(f"{name}: FALHOU (rc={p.returncode})"); sys.exit(1)
print(f"{name}: {frames} quadros em {te-ts:.1f}s -> {frames/(te-ts):.1f} fps  (init {ts-t0:.1f}s)")
