#!/usr/bin/env python3
"""keyshare — copia a chave do Spotify Soloist entre estacoes da mesma rede.

Fluxo (parecido com parear Bluetooth):
  1. A estacao nova acha as outras pelo mDNS (_lasdpc._tcp, TXT spotify_key=yes) e
     pede a chave, mandando uma chave publica X25519 so dela.
  2. A estacao que tem a chave mostra no menu "<nome> pede a chave (codigo NNNN):
     Permitir / Recusar" — ou aprova sozinha se "Permitir compartilhar por 10 min"
     estiver ligado em Ajustes.
  3. So depois de aprovado a chave e enviada, criptografada para aquela chave
     publica (X25519 + HKDF-SHA256 + AES-256-GCM). Ninguem na rede le a chave.
O codigo de 4 digitos aparece nas duas telas para conferir que e o pedido certo.

Linha de comando (estacao nova):
  python3 keyshare.py list                 estacoes da rede com chave
  python3 keyshare.py fetch [estacao|ip]   pede e instala (sem argumento: a 1a achada)
"""
import base64, hashlib, json, os, re, socket, subprocess, sys, threading, time, urllib.request, uuid

from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes, serialization

PORT = 8091
INFO = b"lasdpc-soloist-key-v1"
b64e = lambda b: base64.b64encode(b).decode()
b64d = lambda s: base64.b64decode(s.encode())


def station_name():
    try:
        with open("/etc/lasdpc/station.conf") as f:
            m = re.search(r'^STATION_NAME="?([^"\n]*)', f.read(), re.M)
            if m and m.group(1):
                return m.group(1)
    except FileNotFoundError:
        pass
    return socket.gethostname()


def code_for(pub_b64):
    """4 digitos para conferir nas duas telas (nao e segredo, e conferencia visual)."""
    return f"{int(hashlib.sha256(pub_b64.encode()).hexdigest()[:8], 16) % 10000:04d}"


def _shared(priv, peer_pub_b64):
    peer = X25519PublicKey.from_public_bytes(b64d(peer_pub_b64))
    return HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=INFO).derive(priv.exchange(peer))


def encrypt_for(peer_pub_b64, secret):
    eph = X25519PrivateKey.generate()
    nonce = os.urandom(12)
    ct = AESGCM(_shared(eph, peer_pub_b64)).encrypt(nonce, secret.encode(), INFO)
    epk = eph.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    return {"epk": b64e(epk), "nonce": b64e(nonce), "ct": b64e(ct)}


def decrypt_with(priv, box):
    return AESGCM(_shared(priv, box["epk"])).decrypt(b64d(box["nonce"]), b64d(box["ct"]), INFO).decode()


# ------------------------------------------------------------- lado que TEM a chave
class Sharer:
    """Estado no servidor do menu: pedidos pendentes, aprovacoes e janela automatica."""
    MAX_PENDING = 5
    TTL = 300

    def __init__(self):
        self.lock = threading.Lock()
        self.reqs = {}          # id -> {name, ip, pub, code, status, box, t}
        self.window_until = 0.0

    def _gc(self):
        now = time.time()
        for i in [i for i, r in self.reqs.items() if now - r["t"] > self.TTL]:
            del self.reqs[i]

    def has_key(self):
        r = subprocess.run(["sudo", "-n", "lasdpc-soloist-key", "status"], capture_output=True, text=True)
        return r.stdout.strip() == "sim"

    def request(self, name, ip, pub):
        with self.lock:
            self._gc()
            if sum(1 for r in self.reqs.values() if r["status"] == "pending") >= self.MAX_PENDING:
                raise ValueError("muitos pedidos pendentes")
            X25519PublicKey.from_public_bytes(b64d(pub))   # valida
            rid = uuid.uuid4().hex
            self.reqs[rid] = {"name": str(name)[:40], "ip": ip, "pub": pub, "code": code_for(pub),
                              "status": "pending", "box": None, "t": time.time()}
            auto = time.time() < self.window_until
        if not self.has_key():
            self.decide(rid, False)
        elif auto:
            self.decide(rid, True)
        return rid, self.reqs[rid]["code"]

    def decide(self, rid, allow):
        with self.lock:
            r = self.reqs.get(rid)
            if not r or r["status"] != "pending":
                return False
            if allow:
                key = subprocess.run(["sudo", "-n", "lasdpc-soloist-key", "get"],
                                     capture_output=True, text=True).stdout
                if not key:
                    r["status"] = "denied"; return False
                r["box"] = encrypt_for(r["pub"], key)
                r["status"] = "approved"
            else:
                r["status"] = "denied"
            return True

    def result(self, rid):
        with self.lock:
            r = self.reqs.get(rid)
            if not r:
                return {"status": "unknown"}
            out = {"status": r["status"]}
            if r["status"] == "approved":
                out["box"] = r["box"]
                del self.reqs[rid]          # entregue uma vez so
            return out

    def pending(self):
        with self.lock:
            self._gc()
            return [{"id": i, "name": r["name"], "ip": r["ip"], "code": r["code"]}
                    for i, r in self.reqs.items() if r["status"] == "pending"]

    def open_window(self, minutes=10):
        self.window_until = time.time() + minutes * 60
        for p in self.pending():
            self.decide(p["id"], True)
        return self.window_until


# ------------------------------------------------------------- lado que PEDE a chave
def discover(timeout=6):
    """Estacoes anunciadas no mDNS: [{station, host, ip, has_key}] (sem a propria)."""
    try:
        out = subprocess.run(["avahi-browse", "-rtpk", "_lasdpc._tcp"], capture_output=True,
                             text=True, timeout=timeout).stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return []
    me = station_name()
    found = {}
    for line in out.splitlines():
        f = line.split(";")
        if len(f) < 10 or f[0] != "=" or f[2] != "IPv4":
            continue
        txt = dict(re.findall(r'"(\w+)=([^"]*)"', f[9]))
        st = txt.get("station") or f[3]
        if st == me or f[7].startswith("127.") or f[7].startswith("172."):
            continue                       # a propria e IPs do Docker/loopback
        found[st] = {"station": st, "host": f[6], "ip": f[7], "has_key": txt.get("spotify_key") == "yes"}
    return sorted(found.values(), key=lambda s: (not s["has_key"], s["station"]))


def _http(method, url, data=None, timeout=5):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, method=method, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


class Fetch:
    """Um pedido de chave em andamento (o menu acompanha o estado)."""

    def __init__(self, target):
        self.target, self.state, self.code, self.error = target, "starting", "", ""

    def run(self, wait=300, install=True):
        try:
            ip = self.target
            if not re.match(r"^\d+\.\d+\.\d+\.\d+$", ip):
                st = [s for s in discover() if self.target in (s["station"], s["host"], s["host"].split(".")[0])]
                if not st:
                    raise RuntimeError(f"estacao '{self.target}' nao encontrada na rede")
                ip = st[0]["ip"]
            priv = X25519PrivateKey.generate()
            pub = b64e(priv.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw))
            r = _http("POST", f"http://{ip}:{PORT}/share/request", {"name": station_name(), "pub": pub})
            self.code, rid, self.state = r["code"], r["id"], "waiting"
            deadline = time.time() + wait
            while time.time() < deadline:
                res = _http("GET", f"http://{ip}:{PORT}/share/result/{rid}")
                if res["status"] == "approved":
                    key = decrypt_with(priv, res["box"])
                    if install:
                        p = subprocess.run(["sudo", "-n", "lasdpc-soloist-key", "set"], input=key + "\n",
                                           capture_output=True, text=True)
                        if p.returncode != 0:
                            raise RuntimeError(p.stderr.strip() or "nao consegui salvar a chave")
                    self.state = "done"; return key
                if res["status"] in ("denied", "unknown"):
                    self.state, self.error = "denied", "pedido recusado na outra estacao"; return None
                time.sleep(2)
            self.state, self.error = "timeout", "ninguem aprovou a tempo"
        except Exception as e:  # noqa: BLE001 — mostrado ao usuario
            self.state, self.error = "error", str(e)
        return None


def main(argv):
    if len(argv) >= 2 and argv[1] == "list":
        for s in discover():
            print(f"{s['station']:20} {s['ip']:15} {'com chave' if s['has_key'] else 'sem chave'}")
        return 0
    if len(argv) >= 2 and argv[1] == "fetch":
        target = argv[2] if len(argv) > 2 else None
        if not target:
            cands = [s for s in discover() if s["has_key"]]
            if not cands:
                print("nenhuma estacao com chave encontrada na rede"); return 1
            target = cands[0]["ip"]
            print(f"usando a estacao {cands[0]['station']} ({target})")
        f = Fetch(target)
        t = threading.Thread(target=f.run, daemon=True); t.start()
        shown = False
        while t.is_alive():
            if f.state == "waiting" and not shown:
                print(f"Pedido enviado. Na TV da outra estacao, aprove o codigo {f.code} (menu),\n"
                      f"ou la em Ajustes ligue 'Permitir compartilhar por 10 min'. Aguardando...")
                shown = True
            time.sleep(0.5)
        if f.state == "done":
            print("Chave instalada: escolha 'TV LASDPC' no app do Spotify."); return 0
        print(f"Falhou: {f.error}"); return 1
    print(__doc__.strip()); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
