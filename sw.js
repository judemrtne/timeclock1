const CACHE = 'timeclock-v4';
const ASSETS = [
  '/time_clock/',
  '/time_clock/index.html',
  '/time_clock/manifest.json',
  '/time_clock/icon-192.png',
  '/time_clock/icon-512.png',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(cache =>
      Promise.allSettled([
        ...ASSETS.map(a => cache.add(a)),
        fetch('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2').then(r => cache.put('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2', r)).catch(() => {})
      ])
    )
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
  ));
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (url.hostname.includes('supabase.co')) {
    e.respondWith(fetch(e.request).catch(() =>
      new Response(JSON.stringify({error:'offline'}), {status:503, headers:{'Content-Type':'application/json'}})
    ));
    return;
  }
  if (url.hostname.includes('jsdelivr.net') || url.hostname.includes('googleapis.com') || url.hostname.includes('gstatic.com')) {
    e.respondWith(caches.match(e.request).then(cached => {
      const net = fetch(e.request).then(r => { caches.open(CACHE).then(c => c.put(e.request, r.clone())); return r; }).catch(() => cached);
      return cached || net;
    }));
    return;
  }
  e.respondWith(caches.match(e.request).then(cached =>
    cached || fetch(e.request)
      .then(r => { caches.open(CACHE).then(c => c.put(e.request, r.clone())); return r; })
      .catch(() => caches.match('/time_clock/index.html'))
  ));
});
