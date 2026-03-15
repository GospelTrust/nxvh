// pwabuilder-sw.js
// A modern service worker for PWABuilder projects

const CACHE_NAME = "pwa-cache-v1";
const OFFLINE_URL = "/offline.html";

// List of files to precache
const PRECACHE_ASSETS = [
  "/",
  "/index.html",
  "/404.html",
  OFFLINE_URL,
  "/assets/favicon.ico",
  "/assets/site.webmanifest",
  "/assets/css/session.css",
  "/assets/css/segment.css",
  "/assets/css/dialog.css"
];

// Install event - cache essential assets
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log("[Service Worker] Pre-caching assets");
      return cache.addAll(PRECACHE_ASSETS);
    })
  );
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            console.log("[Service Worker] Removing old cache:", key);
            return caches.delete(key);
          }
        })
      )
    )
  );
  self.clients.claim();
});

// Fetch event - cache-first for static, network-first for API
self.addEventListener("fetch", (event) => {
  const request = event.request;

  // Handle API requests with network-first strategy
  if (request.url.includes("/api/")) {
    event.respondWith(networkFirst(request));
    return;
  }

  // Handle static assets with cache-first strategy
  event.respondWith(cacheFirst(request));
});

// Cache-first strategy
async function cacheFirst(request) {
  const cachedResponse = await caches.match(request);
  return cachedResponse || fetch(request).catch(() => caches.match(OFFLINE_URL));
}

// Network-first strategy
async function networkFirst(request) {
  try {
    const freshResponse = await fetch(request);
    const cache = await caches.open(CACHE_NAME);
    cache.put(request, freshResponse.clone());
    return freshResponse;
  } catch (error) {
    return caches.match(request) || caches.match(OFFLINE_URL);
  }
}

