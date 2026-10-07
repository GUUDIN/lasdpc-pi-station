#!/usr/bin/env python3
# ============================================================
# LASDPC Station — servidor local do menu central (stdlib only).
# Serve a página do menu e uma API mínima para trocar de modo / energia / status.
# Bind 127.0.0.1:8090 (somente local; exibido pelo Chromium kiosk).
# Executado pelo serviço systemd lasdpc-launcher (usuário lasdpc, sudo NOPASSWD).
# ============================================================
import hashlib, json, os, re, shutil, subprocess, socket, threading
import keyshare
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
BIND = ("127.0.0.1", 8090)

def apps_list():
    """Apps habilitados na estacao (registro: lasdpc-apps, apps/<id>/app.json)."""
    try:
        return json.loads(subprocess.run(["lasdpc-apps", "json"], capture_output=True, text=True, timeout=5).stdout)
    except Exception:
        return []

def resolve_mode(name):
    r = subprocess.run(["lasdpc-apps", "resolve", name], capture_output=True, text=True, timeout=5)
    return r.stdout.strip() if r.returncode == 0 else None
YTDLP = "/usr/local/bin/yt-dlp"
# Atalhos fixos do modo TV/Esportes. URL de CANAL oficial (.../@handle/live) pega
# a live ativa do canal certo — bem mais confiavel que busca por texto, que
# retorna clones/re-transmissoes. yt-dlp resolve /live para a transmissao atual.
TV_CHANNELS = [
    {"name": "Cazé TV", "url": "https://www.youtube.com/@CazeTV/live"},
    {"name": "Cazé TV 2", "url": "https://www.youtube.com/@CazeTV2/live"},
    {"name": "GE (ge.globo)", "url": "https://www.youtube.com/@geglobo/live"},
    {"name": "Jovem Pan News", "url": "https://www.youtube.com/@jovempannews/live"},
]
CONF_DIR = os.path.expanduser("~/.config/lasdpc")
SESSION_ENV = os.path.join(CONF_DIR, "session.env")
DASHBOARDS_FILE = os.path.join(CONF_DIR, "dashboards.json")
DEFAULT_DASHBOARDS = [
    {"id": "local", "name": "IoT local", "url": "http://localhost:8080"},
    {"id": "andromeda", "name": "Andromeda", "url": "http://andromeda.lasdpc.icmc.usp.br:60107/"},
]

# Jogos: pasta de ROMs por sistema -> cores aceitos (o primeiro instalado vence).
ROMS_DIR = "/srv/lasdpc-pi-station/roms"
CORE_DIRS = [os.path.expanduser("~/.config/retroarch/cores"), "/usr/lib/aarch64-linux-gnu/libretro"]
THUMBS_DIR = os.path.expanduser("~/.config/retroarch/thumbnails")
GAME_SYSTEMS = {
    "n64": ("Nintendo 64", "Nintendo - Nintendo 64", (".z64", ".n64", ".v64"),
            ["mupen64plus_next_libretro.so", "parallel_n64_libretro.so"]),
    "snes": ("Super Nintendo", "Nintendo - Super Nintendo Entertainment System", (".sfc", ".smc", ".zip"),
             ["snes9x_libretro.so"]),
    "nes": ("NES", "Nintendo - Nintendo Entertainment System", (".nes", ".zip"), ["nestopia_libretro.so"]),
    "megadrive": ("Mega Drive", "Sega - Mega Drive - Genesis", (".md", ".gen", ".bin", ".smd", ".zip"),
                  ["genesis_plus_gx_libretro.so"]),
    "mastersystem": ("Master System", "Sega - Master System - Mark III", (".sms", ".zip"),
                     ["genesis_plus_gx_libretro.so"]),
    "gbc": ("Game Boy Color", "Nintendo - Game Boy Color", (".gbc", ".gb", ".zip"), ["gambatte_libretro.so"]),
    "gb": ("Game Boy", "Nintendo - Game Boy", (".gb", ".zip"), ["gambatte_libretro.so"]),
}

def find_core(names):
    for name in names:
        for d in CORE_DIRS:
            p = os.path.join(d, name)
            if os.path.isfile(p):
                return p
    return None

def game_label(filename):
    """'Legend of Zelda, The - Ocarina of Time (U) [!].z64' -> 'The Legend of Zelda: Ocarina of Time'."""
    name = os.path.splitext(filename)[0]
    name = re.sub(r"\s*[\(\[][^\)\]]*[\)\]]", "", name).strip()
    m = re.match(r"^(.*?), (The|A|An)( - .*)?$", name)
    if m:
        name = f"{m.group(2)} {m.group(1)}{m.group(3) or ''}"
    return name.replace(" - ", ": ", 1)

def game_thumb(playlist, label):
    # mesmo esquema de nomes de thumbnail do RetroArch: &*/:`<>?\| viram _
    safe = re.sub(r'[&*/:`<>?\\|"]', "_", label)
    for kind in ("Named_Boxarts", "Named_Titles", "Named_Snaps"):
        p = os.path.join(THUMBS_DIR, playlist, kind, safe + ".png")
        if os.path.isfile(p):
            return p
    return None

def games_list():
    games = []
    for sysid, (sysname, playlist, exts, cores) in GAME_SYSTEMS.items():
        core = find_core(cores)
        d = os.path.join(ROMS_DIR, sysid)
        if not core or not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            path = os.path.join(d, fn)
            if not fn.lower().endswith(exts) or not os.path.isfile(path):
                continue
            label = game_label(fn)
            games.append({
                "id": hashlib.sha1(path.encode()).hexdigest()[:12],
                "label": label, "system": sysname, "path": path, "core": core,
                "thumb": game_thumb(playlist, label),
            })
    return games

def game_play(payload):
    wanted = str(payload.get("id") or "")
    game = next((g for g in games_list() if g["id"] == wanted), None)
    if game is None:
        raise ValueError("jogo nao encontrado")
    os.makedirs(CONF_DIR, exist_ok=True)
    with open(os.path.join(CONF_DIR, "game_request"), "w") as f:
        f.write(f"{game['core']}\n{game['path']}\n")
    env = dict(os.environ, LASDPC_LOADING_MSG=f"Abrindo {game['label']}")
    subprocess.run(["lasdpc-mode", "games"], env=env)
    return game

def sh(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=15).stdout.strip()
    except Exception:
        return ""

def have(b): return shutil.which(b) is not None

def env_read():
    data = {"DASHBOARD_URL": "http://localhost:8080", "MENU_URL": "http://localhost:8090"}
    try:
        with open(SESSION_ENV) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                data[k.strip()] = v.strip().strip("'\"")
    except Exception:
        pass
    return data

def env_write(data):
    os.makedirs(CONF_DIR, exist_ok=True)
    current = env_read()
    current.update(data)
    body = "".join(f"{k}={v}\n" for k, v in sorted(current.items()))
    tmp = SESSION_ENV + ".tmp"
    with open(tmp, "w") as f:
        f.write(body)
    os.replace(tmp, SESSION_ENV)

def safe_id(name):
    sid = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return sid[:40] or "dashboard"

def valid_url(url):
    return isinstance(url, str) and re.match(r"^https?://[^ \t\r\n]+$", url) is not None

def dashboards_load():
    env = env_read()
    dashboards = []
    try:
        with open(DASHBOARDS_FILE) as f:
            raw = json.load(f)
        if isinstance(raw, list):
            dashboards = raw
        elif isinstance(raw, dict):
            dashboards = raw.get("dashboards", [])
    except Exception:
        dashboards = []

    by_url = {}
    for item in DEFAULT_DASHBOARDS + dashboards:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name", "")).strip()[:80]
        url = str(item.get("url", "")).strip()
        if not name or not valid_url(url):
            continue
        did = safe_id(str(item.get("id") or name))
        by_url[url] = {"id": did, "name": name, "url": url}

    current = env.get("DASHBOARD_URL", "http://localhost:8080")
    if valid_url(current) and current not in by_url:
        by_url[current] = {"id": safe_id(current), "name": "Dashboard atual", "url": current}
    dashboards = list(by_url.values())
    dashboards.sort(key=lambda x: (x["url"] != current, x["name"].lower()))
    return {"current": current, "dashboards": dashboards}

def dashboards_save(items):
    os.makedirs(CONF_DIR, exist_ok=True)
    tmp = DASHBOARDS_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"dashboards": items}, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, DASHBOARDS_FILE)

def dashboard_select(payload):
    state = dashboards_load()
    wanted = str(payload.get("id") or "").strip()
    url = str(payload.get("url") or "").strip()
    chosen = None
    for item in state["dashboards"]:
        if item["id"] == wanted or item["url"] == url:
            chosen = item
            break
    if chosen is None and valid_url(url):
        chosen = {"id": safe_id(payload.get("name") or url), "name": str(payload.get("name") or "Dashboard").strip()[:80], "url": url}
        state["dashboards"].append(chosen)
        dashboards_save(state["dashboards"])
    if chosen is None:
        raise ValueError("dashboard invalido")
    env_write({"DASHBOARD_URL": chosen["url"]})
    return chosen

def dashboard_save(payload):
    name = str(payload.get("name") or "").strip()[:80]
    url = str(payload.get("url") or "").strip()
    if not name or not valid_url(url):
        raise ValueError("nome ou URL invalidos")
    state = dashboards_load()
    did = safe_id(payload.get("id") or name)
    item = {"id": did, "name": name, "url": url}
    out = [x for x in state["dashboards"] if x["id"] != did and x["url"] != url]
    out.append(item)
    dashboards_save(out)
    return item

def sh_long(cmd, timeout=30):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except Exception:
        return ""

def tv_search(query, n=10):
    """Busca no YouTube via yt-dlp (sem API key). Retorna metadados leves."""
    query = str(query or "").strip()[:120]
    if not query:
        return []
    out = sh_long([YTDLP, f"ytsearch{n}:{query}", "--flat-playlist",
                   "--dump-json", "--no-warnings"], timeout=30)
    results = []
    for line in out.splitlines():
        try:
            d = json.loads(line)
        except Exception:
            continue
        vid = d.get("id")
        if not vid:
            continue
        results.append({
            "id": vid,
            "title": (d.get("title") or "")[:120],
            "channel": (d.get("channel") or d.get("uploader") or "")[:80],
            "live": bool(d.get("is_live")),
            "duration": d.get("duration"),
        })
    return results

def tv_play(payload):
    """Toca uma URL especifica, ou resolve uma query (atalho) para a 1a live."""
    url = str(payload.get("url") or "").strip()
    query = str(payload.get("query") or "").strip()
    if not url and query:
        res = tv_search(query, 6)
        # prefere transmissao ao vivo; senao o 1o resultado
        live = [r for r in res if r["live"]]
        pick = (live or res)[:1]
        if pick:
            url = f"https://www.youtube.com/watch?v={pick[0]['id']}"
    if not valid_url(url):
        raise ValueError("nenhum video encontrado")
    subprocess.run(["lasdpc-play", url])
    return url

def net_ok():
    try:
        socket.setdefaulttimeout(2)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect(("1.1.1.1", 53))
        return True
    except Exception:
        return False

def status():
    mode = ""
    mf = os.path.expanduser("~/.config/lasdpc/mode")
    try: mode = open(mf).read().strip()
    except Exception: mode = "?"
    temp = sh(["vcgencmd", "measure_temp"]).replace("temp=", "") if have("vcgencmd") else "?"
    thr = sh(["vcgencmd", "get_throttled"]) if have("vcgencmd") else "?"
    ip = (sh(["hostname", "-I"]).split() or ["?"])[0]
    ts = sh(["tailscale", "ip", "-4"]).split("\n")[0] if have("tailscale") else ""
    containers = []
    if have("docker"):
        out = sh(["sudo", "docker", "ps", "--format", "{{.Names}}|{{.Status}}"])
        for line in out.splitlines():
            if "lasdpc" in line and "|" in line:
                n, s = line.split("|", 1)
                containers.append({"name": n.replace("lasdpc-", ""), "status": s})
    return {"mode": mode, "temp": temp, "throttled": thr, "ip": ip,
            "dashboard": env_read().get("DASHBOARD_URL", ""),
            "tailscale": ts, "net": net_ok(), "containers": containers}

# Copiar a chave do Spotify entre estacoes (ver keyshare.py)
SHARER = keyshare.Sharer()
FETCH = {"job": None}

class ShareH(BaseHTTPRequestHandler):
    """Porta 8091, aberta na rede local: SO pedir e buscar a chave aprovada."""
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def log_message(self, *a):
        pass

    def do_POST(self):
        if self.path != "/share/request":
            return self._send(404, {"error": "not found"})
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 4096)
            body = json.loads(self.rfile.read(length).decode() or "{}")
            rid, code = SHARER.request(body.get("name", "?"), self.client_address[0], body["pub"])
            self._send(200, {"id": rid, "code": code})
        except Exception as e:
            self._send(400, {"error": str(e)})

    def do_GET(self):
        if self.path.startswith("/share/result/"):
            return self._send(200, SHARER.result(self.path.rsplit("/", 1)[-1]))
        self._send(404, {"error": "not found"})

class H(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json"):
        b = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(b)

    def _json_body(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0:
                return {}
            return json.loads(self.rfile.read(length).decode())
        except Exception:
            return {}

    def log_message(self, *a):  # silencioso
        pass

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            try:
                with open(os.path.join(HERE, "index.html"), "rb") as f:
                    self._send(200, f.read(), "text/html; charset=utf-8")
            except Exception as e:
                self._send(500, str(e), "text/plain")
        elif self.path == "/airplay.html":
            try:
                with open(os.path.join(HERE, "airplay.html"), "rb") as f:
                    self._send(200, f.read(), "text/html; charset=utf-8")
            except Exception as e:
                self._send(500, str(e), "text/plain")
        elif self.path == "/musica.html":
            try:
                with open(os.path.join(HERE, "musica.html"), "rb") as f:
                    self._send(200, f.read(), "text/html; charset=utf-8")
            except Exception as e:
                self._send(500, str(e), "text/plain")
        elif self.path == "/ytcast.html":
            try:
                with open(os.path.join(HERE, "ytcast.html"), "rb") as f:
                    self._send(200, f.read(), "text/html; charset=utf-8")
            except Exception as e:
                self._send(500, str(e), "text/plain")
        elif self.path == "/api/ytcast/code":
            # codigo de pareamento "Inserir codigo" escrito pelo receptor (node)
            code = ""
            try:
                p = os.path.expanduser("~/.config/lasdpc/ytcast_code")
                if os.path.exists(p):
                    with open(p) as f:
                        code = f.read().strip()
            except Exception:
                code = ""
            self._send(200, json.dumps({"code": code}))
        elif self.path == "/api/ytcast/status":
            p = os.path.expanduser("~/.config/lasdpc/ytcast_status.json")
            try:
                with open(p) as f:
                    data = json.load(f)
            except Exception:
                data = {"status": "unknown", "message": "Aguardando receiver"}
            self._send(200, json.dumps(data, ensure_ascii=False))
        elif self.path == "/api/status":
            self._send(200, json.dumps(status()))
        elif self.path == "/api/dashboards":
            self._send(200, json.dumps(dashboards_load(), ensure_ascii=False))
        elif self.path == "/api/tv/channels":
            self._send(200, json.dumps({"channels": TV_CHANNELS}, ensure_ascii=False))
        elif self.path == "/api/share/pending":
            self._send(200, json.dumps({"pending": SHARER.pending(), "has_key": SHARER.has_key(),
                                        "window_until": SHARER.window_until}))
        elif self.path == "/api/share/stations":
            self._send(200, json.dumps({"stations": keyshare.discover()}, ensure_ascii=False))
        elif self.path == "/api/share/fetch":
            job = FETCH["job"]
            self._send(200, json.dumps({"state": job.state, "code": job.code, "error": job.error,
                                        "target": job.target} if job else {"state": "idle"}, ensure_ascii=False))
        elif self.path == "/api/apps":
            keep = ("id", "name", "icon", "sub", "order", "tile", "panel", "settings_button")
            apps = [{k: a[k] for k in keep if k in a} for a in apps_list()]
            self._send(200, json.dumps({"apps": apps}, ensure_ascii=False))
        elif self.path == "/api/games":
            games = [{"id": g["id"], "label": g["label"], "system": g["system"], "thumb": bool(g["thumb"])}
                     for g in games_list()]
            self._send(200, json.dumps({"games": games, "roms_dir": ROMS_DIR}, ensure_ascii=False))
        elif self.path.startswith("/api/games/thumb/"):
            wanted = self.path.rsplit("/", 1)[-1]
            game = next((g for g in games_list() if g["id"] == wanted and g["thumb"]), None)
            if game is None:
                self._send(404, "not found", "text/plain")
            else:
                with open(game["thumb"], "rb") as f:
                    self._send(200, f.read(), "image/png")
        else:
            self._send(404, "not found", "text/plain")

    def do_POST(self):
        p = self.path
        if p.startswith("/api/mode/"):
            m = resolve_mode(p.rsplit("/", 1)[-1])
            if m:
                if m == "games":  # sem jogo escolhido: abre o menu do RetroArch
                    try: os.remove(os.path.join(CONF_DIR, "game_request"))
                    except FileNotFoundError: pass
                subprocess.run(["lasdpc-mode", m])
                self._send(200, json.dumps({"ok": True, "mode": m}))
            else:
                self._send(400, json.dumps({"ok": False, "error": "modo inválido"}))
        elif p == "/api/power/reboot":
            subprocess.Popen(["sudo", "systemctl", "reboot"])
            self._send(200, json.dumps({"ok": True}))
        elif p == "/api/power/shutdown":
            subprocess.Popen(["sudo", "systemctl", "poweroff"])
            self._send(200, json.dumps({"ok": True}))
        elif p == "/api/dashboard/select":
            try:
                item = dashboard_select(self._json_body())
                self._send(200, json.dumps({"ok": True, "dashboard": item}, ensure_ascii=False))
            except Exception as e:
                self._send(400, json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
        elif p == "/api/dashboard/save":
            try:
                item = dashboard_save(self._json_body())
                self._send(200, json.dumps({"ok": True, "dashboard": item}, ensure_ascii=False))
            except Exception as e:
                self._send(400, json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
        elif p == "/api/share/decide":
            b = self._json_body()
            ok = SHARER.decide(str(b.get("id", "")), bool(b.get("allow")))
            self._send(200, json.dumps({"ok": ok}))
        elif p == "/api/share/window":
            until = SHARER.open_window(int(self._json_body().get("minutes", 10)))
            self._send(200, json.dumps({"ok": True, "window_until": until}))
        elif p == "/api/share/fetch":
            target = str(self._json_body().get("target", "")).strip()
            job = FETCH["job"]
            if job and job.state in ("starting", "waiting"):
                self._send(409, json.dumps({"ok": False, "error": "ja existe um pedido em andamento"}))
            elif not target:
                self._send(400, json.dumps({"ok": False, "error": "escolha uma estacao"}))
            else:
                job = keyshare.Fetch(target); FETCH["job"] = job
                threading.Thread(target=job.run, daemon=True).start()
                self._send(200, json.dumps({"ok": True}))
        elif p == "/api/games/play":
            try:
                game = game_play(self._json_body())
                self._send(200, json.dumps({"ok": True, "label": game["label"]}, ensure_ascii=False))
            except Exception as e:
                self._send(400, json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
        elif p == "/api/tv/search":
            try:
                results = tv_search(self._json_body().get("query"), 12)
                self._send(200, json.dumps({"ok": True, "results": results}, ensure_ascii=False))
            except Exception as e:
                self._send(400, json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
        elif p == "/api/tv/play":
            try:
                url = tv_play(self._json_body())
                self._send(200, json.dumps({"ok": True, "url": url}, ensure_ascii=False))
            except Exception as e:
                self._send(400, json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
        else:
            self._send(404, "not found", "text/plain")

if __name__ == "__main__":
    # anuncia a estacao no mDNS (com/sem chave do Spotify) e abre a porta da troca
    subprocess.run(["sudo", "-n", "lasdpc-soloist-key", "advertise"], capture_output=True)
    share = ThreadingHTTPServer(("0.0.0.0", keyshare.PORT), ShareH)
    threading.Thread(target=share.serve_forever, daemon=True).start()
    print(f"LASDPC launcher em http://{BIND[0]}:{BIND[1]} (troca de chave em :{keyshare.PORT})")
    ThreadingHTTPServer(BIND, H).serve_forever()
