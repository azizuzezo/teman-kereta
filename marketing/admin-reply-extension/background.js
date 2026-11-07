import {DEFAULTS, TOPICS, detectTopic, templateReplies, systemPrompt} from './replies.js';

const settings = async () => ({...DEFAULTS, ...(await chrome.storage.local.get(Object.keys(DEFAULTS)))});

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({id: 'tk-reply', title: 'Balas sebagai Admin Teman Kereta', contexts: ['selection', 'editable']});
});

async function openPanel(tab, text) {
  if (!tab?.id) return;
  try {
    await chrome.tabs.sendMessage(tab.id, {type: 'tk-open', text: text || ''});
  } catch {
    // Page not covered by the content-script list: inject on demand (activeTab).
    await chrome.scripting.executeScript({target: {tabId: tab.id}, files: ['content.js']});
    await chrome.tabs.sendMessage(tab.id, {type: 'tk-open', text: text || ''});
  }
}

chrome.contextMenus.onClicked.addListener((info, tab) => { if (info.menuItemId === 'tk-reply') openPanel(tab, info.selectionText); });
chrome.commands.onCommand.addListener(async cmd => {
  if (cmd !== 'open-panel') return;
  const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
  openPanel(tab, '');
});
chrome.action.onClicked.addListener(tab => openPanel(tab, ''));

function parseReplies(raw) {
  const text = String(raw || '').replace(/<think>[\s\S]*?<\/think>/gi, '').trim().replace(/^```(?:json)?\s*|\s*```$/g, '');
  const str = v => String(v).replace(/\s+/g, ' ').trim();
  try {
    const j = JSON.parse(text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1));
    if (Array.isArray(j.replies) && j.replies.length) return {topic: j.topic, intent: j.maksud && str(j.maksud), replies: j.replies.map(str).filter(r => r.length > 4).slice(0, 3)};
  } catch { /* output was cut off or not JSON: salvage the complete strings */ }
  const q = '"((?:[^"\\\\]|\\\\.)*)"', dec = m => { try { return str(JSON.parse('"' + m + '"')); } catch { return ''; } };
  const at = text.search(/"replies"\s*:\s*\[/);
  if (at >= 0) {
    const replies = [...text.slice(text.indexOf('[', at)).matchAll(new RegExp(q, 'g'))].map(m => dec(m[1])).filter(r => r.length > 4).slice(0, 3);
    const mk = text.match(new RegExp('"maksud"\\s*:\\s*' + q)), tp = text.match(/"topic"\s*:\s*"(\w+)"/);
    if (replies.length) return {topic: tp && tp[1], intent: mk && dec(mk[1]), replies, partial: replies.length < 3};
  }
  if (/^\s*[{\[]/.test(text)) return null;                 // JSON-looking but unusable: never show raw JSON as a reply
  const lines = text.split('\n').map(l => l.replace(/^\s*(\d+[.)]|[-*•])\s*/, '').trim()).filter(l => l.length > 4);
  return lines.length ? {replies: lines.slice(0, 3)} : null;
}

async function aiReplies(comment, context, s) {
  const url = s.baseUrl.replace(/\/+$/, '') + '/chat/completions';
  const body = {
    model: s.model,
    temperature: 0.8,
    max_tokens: 2000,
    messages: [
      {role: 'system', content: systemPrompt(s)},
      {role: 'user', content: `Platform: ${context.platform || 'media sosial'}\nKonteks video/postingan: ${context.post || '(tidak terbaca)'}\nPengomentar: ${context.author ? '@' + context.author : '(tidak diketahui)'}\n\nKomentar:\n"""${comment}"""`},
    ],
  };
  const ctrl = new AbortController(); const timer = setTimeout(() => ctrl.abort(), 30000);
  try {
    const res = await fetch(url, {method: 'POST', signal: ctrl.signal,
      headers: {'Content-Type': 'application/json', Authorization: `Bearer ${s.apiKey}`}, body: JSON.stringify(body)});
    if (!res.ok) throw new Error(`AI ${res.status}: ${(await res.text()).slice(0, 160)}`);
    const data = await res.json();
    const parsed = parseReplies(data?.choices?.[0]?.message?.content);
    if (!parsed) throw new Error('Balasan AI kosong atau tidak terbaca');
    return parsed;
  } finally { clearTimeout(timer); }
}

chrome.runtime.onMessage.addListener((msg, _sender, reply) => {
  if (msg?.type === 'tk-generate') {
    (async () => {
      const s = await settings();
      const local = templateReplies(msg.comment, s, msg.context || {});
      if (!(s.aiEnabled && s.baseUrl && s.apiKey && s.model)) return reply({...local, note: 'Mode template (AI belum diatur di Pengaturan).'});
      try {
        const ai = await aiReplies(msg.comment, msg.context || {}, s);
        // Guardrail: never sell on sensitive comments, whatever the model wrote.
        const topic = detectTopic(msg.comment);
        let replies = ai.replies;
        if (topic.id === 'sensitif') replies = replies.filter(r => !/teman kereta|temankereta|aplikasi|download|unduh|http/i.test(r));
        if (!replies.length) replies = local.replies;
        const t = topic.id === 'sensitif' ? topic : (TOPICS.find(x => x.id === ai.topic) || topic);
        reply({topic: t, source: 'ai', replies, intent: ai.intent, note: ai.partial ? 'AI hanya menghasilkan ' + replies.length + ' saran lengkap.' : undefined});
      } catch (e) {
        reply({...local, note: `AI gagal (${e.message}). Memakai template.`});
      }
    })();
    return true;
  }
  if (msg?.type === 'tk-options') { chrome.runtime.openOptionsPage(); return false; }
});
