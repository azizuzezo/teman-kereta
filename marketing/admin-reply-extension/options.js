import {DEFAULTS} from './replies.js';

const keys = Object.keys(DEFAULTS);
const $ = id => document.getElementById(id);
const status = (t, ok = true) => { const e = $('status'); e.textContent = t; e.className = ok ? 'ok' : 'bad'; };

async function load() {
  const s = {...DEFAULTS, ...(await chrome.storage.local.get(keys))};
  for (const k of keys) { const el = $(k); if (!el) continue; if (el.type === 'checkbox') el.checked = !!s[k]; else el.value = s[k] ?? ''; }
}

function read() {
  const s = {};
  for (const k of keys) { const el = $(k); if (!el) continue; s[k] = el.type === 'checkbox' ? el.checked : el.value.trim(); }
  return s;
}

// The service worker needs host permission for the AI origin to call it without CORS trouble.
async function ensureOrigin(baseUrl) {
  // Called straight from the click (no await before it) so Chrome keeps the user gesture.
  return chrome.permissions.request({origins: [new URL(baseUrl).origin + '/*']});
}

$('save').onclick = async () => {
  const s = read();
  if (s.aiEnabled) {
    if (!s.baseUrl || !s.apiKey || !s.model) return status('Isi Base URL, API key, dan model dulu.', false);
    try { if (!(await ensureOrigin(s.baseUrl))) return status('Izin akses ke Base URL ditolak.', false); }
    catch { return status('Base URL tidak valid.', false); }
  }
  await chrome.storage.local.set(s);
  status('Tersimpan ✓');
};

$('test').onclick = async () => {
  const s = read();
  if (!s.baseUrl || !s.apiKey || !s.model) return status('Isi Base URL, API key, dan model dulu.', false);
  try { if (!(await ensureOrigin(s.baseUrl))) return status('Izin akses ke Base URL ditolak.', false); } catch { return status('Base URL tidak valid.', false); }
  await chrome.storage.local.set({...s, aiEnabled: true}); $('aiEnabled').checked = true;
  status('Menguji…');
  const r = await chrome.runtime.sendMessage({type: 'tk-generate', comment: 'kemarin ketiduran di krl, bangun-bangun udah sampai bogor 😭', context: {platform: 'Tes'}});
  if (r.source === 'ai') status('AI tersambung ✓ Contoh: ' + r.replies[0]);
  else status(r.note || 'AI tidak menjawab, memakai template.', false);
};

load();
