// Bump CACHE_NAME en cada deploy crítico para forzar limpieza del cache viejo.
const CACHE_NAME = 'arcanum-v2';

const CORE_ASSETS = [
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png'
];

// Assets que SIEMPRE deben venir frescos de la red (contienen la URL del backend).
// Si se cachean, un cambio de backend (Render→Railway) nunca llega al usuario.
const NETWORK_FIRST = [
  '/',
  '/index.html',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/flutter.js',
  '/flutter_service_worker.js'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(CORE_ASSETS).catch((err) => {
        console.warn('[ARCANUM SW] cache.addAll parcial:', err);
      });
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);

  // No interceptar llamadas al backend (otro origin).
  if (url.origin !== self.location.origin) return;

  const isNetworkFirst =
    NETWORK_FIRST.includes(url.pathname) ||
    event.request.destination === 'document' ||
    url.pathname.endsWith('.js');

  if (isNetworkFirst) {
    // Network-first: intenta red, cae a cache si offline.
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          }
          return response;
        })
        .catch(() => caches.match(event.request).then((c) => c || caches.match('/index.html')))
    );
    return;
  }

  // Cache-first para assets estáticos (iconos, fuentes).
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).then((response) => {
        if (response.ok && response.type === 'basic') {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      });
    })
  );
});
