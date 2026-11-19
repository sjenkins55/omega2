/*
 * ConcertoCare EMR service worker.
 *
 * HIPAA-conscious caching policy:
 *   - NEVER caches API responses (anything under /api or a different origin) —
 *     PHI must not persist in browser caches.
 *   - Caches only the static app shell: Next.js build assets, icons, fonts.
 *   - Navigations are network-first with an offline fallback page.
 */
const CACHE = "concertocare-shell-v1";
const OFFLINE_URL = "/offline.html";
const PRECACHE = [OFFLINE_URL, "/manifest.json", "/icons/icon-192.png", "/icons/icon-512.png"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

function isStaticAsset(url) {
  return (
    url.origin === self.location.origin &&
    (url.pathname.startsWith("/_next/static/") ||
      url.pathname.startsWith("/icons/") ||
      url.pathname === "/manifest.json" ||
      url.pathname.endsWith(".woff2"))
  );
}

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  if (event.request.method !== "GET") return;

  // PHI guard: never intercept or cache API traffic (any origin)
  if (url.pathname.startsWith("/api/") || url.origin !== self.location.origin) return;

  // Static app shell: cache-first (immutable, content-hashed)
  if (isStaticAsset(url)) {
    event.respondWith(
      caches.match(event.request).then(
        (cached) =>
          cached ||
          fetch(event.request).then((res) => {
            const copy = res.clone();
            caches.open(CACHE).then((cache) => cache.put(event.request, copy));
            return res;
          })
      )
    );
    return;
  }

  // Page navigations: network-first, offline fallback (pages themselves are
  // not cached — they may render PHI)
  if (event.request.mode === "navigate") {
    event.respondWith(fetch(event.request).catch(() => caches.match(OFFLINE_URL)));
  }
});
