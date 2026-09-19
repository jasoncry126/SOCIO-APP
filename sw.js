/* ===========================================================================
   SOCIO · Service worker
   ---------------------------------------------------------------------------
   Hace dos cosas: que Android ofrezca instalar la app, y que abra aunque el
   socio esté sin señal — que es la mitad del Perú donde va a vender.

   LO QUE NUNCA SE GUARDA EN CACHÉ
   -------------------------------
   Nada que venga de Supabase. Ni catálogo, ni pedidos, ni precios, ni sesión.
   Un precio guardado de ayer es un socio cotizando mal, y un pedido guardado
   de ayer es un socio creyendo que vendió algo que no registró. Con dinero de
   por medio, más vale un error de red visible que un dato viejo invisible.

   Lo que sí se guarda es el "armazón": las páginas y los scripts, que solo
   cambian cuando se publica una versión nueva.

   CÓMO SE ACTUALIZA
   -----------------
   Las páginas van por red primero y solo caen a la caché si no hay señal. Así
   una versión nueva llega sola la próxima vez que abra con datos, en vez de
   quedarse pegado a una copia vieja para siempre — que es el fallo clásico de
   los service workers mal hechos.

   Al cambiar el armazón, sube VERSION: eso borra la caché anterior entera.
   =========================================================================== */

const VERSION = 'socio-v1';
const ARMAZON = 'armazon-' + VERSION;

/* Rutas relativas al alcance del worker, que es la raíz del sitio. */
const PRECARGA = [
  './',
  'index.html',
  'app/vendedor.html',
  'app/socio-config.js',
  'app/socio-precios.js',
  'app/socio-catalogo.js',
  'app/socio-datos.js',
  'manifest.webmanifest',
  'icons/icon-192.png',
  'icons/icon-512.png',
  'icons/apple-touch-icon.png'
];

/* Lo de Supabase no se toca nunca. */
function esDatos(url) {
  return url.hostname.endsWith('.supabase.co') ||
         url.hostname.endsWith('.supabase.in') ||
         url.pathname.startsWith('/rest/v1') ||
         url.pathname.startsWith('/auth/v1') ||
         url.pathname.startsWith('/storage/v1');
}

/* Librerías y tipografías de terceros: llevan la versión en la URL, así que
   una vez guardadas no cambian. */
function esLibreriaExterna(url) {
  return url.hostname === 'cdn.jsdelivr.net' ||
         url.hostname === 'fonts.googleapis.com' ||
         url.hostname === 'fonts.gstatic.com';
}

self.addEventListener('install', (e) => {
  e.waitUntil((async () => {
    const c = await caches.open(ARMAZON);
    // Una sola pieza que falle no puede tumbar la instalación entera: se
    // guardan de una en una y se sigue adelante con las que sí estén.
    await Promise.all(PRECARGA.map((r) => c.add(r).catch(() => {})));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    const nombres = await caches.keys();
    await Promise.all(nombres.filter((n) => n !== ARMAZON).map((n) => caches.delete(n)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;             // nada de POST: son escrituras

  const url = new URL(req.url);
  if (esDatos(url)) return;                     // Supabase, directo a la red

  // Páginas: red primero, caché solo si no hay señal.
  if (req.mode === 'navigate') {
    e.respondWith((async () => {
      try {
        const red = await fetch(req);
        const c = await caches.open(ARMAZON);
        c.put(req, red.clone());
        return red;
      } catch (_) {
        return (await caches.match(req)) ||
               (await caches.match('app/vendedor.html')) ||
               (await caches.match('index.html')) ||
               new Response('<!doctype html><meta charset="utf-8">' +
                 '<div style="font-family:system-ui;padding:32px;text-align:center">' +
                 '<h1>Sin conexión</h1><p>Vuelve a abrir cuando tengas señal.</p></div>',
                 { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
      }
    })());
    return;
  }

  // Librerías externas: caché primero, que no cambian.
  if (esLibreriaExterna(url)) {
    e.respondWith((async () => {
      const guardada = await caches.match(req);
      if (guardada) return guardada;
      const red = await fetch(req);
      if (red && (red.ok || red.type === 'opaque')) {
        (await caches.open(ARMAZON)).put(req, red.clone());
      }
      return red;
    })());
    return;
  }

  // Lo propio (scripts, iconos): se sirve lo guardado y se refresca por detrás.
  if (url.origin === self.location.origin) {
    e.respondWith((async () => {
      const guardada = await caches.match(req);
      const red = fetch(req).then(async (r) => {
        if (r && r.ok) (await caches.open(ARMAZON)).put(req, r.clone());
        return r;
      }).catch(() => guardada);
      return guardada || red;
    })());
  }
});
