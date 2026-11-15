/* HostKit preview site: TV code carry-through + mobile menu. */
(function () {
  var KEY = 'hostkit_tv_code';
  var RE = /^[A-HJKMNP-Z2-9]{6}$/; // 6 chars, no 0 O 1 I L
  var root = document.documentElement;
  var ss = null; try { ss = window.sessionStorage; } catch (e) {}
  var raw = new URLSearchParams(location.search).get('code');
  var code = null;
  if (raw !== null) {
    var c = raw.toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (RE.test(c)) { code = c; if (ss) ss.setItem(KEY, c); }
    else { root.classList.add('bad-code'); if (ss) ss.removeItem(KEY); }
  } else if (ss) {
    var s = ss.getItem(KEY); if (s && RE.test(s)) code = s;
  }
  window.HOSTKIT_CODE = code;
  if (code) {
    root.classList.add('has-code');
    document.querySelectorAll('[data-code]').forEach(function (e) { e.textContent = code; });
  }
  // Every CTA -> signup(?code=), every internal page link keeps the code.
  window.hostkitLink = function (href) {
    if (!code) return href;
    var m = href.match(/^([a-z0-9-]+\.html)(#.*)?$/i);
    return m ? m[1] + '?code=' + code + (m[2] || '') : href;
  };
  document.querySelectorAll('a[href]').forEach(function (a) {
    if (a.hasAttribute('data-cta')) { a.setAttribute('href', code ? 'signup?code=' + encodeURIComponent(code) : 'signup'); return; }
    a.setAttribute('href', window.hostkitLink(a.getAttribute('href')));
  });
  // Mobile menu
  var btn = document.querySelector('.menu-btn');
  if (btn) {
    var set = function (open) { btn.setAttribute('aria-expanded', open ? 'true' : 'false'); btn.setAttribute('aria-label', open ? 'Close menu' : 'Open menu'); root.classList.toggle('menu-open', open); };
    btn.addEventListener('click', function () { set(btn.getAttribute('aria-expanded') !== 'true'); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && root.classList.contains('menu-open')) { set(false); btn.focus(); } });
    document.querySelectorAll('#site-nav a').forEach(function (a) { a.addEventListener('click', function () { set(false); }); });
  }
})();
