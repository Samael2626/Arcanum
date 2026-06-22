const CACHE_NAME = 'arcanum-v1';
const CORE_ASSETS = [
  '/',
  '/index.html',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(CORE_ASSETS).catch((err) => {
        // Non-fatal: algunos assets pueden no existir aún en install
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
  // Solo intercepta GET; deja pasar las llamadas al backend API
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);

  // No cachear llamadas al backend (distintos origins o path /api/)
  if (url.pathname.startsWith('/api/') || url.port === '8000') return;

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;

      return fetch(event.request)
        .then((response) => {
          // Cachear solo respuestas válidas de mismo origen
          if (
            response.ok &&
            response.type === 'basic' &&
            url.origin === self.location.origin
          ) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          }
          return response;
        })
        .catch(() => {
          // Offline fallback: devuelve index.html para rutas de navegación
          if (event.request.destination === 'document') {
            return caches.match('/index.html');
          }
        });
    })
  );
});
