/* Prueba de la app del socio EN UN NAVEGADOR DE VERDAD.

   Las otras dos pruebas de esta carpeta comprueban cálculos sueltos. Ésta abre
   vendedor.html en Chromium y comprueba lo que ninguna de las dos puede: que la
   página arranca sin errores, que el catálogo que se ve es el de la base y no el
   de demostración, y —lo que más importa— que al registrar una venta NO sale
   ningún precio desde el teléfono.

   Se corre con:   node app/pruebas/probar-vendedor-en-navegador.js

   Necesita Chromium, que no viene con el proyecto:

       npm install playwright-core
       npx playwright install chromium

   Si no está instalado, la prueba se salta y lo dice — no falla, para que quien
   solo venga a tocar el HTML no se encuentre con un error que no le toca.

   No toca ningún Supabase real: el cliente es de mentira y vive aquí abajo.
   Lo que se comprueba es lo que la app LE PIDE a la base, que es justamente
   donde estaban los fallos. */

var path = require("path");
var fs = require("fs");
var PAGINA = "file://" + path.join(__dirname, "..", "vendedor.html");

var chromium;
try {
  chromium = require("playwright-core").chromium;
} catch (e) {
  console.log("\n  SALTADA · falta Chromium para esta prueba.");
  console.log("  Para correrla:  npm install playwright-core && npx playwright install chromium\n");
  process.exit(0);
}

/* Dónde está Chromium.

   En un contenedor de CI o de Claude Code en la nube suele venir ya instalado,
   pero puede ser una versión distinta de la que playwright-core espera, y
   entonces se da por vencido y la prueba se salta sin haber probado nada. Si
   encontramos un binario, se lo decimos en vez de dejar que lo busque.

   SOCIO_CHROMIUM=/ruta/al/chrome fuerza uno concreto. */
function rutaDeChromium() {
  if (process.env.SOCIO_CHROMIUM) return process.env.SOCIO_CHROMIUM;
  var base = process.env.PLAYWRIGHT_BROWSERS_PATH || "/opt/pw-browsers";
  try {
    var dirs = fs.readdirSync(base)
                 .filter(function (d) { return /^chromium-\d+$/.test(d); })
                 .sort();
    for (var i = dirs.length - 1; i >= 0; i--) {
      var bin = path.join(base, dirs[i], "chrome-linux", "chrome");
      if (fs.existsSync(bin)) return bin;
    }
  } catch (e) { /* no hay nada preinstalado; que lo busque playwright */ }
  return null;
}

var fallos = [];
function comprobar(nombre, condicion, detalle) {
  if (condicion) { console.log("  ok · " + nombre); return; }
  fallos.push(nombre + (detalle ? "\n      " + detalle : ""));
  console.log("  NO · " + nombre);
}

/* ------------------------------------------------------------------ */
/* El Supabase de mentira                                              */
/* ------------------------------------------------------------------ */
/* Responde lo que respondería la base de verdad: dos presentaciones de un
   producto de una marca que despacha desde Arequipa y Trujillo —a propósito
   NO Cusco y Lima, para que se note si algo sigue leyendo la lista fija— y un
   socio con 30 ventas entregadas, que es nivel Oro. */

/* El socio que devuelve la base. `nivel` es lo que decide el nivel en pantalla;
   `ventas_entregadas` solo alimenta la barra de progreso y el respaldo. En la
   base real NUNCA falta `nivel`: la columna tiene default 'bronce' y la mueve
   el trigger actualizar_nivel_socio(). */
var SOCIO_BASE = {
  id: "55555555-5555-5555-5555-555555555555", nombre: "Ana Prueba",
  dni: "70111222", celular: "987654321", ciudad: "Lima",
  validado: true, nivel: "oro", ventas_entregadas: 30
};

function stubDeSupabase(datos) {
  var socioFingido = datos && datos.socio ? datos.socio : datos;
  var PEDIDOS = (datos && datos.pedidos) || [];
  var MARCA = {
    marca_id: "22222222-2222-2222-2222-222222222222",
    marca: "Marca Prueba", marca_giro: "alimentos",
    marca_ciudad_almacen: "Arequipa", marca_ciudad_punto: "Trujillo"
  };
  var COMUN = {
    producto_id: "11111111-1111-1111-1111-111111111111",
    producto: "Café en grano", nombre_comprobante: "CAFE", categoria: "Bebidas",
    emoji: "☕", descripcion: "Tostado medio", recomendaciones: "Vender por kilo",
    tiempo_prep: "1 día"
  };
  function fila(extra) {
    var f = {}, k;
    for (k in MARCA) f[k] = MARCA[k];
    for (k in COMUN) f[k] = COMUN[k];
    for (k in extra) f[k] = extra[k];
    return f;
  }
  var CATALOGO = [
    fila({ id: "33333333-3333-3333-3333-333333333333", presentacion: "1 kg",
           precio_publico: "80.00", stock_almacen: 10, stock_punto: 4 }),
    fila({ id: "44444444-4444-4444-4444-444444444444", presentacion: "500 g",
           precio_publico: "45.00", stock_almacen: 7, stock_punto: 2 })
  ];
  var SOCIO = socioFingido;

  window.__llamadas = [];          // lo que la app le pidió a la base
  window.__subidas  = [];          // las capturas que subió al cubo

  function consulta(filas) {
    var t = {
      select: function () { return t; },
      eq: function () { return t; },
      order: function () { return Promise.resolve({ data: filas, error: null }); },
      maybeSingle: function () { return Promise.resolve({ data: filas[0] || null, error: null }); },
      single: function () { return Promise.resolve({ data: filas[0] || null, error: null }); },
      then: function (r) { return Promise.resolve({ data: filas, error: null }).then(r); }
    };
    return t;
  }

  window.supabase = {
    createClient: function () {
      return {
        auth: {
          getSession: function () { return Promise.resolve({ data: { session: { user: { id: SOCIO.id } } } }); },
          signInWithPassword: function () { return Promise.resolve({ data: {}, error: null }); },
          signUp: function () { return Promise.resolve({ data: { user: { id: SOCIO.id }, session: {} }, error: null }); },
          signOut: function () { return Promise.resolve({}); }
        },
        from: function (tabla) {
          if (tabla === "catalogo_publico") return consulta(CATALOGO);
          if (tabla === "usuarios_socios")  return consulta([SOCIO]);
          if (tabla === "pedidos_socio")    return consulta(PEDIDOS);
          return consulta([]);
        },
        /* El cubo de capturas. La app sube el archivo ANTES de declarar el
           pago, así que sin esto el circuito se corta aquí. */
        storage: {
          from: function (cubo) {
            return {
              upload: function (ruta, archivo) {
                window.__subidas.push({ cubo: cubo, ruta: ruta, tipo: archivo && archivo.type });
                return Promise.resolve({ data: { path: ruta }, error: null });
              },
              createSignedUrl: function (ruta) {
                return Promise.resolve({ data: { signedUrl: "https://firmada/" + ruta }, error: null });
              }
            };
          }
        },
        rpc: function (nombre, args) {
          window.__llamadas.push({ nombre: nombre, args: args });
          if (nombre === "crear_pedido") return Promise.resolve({ data: [{
            pedido_id: "66666666-6666-6666-6666-666666666666", codigo: "SOC-0919-TEST",
            precio_socio: 64, ganancia_socio: 16, precio_publico: 80, monto_esperado: 64.07
          }], error: null });
          if (nombre === "declarar_pago") return Promise.resolve({ data: [{
            pago_id: "77777777-7777-7777-7777-777777777777",
            monto_esperado: 64.07, cuadra: true
          }], error: null });
          if (nombre === "confirmar_entrega") return Promise.resolve({ data: [{
            codigo: "SOC-0921-CAMINO", estado: "entregado",
            entregado_en: "2026-09-21T12:00:00Z"
          }], error: null });
          return Promise.resolve({ data: [], error: null });
        }
      };
    }
  };
}

/* ------------------------------------------------------------------ */

async function principal() {
  var navegador;
  var bin = rutaDeChromium();
  try {
    navegador = await chromium.launch(bin ? { executablePath: bin } : {});
  } catch (e) {
    console.log("\n  SALTADA · Chromium no se pudo abrir: " + e.message);
    console.log("  Para instalarlo:  npx playwright install chromium\n");
    process.exit(0);
  }

  /* Abre la página con la conexión puesta o quitada, y con o sin el cliente
     de mentira. La librería del CDN se corta siempre: aquí no hay internet
     que valga, y así "configurado pero sin librería" es un caso de verdad. */
  async function abrir(opciones) {
    var ctx = await navegador.newContext();
    var pg = await ctx.newPage();
    var errores = [];
    pg.on("pageerror", function (e) { errores.push(String(e)); });
    await pg.route("**/supabase-js@**", function (r) { return r.abort(); });
    await pg.route("**/socio-config.js", function (r) {
      return r.fulfill({
        contentType: "application/javascript",
        body: opciones.config
          ? 'window.SOCIO_CONFIG={URL:"https://x.supabase.co",ANON:"anon-de-prueba"};'
          : 'window.SOCIO_CONFIG={URL:"",ANON:""};'
      });
    });
    if (opciones.base) await pg.addInitScript(stubDeSupabase, {
      socio: opciones.socio || SOCIO_BASE,
      pedidos: opciones.pedidos || []
    });
    await pg.goto(PAGINA);
    await pg.waitForTimeout(900);
    return { pg: pg, ctx: ctx, errores: errores };
  }

  /* ---- 1 · sin configurar: sigue funcionando como siempre ---- */
  console.log("\n### 1 · sin configurar (modo local, catálogo de demostración)");
  var a = await abrir({ config: false, base: false });
  comprobar("la página carga sin errores de JS", a.errores.length === 0, a.errores[0]);
  var e = await a.pg.evaluate(function () {
    return { prods: productos.length, conectado: CONECTADO };
  });
  comprobar("CONECTADO = false", e.conectado === false);
  comprobar("los 47 productos de demostración siguen ahí", e.prods === 47, "hay " + e.prods);
  await a.ctx.close();

  /* ---- 2 · configurado pero caído: no puede enseñar datos falsos ---- */
  console.log("\n### 2 · configurado pero sin conexión");
  a = await abrir({ config: true, base: false });
  comprobar("la página carga sin errores de JS", a.errores.length === 0, a.errores[0]);
  e = await a.pg.evaluate(function () {
    return { rota: CONEXION_ROTA, conectado: CONECTADO };
  });
  comprobar("CONEXION_ROTA = true", e.rota === true);
  comprobar("CONECTADO = false", e.conectado === false);
  var entro = await a.pg.evaluate(function () { entrarInvitado(); return invitado; });
  comprobar("el modo invitado se NIEGA a entrar", entro === false);
  await a.ctx.close();

  /* ---- 3 · conectado ---- */
  console.log("\n### 3 · conectado (catálogo, nivel y pedido reales)");
  a = await abrir({ config: true, base: true });
  comprobar("la página carga sin errores de JS", a.errores.length === 0, a.errores[0]);
  e = await a.pg.evaluate(function () { return { conectado: CONECTADO }; });
  comprobar("CONECTADO = true", e.conectado === true);

  await a.pg.waitForTimeout(600);
  var s = await a.pg.evaluate(function () {
    return {
      prods: productos.length,
      marca: marcas[0] ? { nombre: marcas[0].nombre, almacen: marcas[0].ciudadAlmacen } : null,
      ventas: ventasHechas(), nivel: nivelActual().id, ganancia: gananciaRef(),
      idsPres: productos[0] ? productos[0].variantes.map(function (v) { return v.id; }) : []
    };
  });
  comprobar("el catálogo es el de la base, no el de demostración", s.prods === 1, "hay " + s.prods);
  comprobar("la marca viene de la base", s.marca && s.marca.nombre === "Marca Prueba");
  comprobar("la ciudad de almacén sale de la marca, no de ORIGENES",
            s.marca && s.marca.almacen === "Arequipa", JSON.stringify(s.marca));
  comprobar("el nivel es el que trae la ficha de la base (oro)",
            s.nivel === "oro", s.nivel + " / " + s.ventas + " ventas");
  comprobar("la ganancia referencial es la del nivel, no un 10% fijo",
            s.ganancia === "16%", s.ganancia);
  comprobar("las presentaciones conservan su UUID",
            s.idsPres[0] && s.idsPres[0].length === 36);

  /* El fallo del separador: los id de la base llevan guiones dentro y la clave
     del carrito se partía por donde no era. */
  var clave = await a.pg.evaluate(function () {
    var p = productos[0];
    var c = claveItem(p.id, 0, "cusco");
    var r = buscaItem(c);
    return { hallado: !!(r && r.p && r.v), idPres: r && r.v && r.v.id };
  });
  comprobar("la clave del carrito sobrevive a los UUID",
            clave.hallado && clave.idPres === "33333333-3333-3333-3333-333333333333",
            JSON.stringify(clave));

  /* Registrar una venta de punta a punta, en los dos pasos que ahora son.

     El orden importa y es lo que esta prueba vigila: PRIMERO se registra el
     pedido —y recién entonces la base dice cuánto hay que depositar, con sus
     céntimos— y DESPUÉS se sube la captura y se declara el pago. Al revés, el
     socio depositaría una cifra redonda que no se puede distinguir de las
     demás del día en el estado de cuenta. */
  var paso1 = await a.pg.evaluate(async function () {
    var p = productos[0];
    carrito = {}; carrito[claveItem(p.id, 0, "cusco")] = 2;
    ultimoMetodo = "qr";
    document.getElementById("r-cli-nombre").value = "Cliente Prueba";
    document.getElementById("r-cli-dni").value    = "70999888";
    document.getElementById("r-cli-cel").value    = "987111222";
    document.getElementById("r-cli-dir").value    = "Av. Siempre Viva 123";
    /* Por agencia, que es lo único que despacha el origen de esta prueba
       (Cusco): modoEnvio("local") lo rechazaría la propia app. */
    document.getElementById("r-ciudad-envio").value  = "lima";
    document.getElementById("r-agencia-local").value = "Shalom Av. Aviación 2345";

    continuarPago();
    await new Promise(function (r) { setTimeout(r, 600); });

    return {
      llamadas: window.__llamadas.slice(),
      pantalla: document.querySelector(".pantalla.activa").id,
      monto:    document.getElementById("pago-total").textContent,
      codigo:   document.getElementById("pago-codigo").textContent,
      carritoVacio: Object.keys(carrito).length === 0
    };
  });

  var crear = paso1.llamadas.filter(function (x) { return x.nombre === "crear_pedido"; })[0];
  comprobar("registrar el pedido NO declara todavía ningún pago",
            paso1.llamadas.filter(function (x) { return x.nombre === "declarar_pago"; }).length === 0);
  comprobar("se llama a crear_pedido()", !!crear);
  comprobar("se pasa a la pantalla del depósito", paso1.pantalla === "p-pago", paso1.pantalla);
  comprobar("la pantalla muestra el monto EXACTO que dio la base",
            paso1.monto === "S/ 64.07", paso1.monto);
  comprobar("y el código del pedido que ya existe",
            paso1.codigo === "SOC-0919-TEST", paso1.codigo);
  comprobar("el carrito se vacía: el pedido ya está en la base", paso1.carritoVacio);

  if (crear) {
    // Lo que de verdad protege el dinero: que el teléfono no mande importes.
    var json = JSON.stringify(crear.args);
    comprobar("NO viaja ningún precio desde el teléfono",
              !/precio|monto|sug|total/i.test(json), json);
    comprobar("viajan presentación y cantidad, nada más",
              crear.args.p_items[0].presentacion_id.length === 36 &&
              crear.args.p_items[0].cantidad === 2,
              JSON.stringify(crear.args.p_items));
  }

  /* Paso 2: el socio vuelve del banco con su captura. */
  var paso2 = await a.pg.evaluate(async function () {
    function intentar() {
      confirmarDeposito();
      return new Promise(function (r) { setTimeout(r, 400); });
    }

    // Sin número de operación ni captura: no debe declararse nada.
    document.getElementById("r-operacion").value = "";
    await intentar();
    var sinNada = window.__llamadas.filter(function (x) { return x.nombre === "declarar_pago"; }).length;

    // Con número pero sin captura: tampoco. Mientras no haya pasarela, la
    // captura es la única evidencia del depósito.
    document.getElementById("r-operacion").value = "OP-12345";
    await intentar();
    var sinCaptura = window.__llamadas.filter(function (x) { return x.nombre === "declarar_pago"; }).length;

    // Ahora sí, con la captura adjunta.
    var dt = new DataTransfer();
    dt.items.add(new File([new Uint8Array([1,2,3,4])], "voucher.png", { type: "image/png" }));
    var inp = document.getElementById("input-voucher");
    inp.files = dt.files;
    inp.dispatchEvent(new Event("change"));
    await intentar();

    return {
      sinNada: sinNada,
      sinCaptura: sinCaptura,
      llamadas: window.__llamadas.slice(),
      subidas: window.__subidas.slice(),
      pantalla: document.querySelector(".pantalla.activa").id,
      codigo: document.getElementById("conf-codigo").textContent
    };
  });

  comprobar("sin N° de operación no se declara nada", paso2.sinNada === 0);
  comprobar("sin captura tampoco: es la única evidencia del depósito", paso2.sinCaptura === 0);

  var subida = paso2.subidas[0];
  comprobar("la captura se sube al cubo de vouchers",
            !!subida && subida.cubo === "vouchers", JSON.stringify(paso2.subidas));
  comprobar("y va dentro de la carpeta del socio, que es de donde cuelgan los permisos",
            !!subida && subida.ruta.indexOf("55555555-5555-5555-5555-555555555555/") === 0,
            subida && subida.ruta);

  var pagar = paso2.llamadas.filter(function (x) { return x.nombre === "declarar_pago"; })[0];
  comprobar("se llama a declarar_pago()", !!pagar);
  if (pagar) {
    comprobar("el pago lleva el N° de operación", pagar.args.p_numero_operacion === "OP-12345");
    comprobar("el pago lleva la ruta de la captura",
              !!pagar.args.p_voucher_url, JSON.stringify(pagar.args.p_voucher_url));
    comprobar("y su huella, que es lo que detecta la captura reusada",
              typeof pagar.args.p_hash_imagen === "string" && pagar.args.p_hash_imagen.length === 64,
              String(pagar.args.p_hash_imagen));
    comprobar("el pago es del pedido que se acaba de registrar",
              pagar.args.p_pedido_id === "66666666-6666-6666-6666-666666666666");
  }
  comprobar("la confirmación muestra el código que dio la base",
            paso2.codigo === "SOC-0919-TEST", paso2.codigo);
  await a.ctx.close();

  /* ---- 4 · de dónde sale el nivel ---- */
  /* El nivel tiene un solo dueño: la base. Lo mueve su trigger cuando una
     entrega se confirma, y la pantalla lo lee, no lo recalcula. Esto importa
     porque del nivel cuelga el descuento que se le aplica al socio en TODO el
     catálogo: si la pantalla se lo calculara por su cuenta y no coincidiera,
     le estaría cobrando de menos o de más.

     Los tres casos son el camino real, el respaldo, y el desacuerdo entre
     ambos — que es donde se ve quién manda. */
  console.log("\n### 4 · el nivel lo decide la base, no la pantalla");
  var CASOS = [
    { que:  "la ficha trae su nivel: se usa tal cual",
      socio: { nivel: "oro", ventas_entregadas: 30 },
      nivel: "oro", ganancia: "16%" },

    { que:  "la ficha no trae nivel: se deduce de las entregas",
      socio: { nivel: undefined, ventas_entregadas: 30 },
      nivel: "oro", ganancia: "16%" },

    { que:  "si no concuerdan, manda el nivel de la base",
      socio: { nivel: "diamante", ventas_entregadas: 30 },
      nivel: "diamante", ganancia: "20%" }
  ];

  for (var i = 0; i < CASOS.length; i++) {
    var caso = CASOS[i];
    var socio = {};
    for (var k in SOCIO_BASE) socio[k] = SOCIO_BASE[k];
    for (var k2 in caso.socio) socio[k2] = caso.socio[k2];
    if (caso.socio.nivel === undefined) delete socio.nivel;

    var b = await abrir({ config: true, base: true, socio: socio });
    await b.pg.waitForTimeout(600);
    var r = await b.pg.evaluate(function () {
      return { nivel: nivelActual().id, ganancia: gananciaRef() };
    });
    comprobar(caso.que + " → " + caso.nivel,
              r.nivel === caso.nivel && r.ganancia === caso.ganancia,
              "salió " + r.nivel + " con " + r.ganancia);
    await b.ctx.close();
  }

  /* Y lo que motivó todo esto: registrar un pedido no asciende a nadie. */
  var c = await abrir({ config: true, base: true,
                        socio: Object.assign({}, SOCIO_BASE, { nivel: "plata", ventas_entregadas: 10 }) });
  await c.pg.waitForTimeout(600);
  var tras = await c.pg.evaluate(async function () {
    var antes = nivelActual().id;
    var p = productos[0];
    carrito = {}; carrito[claveItem(p.id, 0, "cusco")] = 2;
    ultimoMetodo = "qr";
    ["r-cli-nombre","r-cli-dni","r-cli-cel","r-cli-dir"].forEach(function (id, n) {
      document.getElementById(id).value = ["Cliente Prueba","70999888","987111222","Av. Siempre Viva 123"][n];
    });
    document.getElementById("r-ciudad-envio").value  = "lima";
    document.getElementById("r-agencia-local").value = "Shalom Av. Aviación 2345";
    continuarPago();
    await new Promise(function (r) { setTimeout(r, 600); });

    document.getElementById("r-operacion").value = "OP-54321";
    var dt = new DataTransfer();
    dt.items.add(new File([new Uint8Array([9,9,9])], "v.png", { type: "image/png" }));
    var inp = document.getElementById("input-voucher");
    inp.files = dt.files;
    inp.dispatchEvent(new Event("change"));
    confirmarDeposito();
    await new Promise(function (r) { setTimeout(r, 900); });
    return { antes: antes, despues: nivelActual().id };
  });
  comprobar("registrar un pedido NO sube de nivel",
            tras.antes === "plata" && tras.despues === "plata",
            tras.antes + " → " + tras.despues);
  await c.ctx.close();

  /* ---- 5 · el socio cierra el circuito: confirma que llegó ---- */
  console.log("\n### 5 · el pedido en camino lo cierra el socio");
  var PEDIDO_EN_CAMINO = {
    id: "88888888-8888-8888-8888-888888888888", codigo: "SOC-0921-CAMINO",
    socio_id: SOCIO_BASE.id, marca: "Marca Prueba",
    precio_publico: "80.00", precio_socio: "64.00", ganancia_socio: "16.00", costo_envio: "0",
    destinatario: "Cliente Uno", doc_destinatario: "70111222", celular_destinatario: "987111222",
    origen: "almacen", modo_entrega: "agencia", agencia: "shalom", detalle_entrega: "Shalom Arequipa",
    numero_guia: "G-77", courier: "shalom", tracking: "T-77", guia_url: "marca/G-77.jpg",
    estado: "en_camino", creado_en: "2026-09-20T10:00:00Z", despachado_en: "2026-09-20T17:00:00Z"
  };
  var d = await abrir({ config: true, base: true, pedidos: [PEDIDO_EN_CAMINO] });
  comprobar("la página carga sin errores de JS", d.errores.length === 0, d.errores[0]);
  await d.pg.waitForTimeout(700);

  var vista = await d.pg.evaluate(function () {
    irA("p-pedidos");
    return {
      html: document.getElementById("lista-pedidos").innerHTML,
      estado: (misPedidos()[0] || {}).estado
    };
  });
  comprobar("el pedido se ve 'En camino'", vista.estado === "En camino", vista.estado);
  comprobar("y trae el botón para confirmar que llegó",
            vista.html.indexOf("Ya le llegó a mi cliente") !== -1);
  comprobar("con la guía y el tracking a la vista",
            vista.html.indexOf("G-77") !== -1 && vista.html.indexOf("T-77") !== -1);

  var cerrado = await d.pg.evaluate(async function () {
    window.confirm = function () { return true; };
    confirmarQueLlego("SOC-0921-CAMINO");
    await new Promise(function (r) { setTimeout(r, 700); });
    return window.__llamadas.filter(function (l) { return l.nombre === "confirmar_entrega"; });
  });
  comprobar("confirmar llama a confirmar_entrega() con el id del pedido",
            cerrado.length === 1 && cerrado[0].args.p_pedido_id === PEDIDO_EN_CAMINO.id,
            JSON.stringify(cerrado));
  await d.ctx.close();

  await navegador.close();

  if (fallos.length) {
    console.log("\n  " + fallos.length + " fallaron:\n");
    fallos.forEach(function (f) { console.log("    " + f); });
    console.log("");
    process.exit(1);
  }
  console.log("\n  todo en orden\n");
}

principal().catch(function (e) {
  console.error("\n  La prueba se rompió: " + (e && e.stack || e) + "\n");
  process.exit(1);
});
