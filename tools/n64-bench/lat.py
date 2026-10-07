#!/usr/bin/env python3
"""lat.py NOME [chave=valor ...] -> latencia de entrada do Zelda OoT 1.2, em quadros.

Carrega states/ (AUTOLOAD), pausa pelo comando de rede do RetroArch, segura uma tecla
(teclado virtual uinput) e avanca quadro a quadro:
  mem  = quadros ate o Link (ator 0x801DB2F0) mudar de rotacao/posicao na RAM
         (entrada lida + logica do jogo)
  tela = quadros ate a imagem que o RetroArch apresenta mudar
         (+ pipeline de video: GLideN64, renderizador em thread)
O que vem depois do RetroArch (swapchain, compositor, TV) nao aparece aqui: some
video_max_swapchain_images-1 quadros + ~1 do compositor.
Repete TRIALS vezes, deslocando a fase (OoT atualiza a logica a cada 3 quadros VI)."""
import os, socket, subprocess, sys, time, glob, struct, re
from PIL import Image, ImageChops

B = os.path.dirname(os.path.abspath(__file__))
name, kvs = sys.argv[1], sys.argv[2:]
TRIALS = int(os.environ.get("TRIALS", "6"))
KEY = os.environ.get("KEY", "KEY_RIGHT")
MAXF = int(os.environ.get("MAXF", "20"))
LINK = 0x801DB2F0
CORE = "/usr/lib/aarch64-linux-gnu/libretro/mupen64plus_next_libretro.so"
ROM = "/srv/lasdpc-pi-station/roms/n64/Legend of Zelda, The - Ocarina of Time.z64"

opt = open(os.path.join(B, "..", "..", "remote", "launcher", "profiles", "n64", "core.opt")).read()
extra = []
for kv in kvs:
    k, v = kv.split("=", 1)
    if k.startswith("mupen64plus-"):
        opt = re.sub(rf'^{re.escape(k)} = .*$', f'{k} = "{v}"', opt, flags=re.M) if re.search(rf'^{re.escape(k)} = ', opt, re.M) else opt + f'{k} = "{v}"\n'
    else:
        extra.append(f'{k} = "{v}"')
optp = os.path.join(B, f"{name}.opt"); open(optp, "w").write(opt)
shots = os.path.join(B, "shots", f"lat-{name}"); os.makedirs(shots, exist_ok=True)
for f in glob.glob(os.path.join(shots, "*")): os.remove(f)
cfgp = os.path.join(B, f"{name}.cfg")
keys = [l for l in open(os.path.join(B, "keys.txt")).read().strip().split(";") if l]
open(cfgp, "w").write("\n".join([
    f'core_options_path = "{optp}"', 'game_specific_options = "false"', 'global_core_options = "true"',
    'savestate_auto_load = "true"', 'savestate_auto_save = "false"',
    f'savestate_directory = "{B}/states"', f'savefile_directory = "{B}/saves"',
    'network_cmd_enable = "true"', 'network_cmd_port = "55355"', 'pause_nonactive = "false"',
    f'screenshot_directory = "{shots}"', 'savestate_thumbnail_enable = "false"',
    'fps_show = "false"', 'config_save_on_exit = "false"', 'menu_show_load_content_animation = "false"',
    *keys, *extra]) + "\n")

env = dict(os.environ, XDG_RUNTIME_DIR=f"/run/user/{os.getuid()}", WAYLAND_DISPLAY="wayland-0")
log = open(os.path.join(B, f"lat-{name}.log"), "w")
ra = subprocess.Popen(["retroarch", "--verbose", f"--appendconfig={cfgp}", "-L", CORE, ROM],
                      stdout=log, stderr=subprocess.STDOUT, env=env)
fifo = os.path.join(B, "kbd.fifo")
if not os.path.exists(fifo): os.mkfifo(fifo)
kbd = subprocess.Popen(["sudo", "python3", os.path.join(B, "vkbd.py"), fifo, "hold"])
kf = open(fifo, "w", buffering=1)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); sock.settimeout(2)
def cmd(c, reply=False):
    sock.sendto(c.encode(), ("127.0.0.1", 55355))
    if reply:
        return sock.recvfrom(4096)[0].decode().strip()

def read_mem(addr, n):
    """Le n bytes big-endian do N64 (RDRAM guardada em palavras host-endian)."""
    a0 = addr & ~3; n4 = ((addr + n + 3) & ~3) - a0
    r = cmd(f"READ_CORE_MEMORY {a0:x} {n4}", True).split()
    host = bytes(int(x, 16) for x in r[2:])
    be = b"".join(host[i:i+4][::-1] for i in range(0, len(host), 4))
    return be[addr - a0: addr - a0 + n]

def link_state():
    return read_mem(LINK + 0x24, 12) + read_mem(LINK + 0xB4, 4)

def screenshot():
    """Captura a tela composta (grim), o que voce ve na TV, menos o atraso da propria TV."""
    out = os.path.join(shots, "cur.png")
    subprocess.run(["grim", "-s", "0.25", out], env=env, check=True)
    return Image.open(out).convert("L").resize((240, 135))

TRACE = os.environ.get("TRACE")
def bars(img):
    """pixels pretos na faixa do topo da imagem 4:3 (letterbox do Z-target)"""
    w, h = img.size; band = img.crop((int(w * 0.3), 0, int(w * 0.7), int(h * 0.1)))
    return sum(1 for p in band.getdata() if p < 16)
def changed(a, b):
    if os.environ.get("BARS"):
        n = bars(a)
        if TRACE: print(f"    pretos {n}", flush=True)
        return n > 20
    diff = ImageChops.difference(a, b)
    n = sum(1 for p in diff.getdata() if p > 12)
    if TRACE: print(f"    diff {n}", flush=True)
    return n > int(os.environ.get("PIXTHR", "6"))

try:
    for _ in range(80):   # espera o RetroArch e o estado carregarem
        time.sleep(0.25)
        try:
            if link_state(): break
        except Exception: pass
    time.sleep(3)
    cmd("PAUSE_TOGGLE"); time.sleep(0.5)
    results = []
    for t in range(TRIALS):
        for _ in range(t % 3 + 4):          # desloca a fase e deixa o Link parado
            cmd("FRAMEADVANCE"); time.sleep(0.05)
        time.sleep(0.3)
        mem0, img0 = link_state(), screenshot()
        kf.write(f"down {KEY}\n"); time.sleep(0.4)
        nm = ns = None
        for f in range(1, MAXF + 1):
            cmd("FRAMEADVANCE"); time.sleep(0.12)
            if nm is None and link_state() != mem0: nm = f
            if ns is None and changed(screenshot(), img0): ns = f
            if TRACE: print(f"    quadro {f}: mem {'mudou' if nm else '-'}", flush=True)
            if nm is not None and ns is not None and not TRACE: break
        kf.write(f"up {KEY}\n"); time.sleep(0.3)
        for _ in range(45):                 # solta e deixa o Link parar
            cmd("FRAMEADVANCE"); time.sleep(0.03)
        results.append((nm, ns)); print(f"  tentativa {t+1}: mem {nm}  tela {ns}", flush=True)
    ok = [(m, s) for m, s in results if m and s]
    if ok:
        print(f"{name}: mem {sum(m for m,_ in ok)/len(ok):.2f}  tela {sum(s for _,s in ok)/len(ok):.2f} quadros "
              f"(min tela {min(s for _,s in ok)}, max {max(s for _,s in ok)}; n={len(ok)})")
finally:
    kf.write("quit\n"); kf.close(); kbd.wait()
    ra.terminate()
    try: ra.wait(5)
    except subprocess.TimeoutExpired: ra.kill()
