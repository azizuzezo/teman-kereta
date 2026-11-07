// Floating reply panel. Opens by itself when the admin clicks a comment's "Balas"/"Reply" button,
// reads that comment (author + text) and the post caption, and drafts replies.
// It never clicks "send": it only fills the reply box the admin focused.
(() => {
  if (window.__tkAdminPanel) return; window.__tkAdminPanel = true;

  const PLATFORMS = {'instagram.com': 'Instagram', 'threads.com': 'Threads', 'threads.net': 'Threads', 'tiktok.com': 'TikTok',
    'youtube.com': 'YouTube', 'facebook.com': 'Facebook', 'x.com': 'X'};
  const platform = Object.entries(PLATFORMS).find(([d]) => location.hostname.endsWith(d))?.[1] || location.hostname;

  const REPLY_RE = /^(balas|balasan|reply|replies|balas komentar|reply to comment|tulis balasan|jawab)$/i;
  const UI_RE = /^(balas|reply|suka|like|likes|disukai|lihat terjemahan|see translation|terjemahkan|translate|lihat balasan.*|view replies.*|sembunyikan balasan.*|hide replies.*|edit|hapus|delete|laporkan|report|pin|disematkan|pinned|penulis|creator|author|ikuti|follow|mengikuti|following|more|lainnya|\.\.\.|·|•|\d+|\d+([.,]\d+)?\s*(rb|jt|k|m)?\s*(suka|likes?|balasan|replies)?|\d+\s*(d|dtk|detik|m|mnt|menit|h|j|jam|hari|mg|mgg|minggu|w|bln|bulan|thn|tahun|y)(\s*(lalu|ago))?|(baru saja|just now|edited|diedit))$/i;

  // ---------- reading the page ----------
  const isEditable = el => el && (el.isContentEditable || el.tagName === 'TEXTAREA' || (el.tagName === 'INPUT' && /text|search/.test(el.type)));
  const labelOf = el => (el.getAttribute?.('aria-label') || (el.innerText || '').trim()).trim();
  const isReplyButton = el => {
    if (!(el instanceof Element)) return false;
    const l = labelOf(el); if (!l || l.length > 24) return false;
    return REPLY_RE.test(l);
  };
  const countReplyButtons = el => [...el.querySelectorAll('button,[role=button],span,a,div,svg')].filter(x => x.childElementCount <= 2 && isReplyButton(x)).length;

  function textLines(el) {
    const out = [];
    const walk = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, {acceptNode: n => {
      const p = n.parentElement; if (!p) return NodeFilter.FILTER_REJECT;
      if (p.closest('button,[role=button],time,svg,script,style,[aria-hidden=true]')) return NodeFilter.FILTER_REJECT;
      return n.nodeValue.trim() ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
    }});
    for (let n; (n = walk.nextNode());) out.push({t: n.nodeValue.trim(), a: n.parentElement.closest('a')});
    return out;
  }

  // The smallest ancestor of the reply button that holds one comment: real text, and only one reply button.
  function readComment(button) {
    let el = button;
    for (let i = 0; i < 14 && el && el !== document.body; i++) {
      el = el.parentElement; if (!el) break;
      const lines = textLines(el).filter(l => !UI_RE.test(l.t));
      if (!lines.length) continue;
      if (countReplyButtons(el) > 1) break;          // went past the single comment
      const author = (lines.find(l => l.a && l.t.length <= 40 && !/\s{2,}/.test(l.t)) || {}).t || '';
      const body = lines.filter(l => !(l.a && l.t === author)).map(l => l.t).join(' ').replace(/\s+/g, ' ').trim();
      if (body.length >= 2) { var best = {author: author.replace(/^@/, ''), text: body, el, video: videoNear(el)}; }
      if (body.length >= 12) return best;
    }
    return typeof best !== 'undefined' ? best : null;
  }

  // Comment-management pages mix comments from many videos: read the video next to the comment.
  const MULTI = /studio\.youtube\.com|tiktok\.com\/tiktokstudio|business\.facebook\.com|facebook\.com\/(professional_dashboard|latest\/inbox)|instagram\.com\/(direct|accounts)/.test(location.href);
  function videoNear(commentEl) {
    let el = commentEl;
    for (let i = 0; i < 10 && el && el !== document.body; i++) {
      el = el.parentElement; if (!el) break;
      const cand = [
        ...[...el.querySelectorAll('#video-title,[id*=video-title],[class*=video-title],[class*=VideoTitle],[data-e2e*=video-title],[data-e2e*=desc]')].map(e => e.innerText || e.getAttribute('title')),
        ...[...el.querySelectorAll('a[title],[aria-label][href*=watch],[aria-label][href*=video],[aria-label][href*="/reel"],[aria-label][href*="/p/"]')].map(e => e.getAttribute('title') || e.getAttribute('aria-label')),
        ...[...el.querySelectorAll('img[alt]')].map(e => e.alt),
      ].map(t => (t || '').replace(/\s+/g, ' ').trim()).filter(t => t.length > 8 && !/^(foto profil|profile picture|avatar|gambar profil)/i.test(t) && !t.includes(commentEl.innerText?.slice(0, 20) || '§'));
      if (cand.length) return cand.sort((a, b) => b.length - a.length)[0].slice(0, 400);
    }
    return '';
  }

  function postContext() {
    const pick = sels => { for (const s of sels) { const e = document.querySelector(s); const t = e && (e.innerText || e.content || '').trim(); if (t && t.length > 8) return t; } return ''; };
    const meta = n => document.querySelector(`meta[property="${n}"],meta[name="${n}"]`)?.content?.trim() || '';
    let t = '';
    if (platform === 'YouTube') t = [pick(['ytd-watch-metadata #title h1', '#title h1', 'h1.title']), pick(['#description-inline-expander', '#description'])].filter(Boolean).join(' — ');
    if (platform === 'TikTok') t = pick(['[data-e2e="browse-video-desc"]', '[data-e2e="video-desc"]', 'h1[data-e2e]']);
    if (platform === 'Instagram') t = pick(['article h1', 'div[role=dialog] h1', 'main h1']);
    if (!t) { const d = meta('og:description') || meta('description'); const m = d.match(/[:"“]\s*["“]?([\s\S]{8,})["”]?\s*$/); t = (m ? m[1] : d) || meta('og:title') || document.title; }
    return t.replace(/\s+/g, ' ').slice(0, 600);
  }

  // ---------- panel ----------
  let lastEditable = null, current = {author: '', text: ''}, autoCtx = '';
  const host = document.createElement('div');
  host.style.cssText = 'position:fixed;right:20px;bottom:20px;z-index:2147483647;display:none';
  const root = host.attachShadow({mode: 'open'});
  document.addEventListener('focusin', e => { const el = e.composedPath()[0]; if (isEditable(el) && el.getRootNode() !== root) lastEditable = el; }, true);
  const icon = chrome.runtime.getURL('icons/icon48.png');
  root.innerHTML = `
  <style>
    :host{all:initial}
    *{box-sizing:border-box;font-family:'Plus Jakarta Sans',Inter,system-ui,-apple-system,'Segoe UI',sans-serif;-webkit-font-smoothing:antialiased}
    .p{--ink:#0f2236;--mute:#64768a;--line:#e6ecf2;--bg:#f6f9fc;--brand:#2f74bb;--navy:#0f2236;--warm:#e8741f;
       width:400px;max-height:84vh;display:flex;flex-direction:column;background:#fff;color:var(--ink);border-radius:20px;
       box-shadow:0 24px 60px -12px rgba(15,34,54,.35),0 0 0 1px rgba(15,34,54,.06);overflow:hidden;animation:in .22s cubic-bezier(.2,.8,.2,1)}
    @keyframes in{from{opacity:0;transform:translateY(12px) scale(.98)}to{opacity:1;transform:none}}
    header{display:flex;align-items:center;gap:10px;padding:13px 14px 13px 16px;background:linear-gradient(135deg,#0f2236,#183a5e);color:#fff;cursor:grab}
    header img{width:26px;height:26px;border-radius:7px;background:#fff;padding:2px}
    header .t{flex:1;line-height:1.15}header .t b{display:block;font-size:14px;font-weight:750;letter-spacing:-.01em}
    header .t span{font-size:11.5px;color:#a9c0d6}
    .ib{width:30px;height:30px;border:0;border-radius:9px;background:rgba(255,255,255,.1);color:#fff;cursor:pointer;display:grid;place-items:center;transition:.15s}
    .ib:hover{background:rgba(255,255,255,.2)}
    .scroll{overflow:auto;padding:14px 16px 4px;display:grid;gap:12px;align-content:start}
    .cmt{background:var(--bg);border:1px solid var(--line);border-radius:14px;padding:11px 12px;display:grid;gap:7px}
    .who{display:flex;align-items:center;gap:8px;font-size:13px;font-weight:750}
    .av{width:26px;height:26px;border-radius:50%;background:linear-gradient(135deg,#2f74bb,#6aa6e0);color:#fff;display:grid;place-items:center;font-size:12px;font-weight:800;text-transform:uppercase}
    .who small{font-weight:500;color:var(--mute);font-size:12px}
    textarea{width:100%;resize:none;border:0;background:transparent;padding:0;font-size:14px;line-height:1.45;color:var(--ink);outline:none;field-sizing:content;min-height:44px;max-height:120px}
    textarea::placeholder{color:#94a3b3}
    details.ctx{border:1px solid var(--line);border-radius:12px;padding:0 11px}
    details.ctx summary{list-style:none;cursor:pointer;display:flex;align-items:center;gap:8px;padding:9px 0;font-size:12px;font-weight:700;color:var(--mute)}
    details.ctx summary::-webkit-details-marker{display:none}
    details.ctx summary::after{content:'';margin-left:auto;width:7px;height:7px;border-right:2px solid #94a3b3;border-bottom:2px solid #94a3b3;transform:rotate(45deg);transition:.15s}
    details.ctx[open] summary::after{transform:rotate(-135deg)}
    details.ctx #ctx{font-size:12.5px;color:#3b4c5e;padding-bottom:10px;min-height:40px}
    #ctxsrc{font-weight:500;color:#94a3b3}
    .go{display:flex;gap:10px;align-items:center}
    .btn{border:0;border-radius:11px;padding:9px 14px;font-size:13px;font-weight:700;cursor:pointer;transition:.15s;display:inline-flex;align-items:center;gap:7px;font-family:inherit}
    .btn.pri{background:var(--brand);color:#fff;box-shadow:0 6px 14px -6px rgba(47,116,187,.7)}.btn.pri:hover{background:#2766a8}
    .btn.gh{background:#eef3f8;color:var(--ink)}.btn.gh:hover{background:#e3ebf3}
    .btn:disabled{opacity:.55;cursor:default}
    .chips{display:flex;gap:6px;align-items:center;flex-wrap:wrap;min-height:0}
    .tag{font-size:11.5px;font-weight:750;padding:4px 10px;border-radius:999px;background:#e8f1fb;color:var(--brand);display:inline-flex;align-items:center;gap:6px}
    .tag::before{content:'';width:6px;height:6px;border-radius:50%;background:currentColor}
    .tag.sell{background:#fff1e4;color:#c25a0c}.tag.no{background:#eef1f5;color:#5a6b7c}
    .src{font-size:10.5px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;padding:3px 7px;border-radius:6px;background:#0f2236;color:#fff}
    .src.tpl{background:#c9d3de;color:#3b4c5e}
    .intent{font-size:12.5px;line-height:1.4;color:#3b4c5e;background:#f3f7fb;border-left:3px solid var(--brand);border-radius:0 10px 10px 0;padding:8px 10px}
    .intent b{color:var(--brand);font-weight:750}
    .note{font-size:12px;line-height:1.4;color:#7a5200;background:#fff6dc;border-radius:10px;padding:8px 10px}
    .note.ok{background:#e6f6ec;color:#1d6b3c}
    .out{display:grid;gap:10px}
    .s{position:relative;border:1px solid var(--line);border-radius:14px;padding:12px 12px 10px;display:grid;gap:9px;background:#fff;transition:.15s;animation:in .25s both}
    .s:hover{border-color:#c9d8e8;box-shadow:0 8px 20px -12px rgba(15,34,54,.35)}
    .s .n{position:absolute;top:-9px;left:12px;font-size:10.5px;font-weight:800;background:var(--navy);color:#fff;border-radius:999px;padding:2px 9px}
    .s p{margin:0;font-size:14px;line-height:1.5;white-space:pre-wrap;outline:none;border-radius:6px}
    .s p:focus{background:#f6f9fc;box-shadow:0 0 0 4px #f6f9fc}
    .s .ft{display:flex;align-items:center;gap:8px}
    .s .cnt{font-size:11px;color:#94a3b3;margin-right:auto}
    .skel{border:1px solid var(--line);border-radius:14px;padding:14px;display:grid;gap:8px}
    .skel i{display:block;height:10px;border-radius:6px;background:linear-gradient(90deg,#eef2f6 25%,#f8fafc 50%,#eef2f6 75%);background-size:200% 100%;animation:sh 1.1s infinite}
    @keyframes sh{to{background-position:-200% 0}}
    footer{padding:10px 16px 13px;font-size:11.5px;color:var(--mute);display:flex;gap:7px;align-items:center;border-top:1px solid var(--line);margin-top:8px;background:#fbfdff}
    svg{width:15px;height:15px;stroke:currentColor;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
    .ib svg{width:16px;height:16px}
  </style>
  <div class="p" id="p">
    <header id="drag">
      <img src="${icon}" alt="">
      <div class="t"><b>Admin Teman Kereta</b><span>${platform} · saran balasan</span></div>
      <button class="ib" id="opt" title="Pengaturan"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg></button>
      <button class="ib" id="x" title="Tutup"><svg viewBox="0 0 24 24"><path d="M18 6 6 18M6 6l12 12"/></svg></button>
    </header>
    <div class="scroll">
      <div class="cmt">
        <div class="who"><span class="av" id="av">?</span><span id="who">Komentar</span><small id="whoSub"></small></div>
        <textarea id="c" rows="2" placeholder="Klik sebuah komentar, atau tempel teksnya di sini…"></textarea>
      </div>
      <details class="ctx" id="ctxbox">
        <summary>Konteks video <span id="ctxsrc"></span></summary>
        <textarea id="ctx" rows="2" placeholder="Judul/caption video (otomatis, boleh diedit)"></textarea>
      </details>
      <div class="go"><button class="btn pri" id="go">Buat saran balasan</button><div class="chips" id="topic"></div></div>
      <div class="intent" id="intent" hidden></div>
      <div id="note"></div>
      <div class="out" id="out"></div>
    </div>
    <footer><svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>Tidak pernah mengirim otomatis. Kamu yang cek dan kirim.</footer>
  </div>`;
  document.documentElement.appendChild(host);
  const $ = id => root.getElementById(id);
  const ICON = {
    copy: '<svg viewBox="0 0 24 24"><rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h8"/></svg>',
    check: '<svg viewBox="0 0 24 24"><path d="M20 6 9 17l-5-5"/></svg>',
    paste: '<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12l7 7 7-7"/></svg>',
  };
  const ctxKey = 'tkctx:' + location.hostname + location.pathname;

  function insert(text) {
    const el = lastEditable;
    if (!el || !document.contains(el)) { navigator.clipboard.writeText(text); toast('Kolom balasan belum terpilih. Teks disalin, tinggal tempel (Ctrl+V).'); return; }
    el.focus();
    if (el.isContentEditable) {
      const sel = window.getSelection(); sel.selectAllChildren(el); sel.collapseToEnd();
      document.execCommand('insertText', false, text);   // keeps React/Lexical editors in sync, keeps the "@user " prefill
    } else {
      const setter = Object.getOwnPropertyDescriptor(el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype, 'value').set;
      setter.call(el, (el.value && !el.value.endsWith(' ') ? el.value + ' ' : el.value || '') + text);
      el.dispatchEvent(new Event('input', {bubbles: true}));
    }
    toast('Ditempel ke kolom balasan. Cek dulu, lalu kirim sendiri.', true);
  }
  const toast = (t, ok) => { $('note').innerHTML = `<div class="note${ok ? ' ok' : ''}">${t.replace(/</g, '&lt;')}</div>`; };

  async function generate() {
    const comment = $('c').value.trim();
    if (!comment) { toast('Isi teks komentarnya dulu.'); return; }
    // Remember the context only when the admin actually changed it (per video URL).
    const ctxNow = $('ctx').value.trim();
    if (!MULTI && ctxNow && ctxNow !== autoCtx) try { chrome.storage.local.set({[ctxKey]: ctxNow}); } catch {}
    $('go').disabled = true; $('go').textContent = 'Menyusun…'; $('note').innerHTML = ''; $('intent').hidden = true; $('topic').innerHTML = '';
    $('out').innerHTML = '<div class="skel"><i style="width:92%"></i><i style="width:78%"></i><i style="width:40%"></i></div>'.repeat(3);
    try {
      const r = await chrome.runtime.sendMessage({type: 'tk-generate', comment,
        context: {platform, post: $('ctx').value.trim(), author: current.author, url: location.href}});
      const cls = r.topic.id === 'sensitif' || !r.topic.sell ? 'no' : (r.topic.id === 'bablas' ? 'sell' : '');
      $('topic').innerHTML = `<span class="tag ${cls}">${r.topic.label || r.topic.id}${r.topic.id === 'bablas' ? ' · soft selling' : ''}</span><span class="src ${r.source === 'ai' ? '' : 'tpl'}">${r.source === 'ai' ? 'AI' : 'Template'}</span>`;
      $('intent').hidden = !r.intent; $('intent').innerHTML = r.intent ? '<b>Dipahami:</b> ' + r.intent.replace(/</g, '&lt;') : '';
      $('out').innerHTML = '';
      if (r.note) toast(r.note);
      r.replies.forEach((text, k) => {
        const box = document.createElement('div'); box.className = 's'; box.style.animationDelay = k * 70 + 'ms';
        const n = document.createElement('span'); n.className = 'n'; n.textContent = 'Opsi ' + (k + 1);
        const p = document.createElement('p'); p.textContent = text; p.contentEditable = 'true'; p.title = 'Klik untuk mengedit';
        const cnt = document.createElement('span'); cnt.className = 'cnt';
        const upd = () => { cnt.textContent = p.textContent.trim().length + ' karakter'; }; upd(); p.addEventListener('input', upd);
        const ft = document.createElement('div'); ft.className = 'ft';
        const copy = document.createElement('button'); copy.className = 'btn gh'; copy.innerHTML = ICON.copy + 'Salin';
        copy.onclick = async () => { await navigator.clipboard.writeText(p.textContent.trim()); copy.innerHTML = ICON.check + 'Tersalin'; setTimeout(() => copy.innerHTML = ICON.copy + 'Salin', 1400); };
        const put = document.createElement('button'); put.className = 'btn pri'; put.innerHTML = ICON.paste + 'Tempel'; put.onclick = () => insert(p.textContent.trim());
        ft.append(cnt, copy, put); box.append(n, p, ft); $('out').append(box);
      });
    } catch (e) { toast('Gagal: ' + e.message); }
    finally { $('go').disabled = false; $('go').textContent = 'Buat ulang'; }
  }

  async function open({text = '', author = '', video = ''} = {}, auto = true) {
    host.style.display = 'block';
    current = {author, text};
    $('who').textContent = author ? '@' + author : 'Komentar'; $('whoSub').textContent = author ? 'komentar yang dibalas' : ''; $('av').textContent = (author || '?')[0];
    if (text) $('c').value = text;
    let saved = ''; if (!MULTI) try { saved = (await chrome.storage.local.get(ctxKey))[ctxKey] || ''; } catch {}
    autoCtx = video || postContext();
    $('ctx').value = video || saved || autoCtx;
    $('ctxsrc').textContent = video ? '· dari video komentar ini' : saved ? '· editan kamu untuk video ini' : '· dari halaman';
    if (text && auto) generate(); else $('c').focus();
  }

  { let d = null; const dr = $('drag');
    dr.addEventListener('pointerdown', e => { if (e.target.closest('button')) return; const r = host.getBoundingClientRect(); d = {x: e.clientX - r.left, y: e.clientY - r.top}; dr.setPointerCapture(e.pointerId); dr.style.cursor = 'grabbing'; });
    dr.addEventListener('pointermove', e => { if (!d) return; host.style.left = Math.max(0, Math.min(innerWidth - 80, e.clientX - d.x)) + 'px'; host.style.top = Math.max(0, Math.min(innerHeight - 60, e.clientY - d.y)) + 'px'; host.style.right = 'auto'; host.style.bottom = 'auto'; });
    dr.addEventListener('pointerup', () => { d = null; dr.style.cursor = 'grab'; }); }
  $('go').onclick = generate;
  $('x').onclick = () => { host.style.display = 'none'; };
  $('opt').onclick = () => chrome.runtime.sendMessage({type: 'tk-options'});
  root.addEventListener('keydown', e => { if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) generate(); e.stopPropagation(); }, true);

  let lastPath = location.pathname;
  setInterval(() => { if (location.pathname !== lastPath) { lastPath = location.pathname; current = {author: '', text: ''}; } }, 800);

  // Auto-read: one click on a comment (its text, or its Balas/Reply button) is enough.
  const replyButtonsIn = el => [...el.querySelectorAll('button,[role=button],span,a,div')].filter(x => x.childElementCount <= 2 && isReplyButton(x));
  function replyButtonFor(target) {
    let el = target;
    for (let i = 0; i < 12 && el && el !== document.body; i++, el = el.parentElement) {
      const bs = replyButtonsIn(el);
      if (bs.length === 1) return bs[0];
      if (bs.length > 1) return null;                   // already above a single comment
    }
    return null;
  }
  document.addEventListener('click', async e => {
    const path = e.composedPath();
    if (path.includes(host)) return;
    let btn = path.slice(0, 6).find(isReplyButton);
    if (!btn) {
      const t = path[0];
      if (!(t instanceof Element) || t.closest('a,button,[role=button],input,textarea,select,video,[contenteditable=true],[contenteditable=""]')) return;
      btn = replyButtonFor(t);
    }
    if (!btn) return;
    let autoOpen = true; try { autoOpen = (await chrome.storage.local.get('autoOpen')).autoOpen !== false; } catch {}
    if (!autoOpen) return;
    const c = readComment(btn);
    if (c && c.text && (host.style.display === 'none' || c.text !== current.text)) open(c);
  }, true);

  chrome.runtime.onMessage.addListener(msg => {
    if (msg?.type !== 'tk-open') return;
    const sel = (msg.text || String(window.getSelection() || '')).trim();
    open({text: sel});
  });
})();
