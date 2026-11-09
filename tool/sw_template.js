// Service worker da Geringonça: guarda o jogo no aparelho para abrir sem internet.
// Gerado por tool/gen_sw.py a cada publicação (VERSAO e ARQUIVOS são preenchidos lá).
//
// Três caches:
//   app    arquivos desta versão do jogo (trocam a cada publicação)
//   motor  o CanvasKit do Flutter usado neste navegador (troca com a versão do Flutter)
//   fontes as fontes do Google (ficam entre versões)
// Tudo é servido primeiro do cache; o que não estiver lá vem da rede e é guardado.
// Uma versão nova é baixada em segundo plano e vale a partir da próxima abertura.
const VERSAO = '__VERSAO__';
const MOTOR = '__MOTOR__';
const ARQUIVOS = __ARQUIVOS__;

const APP = 'geringonca-app-' + VERSAO;
const CACHE_MOTOR = 'geringonca-motor-' + MOTOR;
const FONTES = 'geringonca-fontes';
const BASE = new URL('./', self.location).href;

// O jogo vem em duas versões; o navegador escolhe uma (WebAssembly onde há suporte, JS
// nos outros). Numa atualização, baixa só a versão do tipo que já estava guardada; na
// primeira visita, a página conta qual usou (mensagem 'guardar' abaixo).
const WASM = ['main.dart.wasm', 'main.dart.mjs'], JS = ['main.dart.js'];

async function versaoEmUso() {
  for (const k of await caches.keys()) {
    if (!k.startsWith('geringonca-app-') || k === APP) continue;
    const c = await caches.open(k);
    if (await c.match(BASE + WASM[0])) return WASM;
    if (await c.match(BASE + JS[0])) return JS;
  }
  return [];
}

self.addEventListener('install', (e) => {
  e.waitUntil((async () => {
    const c = await caches.open(APP);
    await c.addAll([...ARQUIVOS, ...await versaoEmUso()]);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (e) => {
  const manter = [APP, CACHE_MOTOR, FONTES];
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(ks.filter((k) => k.startsWith('geringonca-') && !manter.includes(k)).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

/** Em qual cache guardar uma URL (ou null: não guardar). */
function cacheDe(url) {
  if (url.startsWith('https://fonts.gstatic.com/') || url.startsWith('https://fonts.googleapis.com/')) return FONTES;
  if (!url.startsWith(BASE)) return null;
  const caminho = url.slice(BASE.length).split(/[?#]/)[0];
  if (caminho === 'sw.js' || caminho.endsWith('.symbols')) return null;
  return caminho.startsWith('canvaskit/') ? CACHE_MOTOR : APP;
}

async function responde(req) {
  const nome = cacheDe(req.url);
  // a página (qualquer endereço da pasta, com ou sem #link) vem do index guardado
  const navega = req.mode === 'navigate';
  const achado = navega
    ? await caches.match('./', { ignoreSearch: true }) || await caches.match('index.html', { ignoreSearch: true })
    : await caches.match(req);
  if (achado) return achado;
  try {
    const resp = await fetch(req);
    if (nome && resp.ok && (resp.type === 'basic' || resp.type === 'cors')) {
      const copia = resp.clone();
      caches.open(nome).then((c) => c.put(req, copia));
    }
    return resp;
  } catch (err) {
    if (navega) {
      const pagina = await caches.match('./');
      if (pagina) return pagina;
    }
    throw err;
  }
}

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET' || !cacheDe(e.request.url) && e.request.mode !== 'navigate') return;
  e.respondWith(responde(e.request));
});

// A página manda a lista do que usou ao abrir (o CanvasKit deste navegador,
// as fontes...): guarda o que ainda não estiver no cache.
self.addEventListener('message', (e) => {
  const urls = e.data && e.data.tipo === 'guardar' && Array.isArray(e.data.urls) ? e.data.urls : [];
  e.waitUntil(Promise.all(urls.map(async (u) => {
    const nome = cacheDe(u);
    if (!nome || await caches.match(u)) return;
    try {
      const resp = await fetch(u, { mode: u.startsWith(BASE) ? 'same-origin' : 'cors' });
      if (resp.ok) await (await caches.open(nome)).put(u, resp);
    } catch (_) { /* sem rede: tenta de novo na próxima abertura */ }
  })));
});
