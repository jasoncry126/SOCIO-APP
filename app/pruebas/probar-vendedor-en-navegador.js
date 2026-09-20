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
var PAGINA = "file://" + path.join(__dirname, "..", "vendedor.html");

var chromium;
try {
  chromium = require("playwright-core").chromium;
} catch (e) {
  console.log("\n  SALTADA · falta Chromium para esta prueba.");
  console.log("  Para correrla:  npm install playwright-core && npx playwright install chromium\n");
  process.exit(0);
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

var SOCIO_FINGIDO = null;   // se rellena dentro del navegador

function stubDeSupabase() {
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
  var SOCIO = {
    id: "55555555-5555-5555-5555-555555555555", nombre: "Ana Prueba",
    dni: "70111222", celular: "987654321", ciudad: "Lima",
    validado: true, ventas_entregadas: 30
  };

  window.__llamadas = [];          // lo que la app le pidió a la base

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
          return consulta([]);                       // pedidos_socio: sin pedidos
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
          return Promise.resolve({ data: [], error: null });
        }
      };
    }
  };
}

/* ------------------------------------------------------------------ */

async function principal() {
  var navegador;
  try {
    navegador = await chromium.launch();
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
    if (opciones.base) await pg.addInitScript(stubDeSupabase);
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
  comprobar("el nivel usa ventas ENTREGADAS de la base (30 → oro)",
            s.ventas === 30 && s.nivel === "oro", s.nivel + " / " + s.ventas);
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

  /* Registrar una venta de punta a punta. */
  var venta = await a.pg.evaluate(async function () {
    var p = productos[0];
    carrito = {}; carrito[claveItem(p.id, 0, "cusco")] = 2;
    ultimoMetodo = "qr";
    document.getElementById("r-cli-nombre").value = "Cliente Prueba";
    document.getElementById("r-cli-dni").value    = "70999888";
    document.getElementById("r-cli-cel").value    = "987111222";
    document.getElementById("r-cli-dir").value    = "Av. Siempre Viva 123";

    document.getElementById("r-operacion").value = "";
    registrarPedido();                       // sin N° de operación: no debe hacer nada
    await new Promise(function (r) { setTimeout(r, 300); });
    var sinOperacion = window.__llamadas.length;

    document.getElementById("r-operacion").value = "OP-12345";
    registrarPedido();
    await new Promise(function (r) { setTimeout(r, 600); });

    return {
      sinOperacion: sinOperacion,
      llamadas: window.__llamadas,
      codigo: document.getElementById("conf-codigo").textContent
    };
  });

  comprobar("sin N° de operación no se registra nada", venta.sinOperacion === 0);
  var crear = venta.llamadas.filter(function (x) { return x.nombre === "crear_pedido"; })[0];
  var pagar = venta.llamadas.filter(function (x) { return x.nombre === "declarar_pago"; })[0];
  comprobar("se llama a crear_pedido()", !!crear);
  comprobar("se llama a declarar_pago()", !!pagar);

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
  if (pagar) {
    comprobar("el pago lleva el N° de operación", pagar.args.p_numero_operacion === "OP-12345");
  }
  comprobar("la confirmación muestra el código que dio la base",
            venta.codigo === "SOC-0919-TEST", venta.codigo);
  await a.ctx.close();

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
