/* Prueba del PAQUETE que se sube a Netlify.

   Las otras pruebas de esta carpeta miran el código del repositorio. Ésta mira
   el zip: lo descomprime, lo sirve como lo serviría Netlify —en la raíz, sin
   carpeta que lo envuelva— y abre las cuatro pantallas en Chromium para
   comprobar tres cosas que solo se rompen al empaquetar:

     · que no falte ningún archivo (una ruta relativa que apunte fuera del zip),
     · que el sitio arranque CONECTADO a la base y no en modo demostración,
     · que el manifiesto siga sirviendo para instalarla en el celular.

   Se corre con:   node app/pruebas/probar-paquete-netlify.js

   Antes hay que armar el paquete:  bash herramientas/armar-zip-netlify.sh

   Necesita Chromium. Si no está, la prueba se salta y lo dice.

   La librería de Supabase se carga desde un CDN, que no siempre se alcanza
   desde donde se corran las pruebas. Se sustituye por una de mentira para que
   lo que se mida sea el paquete y no la conexión de quien prueba.
*/

const http = require('http');
const fs   = require('fs');
const path = require('path');
const os   = require('os');
const { execSync } = require('child_process');

const RAIZ = path.join(__dirname, '..', '..');
const ZIP  = path.join(RAIZ, 'dist', 'socio-netlify.zip');
const PUERTO = 8097;

const TIPOS = { '.html':'text/html', '.js':'text/javascript', '.json':'application/json',
                '.webp':'image/webp', '.png':'image/png', '.md':'text/plain', '.toml':'text/plain' };

let chromium;
try { ({ chromium } = require('playwright-core')); }
catch { try { ({ chromium } = require('playwright')); } catch {} }

if (!chromium) {
  console.log('Sin Chromium instalado: la prueba se salta.');
  console.log('   npm install playwright-core && npx playwright install chromium');
  process.exit(0);
}

if (!fs.existsSync(ZIP)) {
  console.error('No encuentro ' + ZIP);
  console.error('Ármalo primero:  bash herramientas/armar-zip-netlify.sh');
  process.exit(1);
}

const ejecutable = process.env.CHROMIUM
  || ['/opt/pw-browsers/chromium', '/usr/bin/chromium', '/usr/bin/chromium-browser']
       .find(p => fs.existsSync(p));

let fallos = 0;
const comprobar = (ok, texto) => {
  console.log((ok ? '  ok  ' : 'FALLA') + ' · ' + texto);
  if (!ok) fallos++;
};

(async () => {
  const sitio = fs.mkdtempSync(path.join(os.tmpdir(), 'socio-paquete-'));
  execSync('unzip -q -o ' + JSON.stringify(ZIP) + ' -d ' + JSON.stringify(sitio));

  const servidor = http.createServer((req, res) => {
    let ruta = decodeURIComponent(req.url.split('?')[0]);
    if (ruta.endsWith('/')) ruta += 'index.html';
    const archivo = path.join(sitio, ruta);
    if (!archivo.startsWith(sitio) || !fs.existsSync(archivo) || fs.statSync(archivo).isDirectory()) {
      res.writeHead(404); return res.end('no está');
    }
    res.writeHead(200, { 'Content-Type': TIPOS[path.extname(archivo)] || 'application/octet-stream' });
    res.end(fs.readFileSync(archivo));
  });
  await new Promise(r => servidor.listen(PUERTO, r));

  const navegador = await chromium.launch(
    Object.assign({ args: ['--no-sandbox'] }, ejecutable ? { executablePath: ejecutable } : {}));

  const contexto = await navegador.newContext();
  // La librería de Supabase, de mentira: solo tiene que existir.
  await contexto.addInitScript(() => {
    window.supabase = { createClient: () => ({
      auth: { getUser: async () => ({ data: { user: null } }),
              getSession: async () => ({ data: { session: null } }),
              onAuthStateChange: () => ({ data: { subscription: { unsubscribe(){} } } }) },
      from: () => ({ select: () => ({ data: [], error: null }) }),
      rpc:  async () => ({ data: null, error: null })
    }) };
  });

  const pantallas = [
    ['/',                        'la portada'],
    ['/app/vendedor.html',       'la app del socio'],
    ['/app/proveedor.html',      'el panel de la marca'],
    ['/app/administrador.html',  'el panel de SOCIO']
  ];

  for (const [ruta, nombre] of pantallas) {
    const pagina = await contexto.newPage();
    const errores = [], faltantes = [];
    pagina.on('pageerror', e => errores.push(e.message));
    pagina.on('response', r => {
      const u = r.url();
      if (r.status() >= 400 && u.startsWith('http://localhost:' + PUERTO)) faltantes.push(r.status() + ' ' + u);
    });
    await pagina.goto('http://localhost:' + PUERTO + ruta, { waitUntil: 'load' });
    await pagina.waitForTimeout(300);

    console.log('\n--- ' + nombre + ' ---');
    comprobar(errores.length === 0,  'abre sin errores' + (errores.length ? ': ' + errores[0] : ''));
    comprobar(faltantes.length === 0, 'no le falta ningún archivo' + (faltantes.length ? ': ' + faltantes.join(', ') : ''));

    if (ruta === '/') {
      const enlaces = await pagina.$$eval('a.panel', as => as.map(a => a.getAttribute('href')));
      comprobar(enlaces.length === 3, 'enlaza los tres paneles');
      for (const e of enlaces) {
        comprobar(fs.existsSync(path.join(sitio, e)), 'el enlace ' + e + ' está dentro del paquete');
      }
    } else {
      const cfg = await pagina.evaluate(() => window.SOCIO_CONFIG || null);
      comprobar(!!(cfg && cfg.URL && cfg.ANON), 'lleva la conexión a Supabase puesta');
      // El panel de SOCIO no tiene la bandera CONECTADO: pregunta directo a la
      // capa de datos. Las otras dos sí, y es la que decide su modo.
      const conectado = await pagina.evaluate(() =>
        typeof CONECTADO !== 'undefined'
          ? CONECTADO
          : !!(window.SocioDatos && window.SocioDatos.configurado()));
      comprobar(conectado === true, 'arranca conectado a la base, no en demostración');
    }
    await pagina.close();
  }

  console.log('\n--- instalable en el celular ---');
  const manifiesto = JSON.parse(fs.readFileSync(path.join(sitio, 'manifest.json'), 'utf8'));
  comprobar(!manifiesto.id.startsWith('/SOCIO-APP'), 'el manifiesto no arrastra la ruta de GitHub Pages');
  comprobar(fs.existsSync(path.join(sitio, manifiesto.start_url)), 'start_url apunta a una pantalla que existe');
  for (const icono of manifiesto.icons) {
    comprobar(fs.existsSync(path.join(sitio, icono.src)), 'el ícono ' + icono.src + ' viaja en el paquete');
  }
  comprobar(fs.existsSync(path.join(sitio, 'sw.js')), 'el service worker viaja en el paquete');
  comprobar(fs.existsSync(path.join(sitio, 'netlify.toml')), 'netlify.toml viaja en el paquete');

  await navegador.close();
  servidor.close();
  fs.rmSync(sitio, { recursive: true, force: true });

  console.log('\n' + (fallos ? fallos + ' comprobaciones fallidas' : 'Todo en verde.'));
  process.exit(fallos ? 1 : 0);
})();
