#!/usr/bin/env python3
"""rtlat.py NOME [chave=valor ...] -> latencia de entrada EM TEMPO REAL (ms), Zelda OoT.

Roda o jogo normalmente (vsync, audio sync), captura a saida de video que vai para o
HDMI com ffmpeg kmsgrab (o plano de scanout, depois do compositor) e mede o tempo entre
a tecla (teclado virtual uinput) e o primeiro quadro da tela que mudou na regiao do Link.
Inclui: logica do jogo + emulador + fila de video + compositor. Nao inclui o atraso da
propria TV. A captura soma um atraso constante (~1 quadro), igual para todas as configs.
TRIALS rodadas; KEY padrao seta para a direita (o Link vira)."""
import os, re, subprocess, sys, threading, time, statistics

B = os.path.dirname(os.path.abspath(__file__))
name, kvs = sys.argv[1], sys.argv[2:]
TRIALS = int(os.environ.get("TRIALS", "20"))
KEY = os.environ.get("KEY", "KEY_LEFTSHIFT")   # Z-target: faixas pretas de cinema entram no topo da tela
W, H = 160, 90
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
optp = os.path.join(B, f"rt-{name}.opt"); open(optp, "w").write(opt)
cfgp = os.path.join(B, f"rt-{name}.cfg")
keys = [l for l in open(os.path.join(B, "keys.txt")).read().strip().split(";") if l]
open(cfgp, "w").write("\n".join([
    f'core_options_path = "{optp}"', 'game_specific_options = "false"', 'global_core_options = "true"',
    'savestate_auto_load = "true"', 'savestate_auto_save = "false"',
    f'savestate_directory = "{B}/states"', f'savefile_directory = "{B}/saves"',
    'fps_show = "false"', 'config_save_on_exit = "false"', 'menu_show_load_content_animation = "false"',
    'notification_show_autoconfig = "false"', *keys, *extra]) + "\n")

env = dict(os.environ, XDG_RUNTIME_DIR=f"/run/user/{os.getuid()}", WAYLAND_DISPLAY="wayland-0")
ra = subprocess.Popen(["retroarch", "--verbose", f"--appendconfig={cfgp}", "-L", CORE, ROM],
                      stdout=open(os.path.join(B, f"rt-{name}.log"), "w"), stderr=subprocess.STDOUT, env=env)
fifo = os.path.join(B, "kbd.fifo")
if not os.path.exists(fifo): os.mkfifo(fifo)
kbd = subprocess.Popen(["sudo", "python3", os.path.join(B, "vkbd.py"), fifo])
kf = open(fifo, "w", buffering=1)

frames = []          # (instante de chegada, bytes da regiao, 1 byte por pixel)
lock = threading.Lock()
RW, RH = 600, 120    # faixa do topo da imagem 4:3 (onde a faixa preta entra)
GEOM = os.environ.get("GEOM", f"{960 - RW // 2},0 {RW}x{RH}")
def grab():
    # wf-recorder pede quadros ao compositor so quando a regiao muda (damage) ->
    # o instante de chegada e o instante em que o compositor montou o quadro novo
    vf = os.path.join(B, "video.fifo")
    if not os.path.exists(vf): os.mkfifo(vf)
    # o FIFO "ja existe": o wf-recorder pergunta se sobrescreve -> responde Y no stdin
    rec = subprocess.Popen(["wf-recorder", "-g", GEOM, "-c", "rawvideo", "-m", "rawvideo", "-f", vf],
                           stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    rec.stdin.write(b"Y\n"); rec.stdin.flush()
    src = open(vf, "rb", buffering=0)
    n = RW * RH * 4
    while True:
        buf = b""
        while len(buf) < n:
            chunk = src.read(n - len(buf))
            if not chunk: return
            buf += chunk
        if len(buf) < n: break
        with lock: frames.append((time.monotonic(), buf[1::4]))   # canal G como luminancia
threading.Thread(target=grab, daemon=True).start()

def roi(buf): return buf
def diff(a, b): return sum(1 for p, q in zip(a, b) if abs(p - q) > 18)

try:
    time.sleep(12)                       # RetroArch + estado + cena estavel
    lat = []
    for t in range(TRIALS):
        time.sleep(2.5)                  # Link parado, camera assentada
        # espera nao haver faixa preta (Z solto e camera de volta ao normal)
        def dark(b): return sum(1 for p in b if p < 16)
        DARK = RW // 2                   # meia linha preta = a faixa de cinema comecou a entrar
        for _ in range(60):
            with lock: last = frames[-1:]
            if last and dark(last[0][1]) < DARK // 4: break
            time.sleep(0.05)
        start = len(frames)
        t_key = time.monotonic()
        kf.write(f"down {KEY}\n")
        hit = None; deadline = t_key + 2.0
        while time.monotonic() < deadline and hit is None:
            time.sleep(0.003)
            with lock: new = frames[start:]
            for ts, buf in new:
                if ts > t_key and dark(buf) >= DARK:
                    hit = ts; break
        noise = thr = DARK
        if os.environ.get("DUMP") and t == 0:
            from PIL import Image
            time.sleep(0.3)
            with lock: seq = [f for f in frames[start:] if f[0] > t_key]
            for k, (ts, b) in enumerate(seq[:24]):
                Image.frombytes("L", (RW, RH), bytes(b)).save(os.path.join(B, "shots", f"seq-{k:02d}-{int((ts-t_key)*1000)}ms-d{dark(b)}.png"))
        if hit:
            lat.append((hit - t_key) * 1000)
            print(f"  rodada {t+1}: {lat[-1]:.0f} ms (ruido {noise}, limiar {thr})", flush=True)
        else:
            with lock: new = frames[start:]
            mx = max([dark(b) for ts, b in new if ts > t_key] or [0])
            print(f"  rodada {t+1}: sem mudanca detectada ({len(new)} quadros, diff max {mx}, limiar {thr})", flush=True)
        if os.environ.get("SHOTS"):
            subprocess.run(["grim", "-s", "0.2", os.path.join(B, "shots", f"rt-{name}-{t+1}.png")], env=env)
        time.sleep(0.3); kf.write(f"up {KEY}\n")   # solta: as faixas saem
    if lat:
        print(f"{name}: mediana {statistics.median(lat):.0f} ms, media {statistics.mean(lat):.0f}, "
              f"min {min(lat):.0f}, max {max(lat):.0f} (n={len(lat)}); captura {len(frames)/(frames[-1][0]-frames[0][0]):.0f} q/s")
finally:
    kf.write("quit\n"); kf.close(); kbd.wait()
    ra.terminate()
    try: ra.wait(5)
    except subprocess.TimeoutExpired: ra.kill()
    subprocess.run(["pkill", "-INT", "-x", "wf-recorder"])
