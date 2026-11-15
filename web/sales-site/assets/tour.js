/* Tour the TV: tabs, remote, swipe, and deep links (tour.html#wifi). */
(function () {
  var T = window.HOSTKIT_TOUR, i = 0;
  var img = document.getElementById('tv-img'), tabs = [].slice.call(document.querySelectorAll('.tab'));
  var $ = function (id) { return document.getElementById(id); };
  T.forEach(function (x) { var im = new Image(); im.src = 'img/' + x.img + '-1280.jpg'; });
  function show(n, fromHash) {
    i = (n + T.length) % T.length; var x = T[i];
    img.style.opacity = 0;
    setTimeout(function () { img.src = 'img/' + x.img + '-1280.jpg'; img.srcset = 'img/' + x.img + '-720.jpg 720w, img/' + x.img + '-1280.jpg 1280w'; img.alt = x.tab + ' screen on the TV'; img.style.opacity = 1; }, 120);
    $('p-title').textContent = x.title; $('p-guest').textContent = x.guest; $('p-host').textContent = x.host;
    $('p-step').textContent = (i + 1) + ' of ' + T.length + ' · ' + x.tab;
    var fl = $('p-feature'); fl.setAttribute('href', window.hostkitLink('features.html#' + x.id)); fl.textContent = 'Read about ' + x.tab + ' →';
    tabs.forEach(function (b, k) { b.setAttribute('aria-selected', k === i ? 'true' : 'false'); b.tabIndex = k === i ? 0 : -1; });
    var sel = tabs[i]; var bar = sel.parentNode; bar.scrollLeft = sel.offsetLeft - (bar.clientWidth - sel.offsetWidth) / 2;
    $('live').textContent = 'Showing ' + x.tab;
    if (!fromHash && history.replaceState) history.replaceState(null, '', location.pathname + location.search + '#' + x.id);
  }
  function fromHash() { var id = location.hash.slice(1); for (var k = 0; k < T.length; k++) if (T[k].id === id) return k; return -1; }
  tabs.forEach(function (b, k) { b.addEventListener('click', function () { show(k); }); });
  $('r-prev').onclick = function () { show(i - 1); };
  $('r-next').onclick = function () { show(i + 1); };
  $('r-ok').onclick = function () { show(i + 1); };
  $('r-back').onclick = function () { show(0); };
  $('tour').addEventListener('keydown', function (e) {
    if (e.key === 'ArrowRight') { show(i + 1); e.preventDefault(); }
    else if (e.key === 'ArrowLeft') { show(i - 1); e.preventDefault(); }
    else if (e.key === 'Escape') { show(0); e.preventDefault(); }
  });
  var x0 = null, scr = $('tv-touch');
  scr.addEventListener('touchstart', function (e) { x0 = e.touches[0].clientX; }, { passive: true });
  scr.addEventListener('touchend', function (e) { if (x0 === null) return; var d = e.changedTouches[0].clientX - x0; if (Math.abs(d) > 40) show(i + (d < 0 ? 1 : -1)); x0 = null; });
  window.addEventListener('hashchange', function () { var k = fromHash(); if (k >= 0) show(k, true); });
  var k0 = fromHash(); show(k0 >= 0 ? k0 : 0, true);
})();
