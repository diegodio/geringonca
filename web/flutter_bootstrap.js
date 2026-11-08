{{flutter_js}}
{{flutter_build_config}}

// Sem o service worker antigo do Flutter (descontinuado): o jogo usa o próprio
// sw.js, gerado na publicação por tool/gen_sw.py, para abrir sem internet.
_flutter.loader.load();

if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) {
  navigator.serviceWorker.register('sw.js').catch(function () {});
  // Depois de abrir, conta ao service worker o que foi usado (o CanvasKit deste
  // navegador, as fontes...) para ele guardar também.
  window.addEventListener('flutter-first-frame', function () {
    setTimeout(function () {
      var base = new URL('./', document.baseURI).href;
      var urls = performance.getEntriesByType('resource').map(function (e) { return e.name; })
        .filter(function (u) { return u.indexOf(base) === 0 || u.indexOf('https://fonts.gstatic.com/') === 0; });
      navigator.serviceWorker.ready.then(function (reg) {
        if (reg.active) reg.active.postMessage({ tipo: 'guardar', urls: urls });
      });
    }, 3000);
  });
}
