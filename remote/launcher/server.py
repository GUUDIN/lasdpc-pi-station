#!/usr/bin/env python3
# ============================================================
# LASDPC Station — servidor local do menu central (stdlib only).
# Serve a página do menu e uma API mínima para trocar de modo / energia / status.
# Bind 127.0.0.1:8090 (somente local; exibido pelo Chromium kiosk).
# Executado pelo serviço systemd lasdpc-launcher (usuário lasdpc, sudo NOPASSWD).
# ============================================================
import json, os, shutil, subprocess, socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
BIND = ("127.0.0.1", 8090)
MODES = {"dashboard", "menu", "media", "games", "desktop"}

def sh(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=15).stdout.strip()
    except Exception:
        return ""

def have(b): return shutil.which(b) is not None

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
            "tailscale": ts, "net": net_ok(), "containers": containers}

class H(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json"):
        b = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(b)

    def log_message(self, *a):  # silencioso
        pass

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            try:
                with open(os.path.join(HERE, "index.html"), "rb") as f:
                    self._send(200, f.read(), "text/html; charset=utf-8")
            except Exception as e:
                self._send(500, str(e), "text/plain")
        elif self.path == "/api/status":
            self._send(200, json.dumps(status()))
        else:
            self._send(404, "not found", "text/plain")

    def do_POST(self):
        p = self.path
        if p.startswith("/api/mode/"):
            m = p.rsplit("/", 1)[-1]
            if m in MODES:
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
        else:
            self._send(404, "not found", "text/plain")

if __name__ == "__main__":
    print(f"LASDPC launcher em http://{BIND[0]}:{BIND[1]}")
    ThreadingHTTPServer(BIND, H).serve_forever()
