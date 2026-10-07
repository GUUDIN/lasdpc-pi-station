#!/usr/bin/env python3
"""ytprobe.py NOME VIDEO_ID [SEGUNDOS] [--sem-ubol] -> abre o YouTube TV (leanback) no Chromium
como o lasdpc-youtube, toca o video e amostra o player via DevTools: duracao do que esta
tocando (anuncio = curto), resolucao, quadros decodificados/perdidos."""
import json, os, subprocess, sys, time, urllib.request, shutil
import websocket

name, vid = sys.argv[1], sys.argv[2]
secs = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 40
no_ubol = "--sem-ubol" in sys.argv
K = "/opt/lasdpc-pi-station/kiosk"
exts = [f"{K}/escape-extension", f"{K}/h264ify-extension"] + ([] if no_ubol else [f"{K}/ubol"]) + ([f"{K}/ytads-extension"] if "--ytads" in sys.argv else [])
prof = f"/tmp/claude-1000/ytprobe-{name}"
shutil.rmtree(prof, ignore_errors=True)
env = dict(os.environ, XDG_RUNTIME_DIR=f"/run/user/{os.getuid()}", WAYLAND_DISPLAY="wayland-0")
UA = "Mozilla/5.0 (SMART-TV; Linux; Tizen 6.5) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/5.0 TV Safari/537.36"
args = ["chromium", "--ozone-platform=wayland", f"--user-data-dir={prof}", f"--load-extension={','.join(exts)}",
        "--disable-features=DisableLoadExtensionCommandLineSwitch,Translate,TranslateUI",
        *os.environ.get("GPUFLAGS", "").split(),
        "--no-first-run", "--noerrdialogs", "--password-store=basic", "--autoplay-policy=no-user-gesture-required",
        f"--user-agent={UA}", "--remote-debugging-port=9222", "--start-fullscreen", "--kiosk",
        f"https://www.youtube.com/tv#/watch?v={vid}"]
cr = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=open(f"{prof}.err", "w"), env=env)

def targets():
    return json.load(urllib.request.urlopen("http://127.0.0.1:9222/json"))
ws = None
try:
    for _ in range(60):
        time.sleep(1)
        try:
            ts = targets()
        except Exception:
            continue
        page = [t for t in ts if t["type"] == "page" and "youtube.com" in t["url"]]
        if page: ws = websocket.create_connection(page[0]["webSocketDebuggerUrl"], suppress_origin=True); break
    print("alvos:", [(t["type"], t["url"][:70]) for t in targets()])
    mid = [0]
    def ev(expr):
        mid[0] += 1
        ws.send(json.dumps({"id": mid[0], "method": "Runtime.evaluate", "params": {"expression": expr, "returnByValue": True}}))
        while True:
            r = json.loads(ws.recv())
            if r.get("id") == mid[0]: return r.get("result", {}).get("result", {}).get("value")
    probe = """(() => { const v = document.querySelector('video'); if (!v) return null;
      const q = v.getVideoPlaybackQuality ? v.getVideoPlaybackQuality() : {};
      return {t: +v.currentTime.toFixed(1), dur: +(v.duration||0).toFixed(1), h: v.videoHeight, w: v.videoWidth,
              paused: v.paused, dec: q.totalVideoFrames, drop: q.droppedVideoFrames}; })()"""
    # teclado virtual de verdade (uinput), como um teclado USB na TV
    VK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "n64-bench", "vkbd.py")
    fifo = f"/tmp/claude-1000/ytprobe-{name}.fifo"
    if not os.path.exists(fifo): os.mkfifo(fifo)
    kbd = subprocess.Popen(["sudo", "python3", VK, fifo]); kf = open(fifo, "w", buffering=1)
    def key(k, code=None):
        kf.write(f"tap KEY_{k} 80\n"); time.sleep(0.3)
    # tela de contas na 1a vez: "Watch as guest" (como no controle remoto: baixo + OK)
    time.sleep(int(os.environ.get("WAIT", "12")))
    txt = ev("document.body ? document.body.innerText.slice(0, 200) : ''") or ""
    print("tela:", " | ".join(txt.split()[:12]))
    if True:   # perfil novo: a tela de contas sempre aparece (o texto fica em shadow DOM)
        key("DOWN"); time.sleep(0.8); key("ENTER"); time.sleep(5)
        print("depois:", " | ".join((ev("document.body.innerText.slice(0, 120)") or "").split()[:10]))
        ev(f"location.hash = '#/watch?v={vid}'")
    t0 = time.time(); samples = []
    SHOT = os.environ.get("SHOT")
    while time.time() - t0 < secs:
        time.sleep(3)
        s = ev(probe); samples.append(s); print(f"  {time.time()-t0:5.1f}s {s}", flush=True)
        if SHOT and len(samples) in (2, 5, 10):
            subprocess.run(["grim", "-s", "0.4", f"/tmp/claude-1000/ytprobe-{name}-{len(samples)}.png"], env=env)
    mimes = ev("""[...new Set(performance.getEntriesByType('resource').map(e => e.name)
        .filter(u => u.includes('videoplayback')).map(u => { const q = new URL(u).searchParams;
        return (q.get('mime') || '?') + ' itag=' + (q.get('itag') || '?'); }))].slice(0, 8)""")
    print("formatos baixados:", mimes)
    if os.environ.get("GPU"):
        mid[0] += 1
        ws.send(json.dumps({"id": mid[0], "method": "Page.navigate", "params": {"url": "chrome://gpu"}}))
        time.sleep(4)
        txt = ev("document.body.innerText") or ""
        for line in txt.splitlines():
            if any(k in line for k in ("Video Decode", "Video Encode", "Rasterization", "OpenGL:", "GL_RENDERER")): print("  gpu:", line.strip()[:110])
    good = [s for s in samples if s and s["dec"]]
    if len(good) >= 2:
        a, b = good[0], good[-1]
        print(f"{name}: duracoes vistas {sorted({s['dur'] for s in good})}, {b['w']}x{b['h']}, "
              f"perdidos {b['drop']-a['drop']}/{b['dec']-a['dec']} quadros no periodo")
finally:
    try: kf.write("quit\n"); kf.close()
    except Exception: pass
    if ws: ws.close()
    cr.terminate()
    try: cr.wait(5)
    except subprocess.TimeoutExpired: cr.kill()
