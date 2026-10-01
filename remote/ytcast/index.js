// ============================================================
// lasdpc-ytcast — receptor de cast do YouTube (protocolo Lounge/DIAL).
// O app do YouTube no celular ve a Pi como uma TV; ao transmitir, recebemos o
// ID do video e tocamos no mpv com decode por HARDWARE (--vo=dmabuf-wayland
// --hwdec=v4l2m2m, igual ao lasdpc-mpv). Controle (play/pause/seek/proximo/
// volume) chega do celular e e aplicado no mpv via IPC (--input-ipc-server).
// Enquanto nada toca, a tela mostra ytcast.html (kiosk); o mpv so existe
// durante a reproducao e, ao terminar/parar, some e revela a tela ociosa.
// ============================================================
import { spawn } from 'node:child_process';
import net from 'node:net';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import YouTubeCastReceiver, { Player, Constants } from 'yt-cast-receiver';

const HOME = os.homedir();
const CONF_DIR = path.join(HOME, '.config', 'lasdpc');
const CODE_FILE = path.join(CONF_DIR, 'ytcast_code');
const STATE_FILE = path.join(CONF_DIR, 'ytcast_state');
const STATUS_FILE = path.join(CONF_DIR, 'ytcast_status.json');
const LOG_FILE = path.join(CONF_DIR, 'ytcast.log');
const STORE_FILE = path.join(CONF_DIR, 'ytcast_store.json');
const SOCK = '/tmp/lasdpc-ytcast-mpv.sock';
const YTDLP = '/usr/local/bin/yt-dlp';
const MAXH = process.env.LASDPC_YTCAST_MAXHEIGHT || process.env.LASDPC_TV_MAXHEIGHT || '1080';
const QUALITY = process.env.LASDPC_YTCAST_QUALITY || '1080';
const VIDEO_ZOOM = process.env.LASDPC_YTCAST_VIDEO_ZOOM || '';
const VIDEO_PAN_X = process.env.LASDPC_YTCAST_VIDEO_PAN_X || '';
const VIDEO_PAN_Y = process.env.LASDPC_YTCAST_VIDEO_PAN_Y || '';
const AUDIO = 'bestaudio[ext=m4a]/bestaudio';
const FMT_MAX = `bestvideo[vcodec^=avc1][height<=${MAXH}]+${AUDIO}/best[vcodec^=avc1][height<=${MAXH}]/best[height<=${MAXH}]`;
const FMT_1080 = [
  `best[vcodec^=avc1][height>=1080][height<=${MAXH}]`,
  `bestvideo[vcodec^=avc1][height>=1080][height<=${MAXH}]+${AUDIO}`,
  `best[height>=1080][height<=${MAXH}]`,
  `bestvideo[height>=1080][height<=${MAXH}]+${AUDIO}`,
].join('/');
const FMT_SMOOTH = [
  'best[vcodec^=avc1][height<=720]',
  `best[vcodec^=avc1][height<=${MAXH}][fps<=30]`,
  `bestvideo[vcodec^=avc1][height<=720]+${AUDIO}`,
  `bestvideo[vcodec^=avc1][height<=${MAXH}][fps<=30]+${AUDIO}`,
  `bestvideo[vcodec^=avc1][height<=${MAXH}]+${AUDIO}`,
  `best[vcodec^=avc1][height<=${MAXH}]`,
  `best[height<=720]`,
].join('/');
const FMT = QUALITY === 'max' ? FMT_MAX : QUALITY === 'smooth' ? FMT_SMOOTH : FMT_1080;

try { fs.mkdirSync(CONF_DIR, { recursive: true }); } catch { /* ok */ }
let currentStatus = 'starting';
const log = (...a) => {
  const line = `${new Date().toISOString()} ${a.map((x) => typeof x === 'string' ? x : JSON.stringify(x)).join(' ')}`;
  console.log(line);
  try { fs.appendFileSync(LOG_FILE, line + '\n'); } catch { /* ok */ }
};
const writeCode = (code) => { try { code ? fs.writeFileSync(CODE_FILE, code) : fs.rmSync(CODE_FILE, { force: true }); } catch { /* ok */ } };
const writeState = (state) => { try { state ? fs.writeFileSync(STATE_FILE, state) : fs.rmSync(STATE_FILE, { force: true }); } catch { /* ok */ } };
const writeStatus = (status, detail = {}) => {
  currentStatus = status;
  try { fs.writeFileSync(STATUS_FILE, JSON.stringify({ status, ts: new Date().toISOString(), ...detail })); } catch { /* ok */ }
};

class FileDataStore {
  setLogger(logger) { this.logger = logger; }
  _read() {
    try { return JSON.parse(fs.readFileSync(STORE_FILE, 'utf8')); } catch { return {}; }
  }
  _write(data) {
    fs.writeFileSync(STORE_FILE, JSON.stringify(data));
  }
  async get(key) {
    const data = this._read();
    return Object.prototype.hasOwnProperty.call(data, key) ? data[key] : undefined;
  }
  async set(key, value) {
    const data = this._read();
    data[key] = value;
    this._write(data);
  }
  async clear() {
    try { fs.rmSync(STORE_FILE, { force: true }); } catch { /* ok */ }
  }
}

// ---------- controlador do mpv (spawn por video + IPC) ----------
class Mpv {
  constructor() { this.proc = null; this.sock = null; this.reqId = 1; this.pending = new Map();
    this.duration = 0; this.position = 0; this.volume = 100; this.muted = false; this.onEof = null; this.swFallback = false; }

  _flags(url, position) {
    const vo = this.swFallback ? '--vo=gpu' : '--vo=dmabuf-wayland';
    const hw = this.swFallback ? '--hwdec=no' : '--hwdec=v4l2m2m';
    const a = ['--no-terminal', '--fullscreen', vo, hw,
      '--msg-level=all=warn,ytdl_hook=info,vo=info,hwdec=info',
      `--script-opts=ytdl_hook-ytdl_path=${YTDLP}`, `--ytdl-format=${FMT}`,
      '--force-window=yes', '--no-border', '--autofit=100%x100%', '--geometry=100%x100%+0+0',
      '--video-align-x=0', '--video-align-y=0', '--panscan=1',
      '--framedrop=vo', '--sub-auto=fuzzy', '--slang=pt-BR,pt,en',
      '--keep-open=no', '--idle=no', `--input-ipc-server=${SOCK}`, '--volume=' + this.volume];
    if (VIDEO_ZOOM) a.push('--video-zoom=' + VIDEO_ZOOM);
    if (VIDEO_PAN_X) a.push('--video-pan-x=' + VIDEO_PAN_X);
    if (VIDEO_PAN_Y) a.push('--video-pan-y=' + VIDEO_PAN_Y);
    if (this.muted) a.push('--mute=yes');
    if (position && position > 0) a.push('--start=' + Math.floor(position));
    a.push(url);
    return a;
  }

  async play(url, position) {
    writeState('loading');
    writeStatus('loading', { message: 'Video recebido; preparando player...', url });
    await this.stop({ preserveState: true });
    this.swFallback = false;
    return this._spawn(url, position);
  }

  _spawn(url, position) {
    try { fs.rmSync(SOCK, { force: true }); } catch { /* ok */ }
    writeState('loading');
    writeStatus('loading', { message: 'Abrindo video no mpv...', url });
    log('mpv spawn', this.swFallback ? '(software)' : '(hw)', url, '@', position || 0);
    const startedAt = Date.now();
    this.proc = spawn('mpv', this._flags(url, position), { stdio: ['ignore', 'pipe', 'pipe'] });
    const logPipe = (name, stream) => {
      let buf = '';
      stream.on('data', (d) => {
        buf += d.toString();
        let i;
        while ((i = buf.indexOf('\n')) >= 0) {
          const line = buf.slice(0, i).trimEnd();
          buf = buf.slice(i + 1);
          if (line.trim()) log(`mpv ${name}:`, line);
        }
      });
      stream.on('end', () => { if (buf.trim()) log(`mpv ${name}:`, buf.trimEnd()); });
    };
    logPipe('stdout', this.proc.stdout);
    logPipe('stderr', this.proc.stderr);
    this.proc.on('error', (e) => {
      log('mpv spawn error:', e?.message || e);
      writeState(null);
      writeStatus('error', { message: e?.message || String(e) });
    });
    this.proc.on('exit', (code) => {
      this.proc = null; this._closeSock();
      // Falha rapida no caminho HW -> tenta software uma vez.
      if (!this.swFallback && code && code !== 0 && (Date.now() - startedAt) < 6000) {
        log('mpv HW falhou (code=' + code + '); fallback software'); this.swFallback = true;
        this._spawn(url, position); return;
      }
      writeState(null);
      writeStatus(code === 0 || code === null ? 'idle' : 'error', { message: `mpv saiu (code=${code})` });
    });
    this._connect();
    return true;
  }

  _connect(tries = 0) {
    const s = net.connect(SOCK);
    s.on('connect', () => { this.sock = s; writeState('playing'); writeStatus('playing', { message: 'Tocando no mpv' }); this._poll(); });
    s.on('error', () => { if (tries < 40 && this.proc) setTimeout(() => this._connect(tries + 1), 100); });
    let buf = '';
    s.on('data', (d) => {
      buf += d.toString();
      let i;
      while ((i = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, i); buf = buf.slice(i + 1);
        if (!line.trim()) continue;
        let msg; try { msg = JSON.parse(line); } catch { continue; }
        if (msg.request_id && this.pending.has(msg.request_id)) {
          this.pending.get(msg.request_id)(msg.error === 'success' ? msg.data : null);
          this.pending.delete(msg.request_id);
        } else if (msg.event === 'end-file') {
          if (msg.reason === 'eof' && this.onEof) this.onEof();
        }
      }
    });
  }

  _poll() { // mantem position/duration atualizados p/ reportar ao celular
    const tick = async () => {
      if (!this.sock) return;
      const p = await this._get('time-pos'); if (typeof p === 'number') this.position = p;
      const d = await this._get('duration'); if (typeof d === 'number') this.duration = d;
    };
    clearInterval(this._timer); this._timer = setInterval(tick, 1000); tick();
  }

  _send(obj) { try { if (this.sock) this.sock.write(JSON.stringify(obj) + '\n'); } catch { /* ok */ } }
  _get(prop) {
    return new Promise((res) => {
      if (!this.sock) return res(null);
      const id = this.reqId++; this.pending.set(id, res);
      this._send({ command: ['get_property', prop], request_id: id });
      setTimeout(() => { if (this.pending.has(id)) { this.pending.delete(id); res(null); } }, 800);
    });
  }
  _set(prop, val) { this._send({ command: ['set_property', prop, val] }); }

  pause() { this._set('pause', true); return true; }
  resume() { this._set('pause', false); return true; }
  seek(pos) { this._send({ command: ['seek', pos, 'absolute'] }); this.position = pos; return true; }
  setVolume(level, muted) { this.volume = level; this.muted = muted; this._set('volume', level); this._set('mute', !!muted); return true; }
  getVolume() { return { level: this.volume, muted: this.muted }; }
  getPosition() { return this.position || 0; }
  getDuration() { return this.duration || 0; }

  _closeSock() { clearInterval(this._timer); if (this.sock) { try { this.sock.destroy(); } catch { /* ok */ } this.sock = null; } }
  async stop(options = {}) {
    this._closeSock();
    if (this.proc) { const p = this.proc; this.proc = null; try { p.kill('SIGTERM'); } catch { /* ok */ }
      await new Promise((r) => { const t = setTimeout(() => { try { p.kill('SIGKILL'); } catch { /* ok */ } r(); }, 1500); p.on('exit', () => { clearTimeout(t); r(); }); }); }
    this.position = 0; this.duration = 0;
    if (!options.preserveState) {
      writeState(null);
      writeStatus('idle', { message: 'Aguardando video do YouTube' });
    }
    return true;
  }
}

// ---------- Player do yt-cast-receiver sobre o mpv ----------
class MpvPlayer extends Player {
  constructor() { super(); this.mpv = new Mpv(); this.mpv.onEof = () => { log('video terminou -> proximo'); this.next().catch(() => {}); }; }
  async doPlay(video, position) {
    const url = `https://www.youtube.com/watch?v=${video.id}`;
    log('doPlay', video.id, '@', position || 0);
    writeStatus('loading', { message: 'Video recebido do celular; resolvendo link...', videoId: video.id });
    return this.mpv.play(url, position || 0);
  }
  async doPause() { log('doPause'); return this.mpv.pause(); }
  async doResume() { log('doResume'); return this.mpv.resume(); }
  async doStop() { log('doStop'); return this.mpv.stop(); }
  async doSeek(position) { log('doSeek', position); return this.mpv.seek(position); }
  async doSetVolume(volume) { return this.mpv.setVolume(volume.level, volume.muted); }
  async doGetVolume() { return this.mpv.getVolume(); }
  async doGetPosition() { return this.mpv.getPosition(); }
  async doGetDuration() { return this.mpv.getDuration(); }
}

// ---------- bootstrap ----------
const player = new MpvPlayer();
player.on('state', (data) => {
  const cur = data?.current || {};
  log('player state', { status: cur.status, video: cur.queue?.current?.id, position: cur.position, duration: cur.duration });
});
writeStatus('starting', { message: 'Iniciando receiver YouTube Cast' });
// DIAL na 3232: a 3000 (padrao) e do docker-proxy (Grafana dos dashboards).
// Persistimos o app.pid sem node-persist. O dataStore padrao falhava no Pi com
// caminho indefinido; dataStore:false troca o pid a cada restart e pode quebrar
// pareamentos manuais do app do YouTube.
const receiver = new YouTubeCastReceiver(player, {
  device: { name: 'TV LASDPC', screenName: 'YouTube na TV LASDPC', brand: 'LASDPC', model: 'Pi4-Station' },
  dial: { port: 3232, prefix: '/ytcr' },
  app: { enableAutoplayOnConnect: true },
  dataStore: new FileDataStore(),
  logLevel: Constants.LOG_LEVELS.INFO,
});

receiver.on('senderConnect', (s) => { log('celular conectado:', s?.name || '?'); writeCode(null); writeStatus('connected', { message: 'Celular conectado. Escolha um video no YouTube.', sender: s?.name || '?' }); });
receiver.on('senderDisconnect', (s) => { log('celular desconectou:', s?.name || '?'); writeStatus('idle', { message: 'Celular desconectado. Aguardando conexao.' }); });
receiver.on('error', (e) => { log('erro receiver:', e?.message || e); writeStatus('error', { message: e?.message || String(e) }); });

// Codigo de pareamento manual ("Inserir codigo" no app) -> mostrado em ytcast.html
try {
  const svc = receiver.getPairingCodeRequestService();
  svc.on('response', (code) => {
    log('codigo de pareamento:', code);
    writeCode(code);
    if (['starting', 'idle', 'unknown', 'stopped'].includes(currentStatus)) {
      writeStatus('idle', { message: 'Aguardando conexao do celular', code });
    }
  });
  svc.on('error', (e) => { log('erro codigo pareamento:', e?.message || e); });
  svc.start();
} catch (e) { log('servico de codigo indisponivel:', e?.message || e); }

async function shutdown() { try { writeCode(null); writeState(null); writeStatus('stopped', { message: 'Receiver parado' }); await player.mpv.stop(); await receiver.stop(); } catch { /* ok */ } process.exit(0); }
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

receiver.start().then(() => { log('receiver no ar como "TV LASDPC"'); writeStatus('idle', { message: 'Aguardando conexao do YouTube' }); }).catch((e) => { log('falha ao iniciar:', e); writeStatus('error', { message: e?.message || String(e) }); process.exit(1); });
