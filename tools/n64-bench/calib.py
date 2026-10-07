#!/usr/bin/env python3
"""calib.py -> atraso da propria captura (wf-recorder): fecha a janela do RetroArch num
instante conhecido (some em ~1 quadro) e mede quando a captura mostra a mudanca."""
import os, subprocess, threading, time, signal
B = os.path.dirname(os.path.abspath(__file__))
env = dict(os.environ, XDG_RUNTIME_DIR=f"/run/user/{os.getuid()}", WAYLAND_DISPLAY="wayland-0")
RW, RH = 600, 120; GEOM = f"{960 - RW // 2},0 {RW}x{RH}"
res = []
for trial in range(5):
    ra = subprocess.Popen(["retroarch", f"--appendconfig={B}/rt-base.cfg", "-L",
                           "/usr/lib/aarch64-linux-gnu/libretro/mupen64plus_next_libretro.so",
                           "/srv/lasdpc-pi-station/roms/n64/Legend of Zelda, The - Ocarina of Time.z64"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    time.sleep(10)
    frames = []; lock = threading.Lock()
    vf = os.path.join(B, "video.fifo")
    if not os.path.exists(vf): os.mkfifo(vf)
    rec = subprocess.Popen(["wf-recorder", "-g", GEOM, "-c", "rawvideo", "-m", "rawvideo", "-f", vf],
                           stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    rec.stdin.write(b"Y\n"); rec.stdin.flush()
    def grab():
        src = open(vf, "rb", buffering=0); n = RW * RH * 4
        while True:
            buf = b""
            while len(buf) < n:
                c = src.read(n - len(buf))
                if not c: return
                buf += c
            with lock: frames.append((time.monotonic(), buf[1::4]))
    threading.Thread(target=grab, daemon=True).start()
    time.sleep(3)
    with lock: ref = frames[-1][1]; start = len(frames)
    t0 = time.monotonic(); ra.send_signal(signal.SIGKILL)   # janela some no proximo quadro do compositor
    hit = None
    while time.monotonic() < t0 + 3 and not hit:
        time.sleep(0.003)
        with lock: new = frames[start:]
        for ts, b in new:
            if sum(1 for p, q in zip(b, ref) if abs(p - q) > 40) > RW * RH // 3: hit = ts; break
    rec.send_signal(signal.SIGINT); rec.wait()
    res.append((hit - t0) * 1000 if hit else None); print(f"  calib {trial+1}: {res[-1]}", flush=True)
ok = sorted(r for r in res if r)
print(f"atraso da captura: mediana {ok[len(ok)//2]:.0f} ms (min {ok[0]:.0f}, max {ok[-1]:.0f})")
