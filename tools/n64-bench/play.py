#!/usr/bin/env python3
"""play.py NAME OPTFILE SCRIPT -> roda OoT em velocidade real e executa um roteiro de teclas.
Roteiro: linhas 't acao', acao = 'tap k[,k]' | 'hold k ms' | 'shot nome' | 'quit'."""
import os, subprocess, sys, time
B = os.path.dirname(os.path.abspath(__file__))
name, optp, script = sys.argv[1], os.path.abspath(sys.argv[2]), open(sys.argv[3]).read().splitlines()
CORE = os.environ.get("CORE", "/usr/lib/aarch64-linux-gnu/libretro/mupen64plus_next_libretro.so")
ROM = "/srv/lasdpc-pi-station/roms/n64/Legend of Zelda, The - Ocarina of Time.z64"
cfgp = os.path.join(B, f"{name}.cfg")
open(cfgp, "w").write("\n".join([
    f'core_options_path = "{optp}"', 'game_specific_options = "false"', 'global_core_options = "true"',
    'savestate_auto_load = "' + os.environ.get('AUTOLOAD','false') + '"', 'savestate_auto_save = "' + os.environ.get('AUTOSAVE','false') + '"', 'fps_show = "true"',
    f'savefile_directory = "{B}/saves"', f'savestate_directory = "{B}/states"',
    'config_save_on_exit = "false"', 'menu_show_load_content_animation = "false"', *[l for l in os.environ.get('RA_EXTRA','').split(';') if l]]) + "\n")
env = dict(os.environ, XDG_RUNTIME_DIR=f"/run/user/{os.getuid()}", WAYLAND_DISPLAY="wayland-0")
log = open(os.path.join(B, f"{name}.log"), "w")
p = subprocess.Popen(["retroarch", "--verbose", f"--appendconfig={cfgp}", "-L", CORE, ROM],
                     stdout=log, stderr=subprocess.STDOUT, env=env)
fifo = os.path.join(B, "kbd.fifo")
if not os.path.exists(fifo): os.mkfifo(fifo)
kbd = subprocess.Popen(["sudo", "python3", os.path.join(B, "vkbd.py"), fifo])
kf = open(fifo, "w", buffering=1)
KEYS = {"Return": "KEY_ENTER", "x": "KEY_X", "z": "KEY_Z", "Up": "KEY_UP", "Down": "KEY_DOWN",
        "Left": "KEY_LEFT", "Right": "KEY_RIGHT", "Shift_L": "KEY_LEFTSHIFT", "F1": "KEY_F1", "k": "KEY_K", "i": "KEY_I", "j": "KEY_J", "l": "KEY_L"}
t0 = time.time()
for line in script:
    line = line.split("#")[0].strip()
    if not line: continue
    t, act, *args = line.split()
    while time.time() - t0 < float(t): time.sleep(0.02)
    if act == "tap":
        for k in args[0].split(","):
            kf.write(f"tap {KEYS.get(k, k)} 100\n"); time.sleep(0.2)
    elif act == "hold":
        kf.write(f"tap {KEYS.get(args[0], args[0])} {args[1]}\n"); time.sleep(int(args[1]) / 1000 + 0.1)
    elif act == "shot":
        subprocess.run(["grim", "-s", "0.5", os.path.join(B, "shots", f"{name}-{args[0]}.png")], env=env)
        print(f"{time.time()-t0:6.1f}s shot {args[0]}", flush=True)
    elif act == "quit":
        break
kf.write("quit\n"); kf.close(); kbd.wait()
subprocess.run(["pkill", "-INT", "-x", "retroarch"])
p.terminate() if p.poll() is None and time.sleep(3) is None and p.poll() is None else None
try: p.wait(5)
except subprocess.TimeoutExpired: p.kill()
