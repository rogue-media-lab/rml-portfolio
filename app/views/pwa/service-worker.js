// Zuke Music Player Service Worker
const CACHE_VERSION = 'zuke-v4'; // Bumped for Range/ActiveStorage fix
const CACHE_ASSETS = [
  '/zuke/music',
  '/icon.png'
];

// Install event - cache essential assets
self.addEventListener('install', (event) => {
  console.log('Service Worker: Installing...');

  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then((cache) => {
        console.log('Service Worker: Caching assets...');

        // Cache assets individually to prevent one failure from breaking everything
        return Promise.allSettled(
          CACHE_ASSETS.map(url =>
            cache.add(url)
              .then(() => console.log(`Service Worker: Cached ${url}`))
              .catch(err => console.warn(`Service Worker: Failed to cache ${url}:`, err))
          )
        );
      })
      .then(() => {
        console.log('Service Worker: Install complete');
        return self.skipWaiting();
      })
      .catch(err => console.error('Service Worker: Install failed:', err))
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('Service Worker: Activating...');

  event.waitUntil(
    caches.keys().then((cacheNames) => {
      console.log('Service Worker: Found caches:', cacheNames);

      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_VERSION) {
            console.log(`Service Worker: Deleting old cache: ${cacheName}`);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      console.log('Service Worker: Activation complete, claiming clients');
      return self.clients.claim();
    })
  );
});

// Fetch event - network first, fall back to cache
self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') return;

  // Skip audio files, Range requests, ActiveStorage blobs, and SoundCloud CDN
  // Letting the browser handle these directly ensures proper streaming and avoids CORS/Range issues.
  const url = event.request.url;
  if (url.includes('.mp3') || 
      url.includes('.wav') ||
      url.includes('/rails/active_storage/') ||
      url.includes('sndcdn.com') ||
      url.includes('soundcloud.com') ||
      event.request.headers.has('range')) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Clone the response before caching
        const responseClone = response.clone();

        // Cache successful responses
        if (response.status === 200) {
          caches.open(CACHE_VERSION).then((cache) => {
            cache.put(event.request, responseClone);
          });
        }

        return response;
      })
      .catch(() => {
        // Network failed, try cache
        return caches.match(event.request).then((response) => {
          // Return cache if found, otherwise return a fallback response
          return response || new Response("Zuke SW: Network error and no cache available", {
            status: 503,
            statusText: "Service Unavailable",
            headers: new Headers({ "Content-Type": "text/plain" })
          });
        });
      })
  );
});
