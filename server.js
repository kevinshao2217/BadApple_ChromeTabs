// 極簡靜態伺服器（無相依套件）：node server.js [port]
// BroadcastChannel 需要所有分頁同源，所以要用 http://localhost 開，不能用 file://
const http = require('http');
const { spawn, execFile } = require('child_process');
const fs = require('fs');
const path = require('path');

const PORT = +process.argv[2] || 8760;
const ROOT = __dirname;
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.mp4': 'video/mp4',
  '.webm': 'video/webm', '.png': 'image/png', '.ico': 'image/x-icon', '.json': 'application/json' };

function resolve(urlPath) {
  const p = path.normalize(decodeURIComponent(urlPath)).replace(/^([\\/]\.\.)+/, '');
  let f = path.join(ROOT, p === path.sep || p === '/' ? 'master.html' : p);
  if (!f.startsWith(ROOT)) return null;
  // 資料夾裡沒有 bad_apple.mp4 時，借用上一層的
  if (path.basename(f) === 'bad_apple.mp4' && !fs.existsSync(f)) f = path.join(ROOT, '..', 'bad_apple.mp4');
  return fs.existsSync(f) && fs.statSync(f).isFile() ? f : null;
}

// ---------------- 生成／排列／關閉（只在 Windows、只聽 127.0.0.1）----------------
const PROFILE = path.join(ROOT, 'chrome-profile');
const FLAGS = [`--user-data-dir=${PROFILE}`, '--no-first-run', '--no-default-browser-check', '--disable-extensions',
  '--renderer-process-limit=12', '--disable-renderer-backgrounding', '--disable-background-timer-throttling',
  '--disable-backgrounding-occluded-windows', '--disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling,Translate'];

function chromePath() {
  const c = [process.env.PROGRAMFILES, process.env['PROGRAMFILES(X86)'], process.env.LOCALAPPDATA]
    .filter(Boolean).map(d => path.join(d, 'Google', 'Chrome', 'Application', 'chrome.exe'));
  return c.find(f => fs.existsSync(f)) || null;
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
const int = (v, lo, hi, d) => { const n = Math.round(Number(v)); return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : d; };

function ps(args) {
  return new Promise(res => execFile('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(ROOT, 'arrange.ps1'), '-Profile', PROFILE, ...args],
    { windowsHide: true, timeout: 30000 }, (err, out, errOut) => res(((out || '') + (errOut || '') + (err ? '\n' + err.message : '')).trim())));
}

function geom(o) {
  const w = int(o.width, -1, 20000, -1);
  return { pitch: int(o.pitch, 10, 400, 45), top: int(o.top, -2000, 20000, 0), left: int(o.left, -20000, 20000, 0),
    width: w < 400 ? -1 : w, height: int(o.height, -1, 20000, -1) };   // 寬度小於 400 視為「整個螢幕寬」
}
function arrangeArgs(o) {
  const g = geom(o);
  return ['-Pitch', String(g.pitch), '-Top', String(g.top), '-Left', String(g.left), '-Width', String(g.width), '-Height', String(g.height)];
}

let busy = false;
async function api(name, o) {
  if (process.platform !== 'win32') return { ok: false, msg: '生成視窗只支援 Windows。' };
  if (name === 'arrange') return { ok: true, msg: await ps(arrangeArgs(o)) };
  if (name === 'close') return { ok: true, msg: await ps(['-Close']) };
  if (name === 'spawn') {
    if (busy) return { ok: false, msg: '正在生成中，請稍候。' };
    const exe = chromePath();
    if (!exe) return { ok: false, msg: '找不到 chrome.exe（Program Files 或 LocalAppData 底下）。' };
    const rows = int(o.rows, 1, 64, 3), cols = int(o.cols, 1, 300, 40), from = int(o.from, 0, 63, 0);
    const base = `http://localhost:${PORT}`;
    busy = true;
    try {
      for (let r = from; r < from + rows; r++) {
        // Chrome 開多個網址時，作用中的是「第一個」分頁 → ROW 分頁放最前面，讓 ✕ 落在它身上、視窗標題變成 "ROW nn"
        const urls = [`${base}/row.html?r=${r}`];
        for (let c = 0; c < cols; c++) urls.push(`${base}/tile.html?r=${r}&c=${c}`);
        const g = geom(o);
        const pos = [`--window-position=${g.left},${g.top + r * g.pitch}`];
        if (g.width > 0) pos.push(`--window-size=${g.width},${g.height > 0 ? g.height : g.pitch}`);
        spawn(exe, [...FLAGS, ...pos, '--new-window', ...urls], { detached: true, stdio: 'ignore' }).unref();
        await sleep(int(o.delay, 200, 5000, 700));
        await ps([...arrangeArgs(o), '-Only', String(r)]);   // 開好立刻放到定位，不會先階梯式錯開
      }
      await sleep(500);
      const out = o.arrange === false ? '' : await ps(arrangeArgs(o));
      return { ok: true, msg: `已開 ${rows} 排 × ${cols} 個分頁（第 ${from}–${from + rows - 1} 排）。\n${out}` };
    } finally { busy = false; }
  }
  return { ok: false, msg: '未知的指令' };
}

const VERSION = 3;
http.createServer((req, res) => {
  if (req.url === '/api/version') { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ version: VERSION })); return; }
  const m = /^\/api\/(spawn|arrange|close)$/.exec(req.url.split('?')[0]);
  if (m && req.method === 'POST') {
    let body = '';
    req.on('data', d => { body += d; if (body.length > 1e5) req.destroy(); });
    req.on('end', async () => {
      let o = {};
      try { o = JSON.parse(body || '{}'); } catch (e) { /* 空物件 */ }
      const out = await api(m[1], o).catch(e => ({ ok: false, msg: e.message }));
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(out));
    });
    return;
  }
  const f = resolve(req.url.split('?')[0]);
  if (!f) { res.writeHead(404); res.end('not found'); return; }
  const size = fs.statSync(f).size;
  const type = MIME[path.extname(f).toLowerCase()] || 'application/octet-stream';
  const range = req.headers.range && /bytes=(\d*)-(\d*)/.exec(req.headers.range);
  if (range) {
    const start = range[1] ? +range[1] : 0, end = range[2] ? Math.min(+range[2], size - 1) : size - 1;
    res.writeHead(206, { 'Content-Type': type, 'Content-Range': `bytes ${start}-${end}/${size}`, 'Accept-Ranges': 'bytes',
      'Content-Length': end - start + 1, 'Cache-Control': 'no-cache' });
    if (req.method === 'HEAD') return res.end();
    fs.createReadStream(f, { start, end }).pipe(res);
  } else {
    res.writeHead(200, { 'Content-Type': type, 'Content-Length': size, 'Accept-Ranges': 'bytes', 'Cache-Control': 'no-cache' });
    if (req.method === 'HEAD') return res.end();
    fs.createReadStream(f).pipe(res);
  }
}).listen(PORT, '127.0.0.1', () => console.log(`tab matrix server: http://localhost:${PORT}/master.html`));
