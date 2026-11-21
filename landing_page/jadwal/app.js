/*
 * Timetable KRL (/jadwal/). Data: /jadwal/data.json, dibangun oleh
 * scripts/build_landing_timetable.py dari feed GAPEKA 2026.
 *
 * Bentuk data: lines[].trips[] = [noKA, tujuan, fakultatif(0/1), [idxStasiun], [menit], "est per stasiun"]
 * Menit dihitung dari tengah malam hari layanan, bisa >= 1440 untuk lewat tengah malam.
 */
(function () {
  'use strict';

  var DATA, ST = [], SID = [], STIDX = {}, BYLINE = {}, LINES_AT = {};
  var $ = function (id) { return document.getElementById(id); };
  var POPULER = ['Manggarai', 'Tanah Abang', 'Sudirman', 'Jakarta Kota', 'Bogor', 'Bekasi', 'Tangerang', 'Yogyakarta'];

  /* ---------- util ---------- */
  function hm(m) { m = ((m % 1440) + 1440) % 1440; return pad(Math.floor(m / 60)) + ':' + pad(m % 60); }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function norm(s) { return s.toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim(); }
  function nowWib() {
    try {
      var p = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Jakarta', hour: '2-digit', minute: '2-digit', hour12: false }).formatToParts(new Date());
      var h = 0, m = 0;
      p.forEach(function (x) { if (x.type === 'hour') h = +x.value % 24; if (x.type === 'minute') m = +x.value; });
      return h * 60 + m;
    } catch (e) { var d = new Date(); return d.getHours() * 60 + d.getMinutes(); }
  }
  function lcolor(l) {
    if (l.color) return '#' + l.color;
    var h = 0; for (var i = 0; i < l.id.length; i++) h = (h * 31 + l.id.charCodeAt(i)) % 360;
    return 'hsl(' + h + ' 48% 40%)';
  }
  function isEst(tr, i) { return tr[5].charAt(i) === '1'; }
  function lineChip(l) { return '<span class="jd-line" style="--c:' + lcolor(l) + '">' + esc(l.name) + '</span>'; }

  /* ---------- per stasiun ---------- */
  var cur = { id: null, dir: null, mark: null };

  // Keberangkatan dari stasiun, dikelompokkan per arah (= stasiun berikutnya), seperti papan peron.
  function directions(stIdx) {
    var groups = {};
    DATA.lines.forEach(function (l) {
      l.trips.forEach(function (tr) {
        for (var i = 0; i < tr[3].length - 1; i++) {
          if (tr[3][i] !== stIdx) continue;
          var key = tr[3][i + 1];
          var g = groups[key] || (groups[key] = { key: key, via: ST[key], deps: [], term: {} });
          g.deps.push({ t: tr[4][i], e: isEst(tr, i), l: l, tr: tr, i: i });
          g.term[tr[1]] = (g.term[tr[1]] || 0) + 1;
        }
      });
    });
    var list = Object.keys(groups).map(function (k) {
      var g = groups[k];
      g.deps.sort(function (a, b) { return a.t - b.t; });
      g.terms = Object.keys(g.term).sort(function (a, b) { return g.term[b] - g.term[a]; });
      // Tanda huruf untuk tujuan selain tujuan utama (cara timetable stasiun Jepang)
      g.marks = {}; var used = {};
      g.terms.forEach(function (t, n) {
        if (n === 0) return;
        var w = t.replace(/[^A-Za-z ]/g, '').split(' ').filter(Boolean);
        var cands = [w[0].charAt(0).toUpperCase(), (w[0].charAt(0) + (w[1] ? w[1].charAt(0) : w[0].charAt(1))).toUpperCase(), w[0].slice(0, 3).toUpperCase()];
        var m = cands.filter(function (c) { return !used[c]; })[0] || String(n);
        used[m] = 1; g.marks[t] = m;
      });
      return g;
    });
    list.sort(function (a, b) { return b.deps.length - a.deps.length; });
    return list;
  }

  function stationHeader(idx) {
    var lines = LINES_AT[idx] || [];
    return '<div class="jd-st-head"><p class="jd-eyebrow">Stasiun</p><h2>' + esc(ST[idx]) + '</h2>' +
      (lines.length ? '<div class="jd-lines-at">' + lines.map(lineChip).join('') + '</div>' : '') + '</div>';
  }

  function renderStation() {
    var out = $('jd-st-out');
    if (cur.id == null) { out.innerHTML = ''; return; }
    var idx = STIDX[cur.id];
    var dirs = directions(idx);
    var h = stationHeader(idx);
    if (!dirs.length) {
      out.innerHTML = h + '<p class="jd-empty">Semua kereta berakhir di stasiun ini.</p>';
      return;
    }
    var d = dirs.filter(function (x) { return x.key === cur.dir; })[0] || dirs[0];
    cur.dir = d.key;

    // Pilih arah
    h += '<div class="jd-dirs" role="tablist" aria-label="Arah">';
    dirs.forEach(function (g) {
      var sel = g === d;
      var names = g.terms.slice(0, 2).join(' · ') + (g.terms.length > 2 ? ' +' + (g.terms.length - 2) : '');
      h += '<button type="button" role="tab" class="jd-dir" aria-selected="' + sel + '" data-dir="' + g.key + '">' +
        '<span class="jd-dir-to">' + esc(names) + '</span>' +
        '<span class="jd-dir-via">via ' + esc(g.via) + ' · ' + g.deps.length + '</span></button>';
    });
    h += '</div>';

    var deps = d.deps.filter(function (x) { return !cur.mark || x.tr[1] === cur.mark; });
    var now = nowWib(), nextI = -1;
    for (var k = 0; k < deps.length; k++) { if (deps[k].t >= now) { nextI = k; break; } }

    // Berikutnya
    if (nextI > -1) {
      var n0 = deps[nextI], mins = n0.t - now;
      h += '<div class="jd-next"><span class="jd-next-dot" aria-hidden="true"></span><span class="jd-next-lbl">Berikutnya</span>' +
        '<button type="button" class="jd-next-time" data-k="' + nextI + '">' + hm(n0.t) + '</button>' +
        '<span class="jd-next-to">' + esc(n0.tr[1]) + '</span>' +
        '<span class="jd-next-in">' + (mins === 0 ? 'sekarang' : mins < 120 ? mins + ' mnt lagi' : '') + '</span></div>';
    }

    // Legenda tujuan: hanya bila arah ini punya lebih dari satu tujuan
    if (d.terms.length > 1) {
      h += '<div class="jd-legend-dest" role="group" aria-label="Tujuan">';
      h += '<button type="button" class="jd-mk" aria-pressed="' + !cur.mark + '" data-mark="">Semua</button>';
      d.terms.forEach(function (t, n) {
        h += '<button type="button" class="jd-mk" aria-pressed="' + (cur.mark === t) + '" data-mark="' + esc(t) + '">' +
          (n === 0 ? '<i class="jd-mk-none" aria-hidden="true"></i>' : '<b>' + d.marks[t] + '</b>') + esc(t) + '</button>';
      });
      h += '</div>';
    }

    // Kisi jam x menit
    var rows = {}, order = [];
    deps.forEach(function (x, k) {
      var hr = Math.floor(x.t / 60);
      if (!rows[hr]) { rows[hr] = []; order.push(hr); }
      rows[hr].push(k);
    });
    var nowHr = Math.floor(now / 60);
    h += '<div class="jd-grid" role="table" aria-label="Jam keberangkatan">';
    order.forEach(function (hr) {
      h += '<div class="jd-hr' + (hr === nowHr ? ' is-now' : '') + '" role="row"><div class="jd-hr-n" role="rowheader">' + pad(hr % 24) + '</div><div class="jd-hr-m" role="cell">';
      rows[hr].forEach(function (k) {
        var x = deps[k], mk = d.marks[x.tr[1]];
        var cls = 'jd-m' + (x.t < now ? ' is-past' : '') + (k === nextI ? ' is-next' : '') + (x.e ? ' is-est' : '') + (x.tr[2] ? ' is-fak' : '');
        var label = hm(x.t) + ' ke ' + x.tr[1] + ', ' + x.l.name + (x.e ? ', perkiraan' : '') + (x.tr[2] ? ', fakultatif' : '');
        h += '<button type="button" class="' + cls + '" data-k="' + k + '" aria-label="' + esc(label) + '">' + pad(x.t % 60) +
          (mk && !cur.mark ? '<sup>' + mk + '</sup>' : '') + '</button>';
      });
      h += '</div></div>';
    });
    h += '</div>';
    h += '<p class="jd-keys"><span><i class="k-est"></i>perkiraan</span><span><i class="k-fak"></i>fakultatif</span><span><i class="k-next"></i>berikutnya</span></p>';
    out.innerHTML = h;

    out.querySelectorAll('.jd-dir').forEach(function (b) {
      b.addEventListener('click', function () { cur.dir = +b.dataset.dir; cur.mark = null; renderStation(); });
    });
    out.querySelectorAll('.jd-mk').forEach(function (b) {
      b.addEventListener('click', function () { cur.mark = b.dataset.mark || null; renderStation(); });
    });
    out.querySelectorAll('[data-k]').forEach(function (b) {
      b.addEventListener('click', function () { var x = deps[+b.dataset.k]; openTrip(x.l, x.tr, x.i, b); });
    });
  }

  function pickStation(id, push) {
    cur.id = id; cur.dir = null; cur.mark = null;
    $('jd-q').value = ST[STIDX[id]];
    hideSug();
    if (push !== false) { try { history.replaceState(null, '', '#s=' + encodeURIComponent(id)); } catch (e) {} }
    renderStation();
  }

  /* ---------- saran pencarian ---------- */
  var sugPos = -1;
  function hideSug() { $('jd-sug').hidden = true; $('jd-q').setAttribute('aria-expanded', 'false'); $('jd-q').removeAttribute('aria-activedescendant'); sugPos = -1; }
  function showSug() {
    var q = norm($('jd-q').value), box = $('jd-sug');
    if (!q) { hideSug(); return; }
    var items = DATA.stations.filter(function (s) { return norm(s[1]).indexOf(q) !== -1 || s[0].toLowerCase() === q; });
    items.sort(function (a, b) { return (norm(a[1]).indexOf(q) === 0 ? 0 : 1) - (norm(b[1]).indexOf(q) === 0 ? 0 : 1); });
    items = items.slice(0, 8);
    box.innerHTML = items.length ? items.map(function (s, i) {
      var idx = STIDX[s[0]], ls = (LINES_AT[idx] || []).slice(0, 3);
      return '<li role="option" id="sug-' + i + '" data-id="' + esc(s[0]) + '"><span>' + esc(s[1]) + '</span><span class="jd-sug-dots">' +
        ls.map(function (l) { return '<i style="background:' + lcolor(l) + '"></i>'; }).join('') + '</span></li>';
    }).join('') : '<li class="jd-sug-none">Tidak ada stasiun bernama itu</li>';
    box.hidden = false; $('jd-q').setAttribute('aria-expanded', 'true');
    box.querySelectorAll('li[data-id]').forEach(function (li) {
      li.addEventListener('mousedown', function (e) { e.preventDefault(); pickStation(li.dataset.id); });
    });
  }

  /* ---------- per lintas ---------- */
  var ln = { id: null, to: null };
  function renderLines() {
    var groups = {}, order = [];
    DATA.lines.forEach(function (l) { if (!groups[l.group]) { groups[l.group] = []; order.push(l.group); } groups[l.group].push(l); });
    var h = '';
    order.forEach(function (g) {
      h += '<h3 class="jd-eyebrow jd-grp">' + esc(g) + '</h3><div class="jd-lgrid">';
      groups[g].forEach(function (l) {
        h += '<button type="button" class="jd-lcard" style="--c:' + lcolor(l) + '" aria-pressed="' + (l.id === ln.id) + '" data-line="' + esc(l.id) + '">' +
          '<span class="jd-lcard-n">' + esc(l.name) + '</span><span class="jd-lcard-c">' + l.trips.length + '</span></button>';
      });
      h += '</div>';
    });
    $('jd-lines').innerHTML = h;
    $('jd-lines').querySelectorAll('.jd-lcard').forEach(function (b) {
      b.addEventListener('click', function () {
        ln.id = b.dataset.line; ln.to = null;
        try { history.replaceState(null, '', '#l=' + encodeURIComponent(ln.id)); } catch (e) {}
        renderLines(); renderLine();
        $('jd-ln-out').scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' });
      });
    });
  }

  function renderLine() {
    var out = $('jd-ln-out');
    if (!ln.id) { out.innerHTML = ''; return; }
    var l = BYLINE[ln.id];
    var cnt = {}; l.trips.forEach(function (tr) { cnt[tr[1]] = (cnt[tr[1]] || 0) + 1; });
    var tos = Object.keys(cnt).sort(function (a, b) { return cnt[b] - cnt[a]; });
    var trips = l.trips.filter(function (tr) { return !ln.to || tr[1] === ln.to; });
    var h = '<div class="jd-st-head" style="--c:' + lcolor(l) + '"><p class="jd-eyebrow">Lintas</p><h2 class="jd-ln-title">' + esc(l.long) + '</h2></div>';
    if (tos.length > 1) {
      h += '<div class="jd-legend-dest" role="group" aria-label="Tujuan"><button type="button" class="jd-mk" aria-pressed="' + !ln.to + '" data-to="">Semua</button>';
      tos.forEach(function (t) { h += '<button type="button" class="jd-mk" aria-pressed="' + (ln.to === t) + '" data-to="' + esc(t) + '">' + esc(t) + '</button>'; });
      h += '</div>';
    }
    h += '<div class="jd-table" role="table" aria-label="Perjalanan ' + esc(l.name) + '"><div class="jd-tr jd-th" role="row"><span role="columnheader">Berangkat</span><span role="columnheader">Rute</span><span role="columnheader">Tiba</span></div>';
    trips.forEach(function (tr, n) {
      var a = tr[4][0], z = tr[4][tr[4].length - 1];
      h += '<button type="button" class="jd-tr" role="row" data-n="' + n + '">' +
        '<span class="jd-td-t" role="cell">' + hm(a) + '</span>' +
        '<span class="jd-td-r" role="cell"><b>' + esc(ST[tr[3][0]]) + '</b><i aria-hidden="true"></i><b>' + esc(ST[tr[3][tr[3].length - 1]]) + '</b>' +
        (tr[2] ? '<em class="jd-tag-fak">F</em>' : '') + '<small>KA ' + esc(tr[0]) + '</small></span>' +
        '<span class="jd-td-t is-z" role="cell">' + hm(z) + '</span></button>';
    });
    out.innerHTML = h + '</div>';
    out.querySelectorAll('.jd-mk').forEach(function (b) { b.addEventListener('click', function () { ln.to = b.dataset.to || null; renderLine(); }); });
    out.querySelectorAll('.jd-tr[data-n]').forEach(function (b) { b.addEventListener('click', function () { openTrip(l, trips[+b.dataset.n], -1, b); }); });
  }

  /* ---------- detail perjalanan (bottom sheet) ---------- */
  var sheet, lastFocus;
  function openTrip(l, tr, here, from) {
    lastFocus = from;
    var last = tr[3].length - 1;
    var h = '<div class="jd-sh-head" style="--c:' + lcolor(l) + '">' +
      '<div><p class="jd-eyebrow">KA ' + esc(tr[0]) + (tr[2] ? ' · fakultatif' : '') + '</p>' +
      '<h2 id="jd-sh-title">' + esc(ST[tr[3][0]]) + ' <span aria-hidden="true">→</span><span class="jd-sr"> ke </span> ' + esc(ST[tr[3][last]]) + '</h2>' + lineChip(l) + '</div>' +
      '<button type="button" class="jd-sh-x" aria-label="Tutup"><svg viewBox="0 0 20 20" width="20" height="20" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="m5 5 10 10M15 5 5 15"/></svg></button></div>';
    h += '<ol class="jd-route" style="--c:' + lcolor(l) + '">';
    for (var i = 0; i <= last; i++) {
      var cls = i === here ? 'is-here' : i === last ? 'is-end' : i === 0 ? 'is-start' : '';
      if (here > -1 && i < here) cls += ' is-before';
      h += '<li class="' + cls + '"><span class="jd-route-n">' + esc(ST[tr[3][i]]) + (i === here ? '<em>naik di sini</em>' : '') + '</span>' +
        '<time class="' + (isEst(tr, i) ? 'is-est' : '') + '">' + hm(tr[4][i]) + '</time></li>';
    }
    h += '</ol>';
    sheet.querySelector('.jd-sh-body').innerHTML = h;
    sheet.querySelector('.jd-sh-x').addEventListener('click', closeTrip);
    if (typeof sheet.showModal === 'function') sheet.showModal(); else sheet.setAttribute('open', '');
    var hereEl = sheet.querySelector('.is-here');
    if (hereEl) hereEl.scrollIntoView({ block: 'center' });
    sheet.querySelector('.jd-sh-x').focus();
  }
  function closeTrip() {
    if (typeof sheet.close === 'function') sheet.close(); else sheet.removeAttribute('open');
  }

  /* ---------- tab ---------- */
  function setTab(which) {
    var s = which === 'stasiun';
    ['stasiun', 'lintas'].forEach(function (t) {
      var on = t === which;
      $('tab-' + t).setAttribute('aria-selected', String(on));
      $('tab-' + t).tabIndex = on ? 0 : -1;
      $('panel-' + t).hidden = !on;
    });
    if (!s && !$('jd-lines').firstChild) { renderLines(); renderLine(); }
  }

  /* ---------- mulai ---------- */
  fetch('/jadwal/data.json').then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); }).then(function (d) {
    DATA = d;
    d.stations.forEach(function (s, i) { SID[i] = s[0]; ST[i] = s[1]; STIDX[s[0]] = i; });
    d.lines.forEach(function (l) {
      BYLINE[l.id] = l;
      var seen = {};
      l.trips.forEach(function (tr) { tr[3].forEach(function (i) { seen[i] = 1; }); });
      Object.keys(seen).forEach(function (i) { (LINES_AT[i] = LINES_AT[i] || []).push(l); });
    });
    $('jd-status').hidden = true;
    $('jd-app').hidden = false;

    // Stasiun populer: hanya yang benar-benar ada di data
    var byName = {}; d.stations.forEach(function (s) { byName[s[1].toLowerCase()] = s[0]; });
    $('jd-pop').innerHTML = POPULER.filter(function (n) { return byName[n.toLowerCase()]; }).map(function (n) {
      return '<button type="button" class="jd-pop" data-id="' + byName[n.toLowerCase()] + '">' + esc(n) + '</button>';
    }).join('');
    $('jd-pop').querySelectorAll('.jd-pop').forEach(function (b) { b.addEventListener('click', function () { setTab('stasiun'); pickStation(b.dataset.id); $('jd-st-out').scrollIntoView({ block: 'start' }); }); });

    sheet = $('jd-sheet');
    sheet.addEventListener('click', function (e) { if (e.target === sheet) closeTrip(); });
    sheet.addEventListener('close', function () { if (lastFocus && lastFocus.focus) lastFocus.focus(); });

    $('tab-stasiun').addEventListener('click', function () { setTab('stasiun'); });
    $('tab-lintas').addEventListener('click', function () { setTab('lintas'); });
    $('jd-tabs').addEventListener('keydown', function (e) {
      if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
      var to = $('tab-stasiun').getAttribute('aria-selected') === 'true' ? 'lintas' : 'stasiun';
      setTab(to); $('tab-' + to).focus();
    });

    var q = $('jd-q');
    q.addEventListener('input', showSug);
    q.addEventListener('focus', function () { q.select(); if (q.value) showSug(); });
    q.addEventListener('blur', function () { setTimeout(hideSug, 120); });
    q.addEventListener('keydown', function (e) {
      var box = $('jd-sug'), opts = box.querySelectorAll('li[data-id]');
      if (e.key === 'ArrowDown') { if (box.hidden) showSug(); sugPos = Math.min(sugPos + 1, opts.length - 1); }
      else if (e.key === 'ArrowUp') { sugPos = Math.max(sugPos - 1, 0); }
      else if (e.key === 'Enter') { var t = opts[Math.max(sugPos, 0)]; if (t) pickStation(t.dataset.id); e.preventDefault(); return; }
      else if (e.key === 'Escape') { hideSug(); return; }
      else return;
      e.preventDefault();
      opts.forEach(function (o, i) { o.setAttribute('aria-selected', String(i === sugPos)); });
      if (opts[sugPos]) { q.setAttribute('aria-activedescendant', opts[sugPos].id); opts[sugPos].scrollIntoView({ block: 'nearest' }); }
    });

    var ms = /#s=([A-Za-z0-9_-]+)/.exec(location.hash), ml = /#l=([A-Za-z0-9_-]+)/.exec(location.hash);
    if (ml && BYLINE[ml[1]]) { ln.id = ml[1]; setTab('lintas'); }
    else { setTab('stasiun'); if (ms && STIDX[ms[1]] != null) pickStation(ms[1], false); }
  }).catch(function () {
    $('jd-status').textContent = 'Jadwal gagal dimuat. Periksa koneksi lalu muat ulang halaman.';
  });
})();
