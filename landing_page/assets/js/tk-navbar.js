/* Navbar kapsul bersama (lihat assets/css/tk-navbar.css). */
(function () {
  'use strict';
  try {
    // Pembiasan tepi (backdrop-filter dengan filter SVG) hanya jalan di Chromium.
    var u = navigator.userAgent;
    if (/Chrome\//.test(u) && !/Firefox/.test(u)) document.documentElement.classList.add('tk-lg-svg');
  } catch (e) {}

  var btn = document.getElementById('tkn-burger');
  var menu = document.getElementById('tkn-menu');
  if (!btn || !menu) return;

  function set(open) {
    btn.setAttribute('aria-expanded', String(open));
    btn.setAttribute('aria-label', open ? 'Tutup menu' : 'Buka menu');
    menu.hidden = !open;
  }
  btn.addEventListener('click', function () { set(menu.hidden); });
  menu.addEventListener('click', function (e) { if (e.target.closest('a')) set(false); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && !menu.hidden) { set(false); btn.focus(); } });
  document.addEventListener('click', function (e) { if (!menu.hidden && !e.target.closest('.tkn')) set(false); });
})();
