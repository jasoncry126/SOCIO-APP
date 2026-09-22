/* Prueba del PANEL DE LA MARCA en un navegador de verdad.

   Comprueba el tramo que antes no existía: que la marca vea en su bandeja los
   pedidos que SOCIO ya validó —con lo que hay que empacar—, que al despachar
   suba la foto de la guía al cubo y escriba en la base, y que NO pueda darse
   por entregada sola, que es el hallazgo que cierra esta rama.

   Se corre con:   node app/pruebas/probar-proveedor-en-navegador.js

   Necesita Chromium; si no está, la prueba se salta y lo dice.
   No toca ningún Supabase real: el cliente es de mentira y vive aquí abajo. */

var path = require("path");
var fs = require("fs");
var PAGINA = "file://" + path.join(__dirname, "..", "proveedor.html");

var chromium;
try {
  chromium = require("playwright-core").chromium;
} catch (e) {
  console.log("\n  SALTADA · falta Chromium para esta prueba.");
  console.log("  Para correrla:  npm install playwright-core && npx playwright install chromium\n");
  process.exit(0);
}

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
  } catch (e) { /* que lo busque playwright */ }
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
/* Una marca 'confiable' —cobra 70% al registrar la guía— con tres pedidos:
   uno validado esperando despacho, uno en camino y uno entregado. */

function stubDeSupabase() {
  var MARCA_ID = "22222222-2222-2222-2222-222222222222";

  var MARCA = {
    id: MARCA_ID, nombre: "Marca Prueba", ruc: "20100000001", giro: "alimentos",
    ciudad_almacen: "Arequipa", ciudad_punto: "Trujillo", celular: "955000001",
    nivel_fiabilidad: "confiable", entregas_ok: 25, creado_en: "2026-01-01T00:00:00Z"
  };

  var PEDIDOS = [
    { id: "p1", codigo: "SOC-0921-AAA1", marca_id: MARCA_ID, socio_id: "s1",
      precio_mayorista: "100.00", costo_envio: "12.00",
      destinatario: "Cliente Uno", doc_destinatario: "70111222", celular_destinatario: "987111222",
      origen: "almacen", modo_entrega: "agencia", agencia: "shalom",
      detalle_entrega: "Shalom Arequipa", numero_guia: null, courier: null, tracking: null,
      guia_url: null, estado: "validado", creado_en: "2026-09-20T10:00:00Z" },
    { id: "p2", codigo: "SOC-0921-BBB2", marca_id: MARCA_ID, socio_id: "s1",
      precio_mayorista: "80.00", costo_envio: "0",
      destinatario: "Cliente Dos", doc_destinatario: "70111333", celular_destinatario: "987111333",
      origen: "almacen", modo_entrega: "domicilio", agencia: null,
      detalle_entrega: "Av. El Sol 200", numero_guia: "G-2", courier: null, tracking: null,
      guia_url: MARCA_ID + "/G-2.jpg", estado: "en_camino", creado_en: "2026-09-19T10:00:00Z" },
    { id: "p3", codigo: "SOC-0921-CCC3", marca_id: MARCA_ID, socio_id: "s1",
      precio_mayorista: "60.00", costo_envio: "8.00",
      destinatario: "Cliente Tres", doc_destinatario: "70111444", celular_destinatario: "987111444",
      origen: "almacen", modo_entrega: "agencia", agencia: "olva",
      detalle_entrega: "Olva Trujillo", numero_guia: "G-3", courier: "olva", tracking: "T-3",
      guia_url: MARCA_ID + "/G-3.jpg", estado: "entregado", creado_en: "2026-09-18T10:00:00Z",
      entregado_en: "2026-09-19T18:00:00Z" },
    /* Un pedido del socio que todavía no cruzó SOCIO: la marca NO debe verlo. */
    { id: "p4", codigo: "SOC-0921-DDD4", marca_id: MARCA_ID, socio_id: "s1",
      precio_mayorista: "50.00", costo_envio: "0",
      destinatario: "Cliente Cuatro", doc_destinatario: "70111555", celular_destinatario: "987111555",
      origen: "almacen", modo_entrega: "domicilio", agencia: null,
      detalle_entrega: "Jr. Lima 100", numero_guia: null, courier: null, tracking: null,
      guia_url: null, estado: "pagado", creado_en: "2026-09-21T10:00:00Z" }
  ];

  var ITEMS = [
    { id: "i1", pedido_id: "p1", presentacion_id: "v1", cantidad: 2,
      precio_unit_mayorista: "50.00", presentacion: "1 kg", producto: "Café en grano", emoji: "☕" },
    { id: "i2", pedido_id: "p2", presentacion_id: "v2", cantidad: 1,
      precio_unit_mayorista: "80.00", presentacion: "500 g", producto: "Café en grano", emoji: "☕" }
  ];

  window.__llamadas = [];     // lo que la app le pidió a la base
  window.__subidas = [];      // lo que subió al cubo
  window.__updates = [];      // lo que escribió en 'pedidos'

  function resuelto(filas) {
    return Promise.resolve({ data: filas, error: null });
  }

  function consulta(tabla, filas) {
    var t = {
      select: function () { return t; },
      eq: function (col, val) {
        t._filtro = { col: col, val: val };
        return t;
      },
      order: function () { return resuelto(filas); },
      maybeSingle: function () { return resuelto(filas[0] || null); },
      single: function () { return resuelto(filas[0] || null); },
      update: function (cambios) {
        return {
          eq: function (col, val) {
            window.__updates.push({ tabla: tabla, cambios: cambios, id: val });
            return resuelto([]);
          }
        };
      },
      then: function (r) { return resuelto(filas).then(r); }
    };
    return t;
  }

  window.supabase = {
    createClient: function () {
      return {
        auth: {
          getSession: function () { return Promise.resolve({ data: { session: { user: { id: MARCA_ID } } } }); },
          signInWithPassword: function () { return Promise.resolve({ data: {}, error: null }); },
          signUp: function () { return Promise.resolve({ data: { user: { id: MARCA_ID }, session: {} }, error: null }); },
          signOut: function () { return Promise.resolve({}); }
        },
        from: function (tabla) {
          window.__llamadas.push({ tabla: tabla });
          if (tabla === "marcas") return consulta(tabla, [MARCA]);
          if (tabla === "pedidos_marca") return consulta(tabla, PEDIDOS);
          if (tabla === "pedido_items_marca") return consulta(tabla, ITEMS);
          if (tabla === "pedidos") return consulta(tabla, []);
          return consulta(tabla, []);
        },
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
          if (nombre === "saldo_disponible") return Promise.resolve({ data: 130.00, error: null });
          if (nombre === "solicitar_retiro") return Promise.resolve({
            data: [{ retiro_id: "r1", monto: args.p_monto, saldo_restante: 0 }], error: null });
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

  /* ---- 1 · sin configurar: el panel suelto sigue funcionando ---- */
  console.log("\n### 1 · sin configurar (modo local, como antes)");
  var a = await abrir({ config: false, base: false });
  comprobar("la página carga sin errores de JS", a.errores.length === 0, a.errores[0]);
  var e = await a.pg.evaluate(function () { return { conectado: CONECTADO }; });
  comprobar("CONECTADO = false", e.conectado === false);
  await a.ctx.close();

  /* ---- 2 · conectado: la bandeja sale de la base ---- */
  console.log("\n### 2 · conectado (los pedidos son los de la base)");
  a = await abrir({ config: true, base: true });
  comprobar("la página carga sin errores de JS", a.errores.length === 0, a.errores[0]);
  await a.pg.waitForTimeout(700);

  var s = await a.pg.evaluate(function () {
    ir("v-pedidos");
    return {
      conectado: CONECTADO,
      marca: marca ? { nombre: marca.nombre, fiab: marca.fiab, entregas: marca.entregasOk } : null,
      pedidos: peds().map(function (p) {
        return { codigo: p.codigo, estado: p.estado, items: p.items, proveedor: p.proveedor, envio: p.envio };
      }),
      nivel: nivelFiab().nombre,
      html: document.getElementById("v-pedidos").innerHTML
    };
  });

  comprobar("CONECTADO = true", s.conectado === true);
  comprobar("la marca viene de la base", s.marca && s.marca.nombre === "Marca Prueba");
  comprobar("su nivel de fiabilidad lo trae la base, no un contador local",
            s.nivel === "Confiable" && s.marca.entregas === 25, s.nivel);
  comprobar("solo ve los pedidos que SOCIO ya validó (3, no 4)",
            s.pedidos.length === 3, JSON.stringify(s.pedidos.map(function (p) { return p.codigo; })));
  comprobar("el pedido validado aparece como 'por despachar'",
            s.pedidos[0] && s.pedidos[0].estado === "pagado", JSON.stringify(s.pedidos[0]));
  comprobar("ve QUÉ empacar, con producto y presentación",
            s.pedidos[0] && s.pedidos[0].items.indexOf("Café en grano") !== -1 &&
            s.pedidos[0].items.indexOf("1 kg") !== -1, s.pedidos[0] && s.pedidos[0].items);
  comprobar("lo que cobra es su precio mayorista, sin el envío encima",
            s.pedidos[0] && s.pedidos[0].proveedor === 100 && s.pedidos[0].envio === 12,
            JSON.stringify(s.pedidos[0]));
  comprobar("el pedido en camino NO trae botón de confirmar entrega",
            s.html.indexOf("confirmarEntrega(") === -1,
            "sigue apareciendo el botón que la auditoría marcó");
  comprobar("y dice que espera al socio",
            s.html.indexOf("Esperando que el socio confirme") !== -1);

  /* ---- 3 · despachar escribe en la base ---- */
  console.log("\n### 3 · despachar sube la guía y escribe en la base");

  var sinFoto = await a.pg.evaluate(async function () {
    document.getElementById("guia-SOC-0921-AAA1").value = "G-NUEVA";
    document.getElementById("courier-SOC-0921-AAA1").value = "shalom";
    document.getElementById("track-SOC-0921-AAA1").value = "T-NUEVA";
    despachar("SOC-0921-AAA1");
    await new Promise(function (r) { setTimeout(r, 400); });
    return { updates: window.__updates.length, aviso: document.getElementById("toast").textContent };
  });
  comprobar("sin la foto de la guía no se despacha", sinFoto.updates === 0, sinFoto.aviso);
  comprobar("y lo dice con palabras claras",
            sinFoto.aviso.indexOf("foto de la guía") !== -1, sinFoto.aviso);

  var conFoto = await a.pg.evaluate(async function () {
    var dt = new DataTransfer();
    dt.items.add(new File([new Uint8Array([1, 2, 3])], "guia.png", { type: "image/png" }));
    var inp = document.getElementById("foto-SOC-0921-AAA1");
    inp.files = dt.files;
    inp.dispatchEvent(new Event("change"));
    despachar("SOC-0921-AAA1");
    await new Promise(function (r) { setTimeout(r, 900); });
    return { subidas: window.__subidas, updates: window.__updates };
  });

  comprobar("la foto sube al cubo 'guias'",
            conFoto.subidas.length === 1 && conFoto.subidas[0].cubo === "guias",
            JSON.stringify(conFoto.subidas));
  comprobar("dentro de la carpeta de la marca",
            conFoto.subidas[0] &&
            conFoto.subidas[0].ruta.indexOf("22222222-2222-2222-2222-222222222222/") === 0,
            conFoto.subidas[0] && conFoto.subidas[0].ruta);
  comprobar("y el pedido se escribe en la base como despachado",
            conFoto.updates.length === 1 &&
            conFoto.updates[0].tabla === "pedidos" &&
            conFoto.updates[0].cambios.estado === "en_camino" &&
            conFoto.updates[0].id === "p1",
            JSON.stringify(conFoto.updates));
  comprobar("con su guía, su courier, su tracking y la ruta de la foto",
            conFoto.updates[0] &&
            conFoto.updates[0].cambios.numero_guia === "G-NUEVA" &&
            conFoto.updates[0].cambios.courier === "shalom" &&
            conFoto.updates[0].cambios.tracking === "T-NUEVA" &&
            !!conFoto.updates[0].cambios.guia_url,
            JSON.stringify(conFoto.updates[0] && conFoto.updates[0].cambios));

  /* ---- 4 · el dinero lo dice la base ---- */
  console.log("\n### 4 · el saldo para retirar lo dice la base");
  var din = await a.pg.evaluate(function () {
    ir("v-liq");
    return { saldo: SALDO, html: document.getElementById("zona-liq").innerHTML };
  });
  comprobar("el saldo sale de saldo_disponible()", din.saldo === 130,
            "SALDO = " + din.saldo);
  comprobar("y es el que se ofrece retirar",
            din.html.indexOf("Retirar S/ 130.00") !== -1);

  var retiro = await a.pg.evaluate(async function () {
    retirar(130);
    await new Promise(function (r) { setTimeout(r, 600); });
    var pedido = window.__llamadas.filter(function (l) { return l.nombre === "solicitar_retiro"; });
    return { pedido: pedido, saldo: SALDO };
  });
  comprobar("pedir el retiro llama a solicitar_retiro() con el monto",
            retiro.pedido.length === 1 && retiro.pedido[0].args.p_monto === 130,
            JSON.stringify(retiro.pedido));
  comprobar("y el saldo queda en lo que respondió la base",
            retiro.saldo === 0, "SALDO = " + retiro.saldo);

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
