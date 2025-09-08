const CACHE = "sketch-v1";
const FILES = [
  "./",
  "./index.html",
  // List your images explicitly:
  ...Array.from({length: 30}, (_,i)=>`./images/frame_${String(i+1).padStart(2,'0')}.png`)
];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)));
  self.skipWaiting();
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.map(k => k!==CACHE && caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener("fetch", e => {
  e.respondWith(caches.match(e.request).then(r => r || fetch(e.request)));
});
