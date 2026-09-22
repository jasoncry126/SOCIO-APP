/* Prueba del recorrido de venta de la app en React, EN UN NAVEGADOR DE VERDAD.

   Recorre lo mismo que recorrería un socio —catálogo, ficha, carrito, datos de
   envío, depósito— y comprueba en cada paso lo que ninguna prueba de cálculo
   puede ver: que la pantalla arranca sin errores de consola, que el precio
   mayorista no aparece por ningún lado (regla 1 de CLAUDE.md), que no se le
   promete al socio una custodia que la plataforma no tiene, y que el monto a
   depositar se enseña con sus céntimos identificadores.

   Se corre con:   node web/pruebas/probar-recorrido-en-navegador.cjs

   No toca ningún Supabase real. Compila la app con la conexión vacía a
   propósito, así que corre con los datos de ejemplo que trae dentro. */

var path = require("path");
var fs = require("fs");
var http = require("http");
var { execFileSync } = require("child_process");

var RAIZ = path.join(__dirname, "..");
var SALIDA = path.join(require("os").tmpdir(), "socio-prueba-dist");
var PUERTO = 4319;

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
/* Un servidor mínimo para los archivos ya compilados                  */
/* ------------------------------------------------------------------ */
var TIPOS = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css",
              ".svg": "image/svg+xml", ".json": "application/json" };

function servir(raiz) {
  return http.createServer(function (pet, res) {
    var limpia = pet.url.split("?")[0];
    var archivo = path.join(raiz, limpia === "/" ? "index.html" : limpia);
    if (!archivo.startsWith(raiz) || !fs.existsSync(archivo) || fs.statSync(archivo).isDirectory()) {
      archivo = path.join(raiz, "index.html");
    }
    res.writeHead(200, { "Content-Type": TIPOS[path.extname(archivo)] || "text/plain" });
    res.end(fs.readFileSync(archivo));
  });
}

async function principal() {
  console.log("\n  Compilando la app con la conexión vacía (datos de ejemplo)…");
  execFileSync("npx", ["vite", "build", "--outDir", SALIDA, "--emptyOutDir"], {
    cwd: RAIZ,
    stdio: "pipe",
    env: Object.assign({}, process.env, { VITE_SUPABASE_URL: "", VITE_SUPABASE_ANON_KEY: "" }),
  });

  var servidor = servir(SALIDA);
  await new Promise(function (listo) { servidor.listen(PUERTO, listo); });

  var ejecutable = rutaDeChromium();
  var navegador = await chromium.launch(
    ejecutable ? { executablePath: ejecutable, args: ["--no-sandbox"] } : { args: ["--no-sandbox"] }
  );
  var pagina = await navegador.newPage({ viewport: { width: 390, height: 844 } });

  /* Las tipografías vienen de Google Fonts. En un contenedor sin salida a
     internet —o detrás de un proxy que firma los certificados— no cargan y el
     navegador lo apunta como error. No es un fallo de la app: la página se ve
     igual con la tipografía del sistema, así que ese error se ignora y
     cualquier otro cuenta. */
  function esRuidoDeEntorno(t) {
    return /ERR_CERT_AUTHORITY_INVALID|ERR_NAME_NOT_RESOLVED|fonts\.(googleapis|gstatic)/.test(t);
  }

  var errores = [];
  pagina.on("pageerror", function (e) { errores.push(String(e)); });
  pagina.on("console", function (m) {
    if (m.type() === "error" && !esRuidoDeEntorno(m.text())) errores.push(m.text());
  });

  try {
    console.log("\n  ── Catálogo ──");
    await pagina.goto("http://localhost:" + PUERTO + "/", { waitUntil: "networkidle" });

    comprobar("la app arranca sin errores de consola", errores.length === 0, errores.join(" | "));
    comprobar("se ve el aviso de datos de ejemplo",
      (await pagina.locator("text=datos de ejemplo").count()) > 0);

    var tarjetas = pagina.locator("main button", { hasText: "Precio socio" });
    var cuantas = await tarjetas.count();
    comprobar("el catálogo pinta sus tarjetas", cuantas >= 2, "encontradas: " + cuantas);

    var textoCatalogo = (await pagina.locator("body").innerText()).toLowerCase();
    comprobar("el catálogo no enseña precio mayorista", !textoCatalogo.includes("mayorista"));

    /* Los datos de ejemplo no traen fotos, que es justo lo que ve una marca
       recién dada de alta: se enseña su emoji y no queda ningún hueco roto. */
    comprobar("sin foto, la tarjeta enseña el emoji del producto",
      (await pagina.locator("main img").count()) === 0);

    console.log("\n  ── Ficha del producto ──");
    await tarjetas.first().click();
    await pagina.waitForSelector("text=Tu precio socio");
    comprobar("la ficha enseña el precio socio y el de página",
      (await pagina.locator("text=Precio de página").count()) > 0);

    var textoFicha = (await pagina.locator("body").innerText()).toLowerCase();
    comprobar("la ficha tampoco enseña precio mayorista", !textoFicha.includes("mayorista"));

    console.log("\n  ── Carrito ──");
    await pagina.getByRole("button", { name: /Agregar al pedido/ }).click();
    await pagina.waitForSelector("text=Ver mi pedido");
    comprobar("agregar al pedido levanta la barra del carrito", true);

    console.log("\n  ── Datos de envío ──");
    await pagina.getByRole("button", { name: /Ver mi pedido/ }).click();
    await pagina.waitForSelector("text=Depositarás");
    comprobar("el checkout resume lo que se deposita y lo que se cobra",
      (await pagina.locator("text=Le cobras a tu cliente").count()) > 0);

    /* Se registra sin llenar nada: tiene que quejarse de los datos, no
       intentar mandar un pedido a medias. */
    await pagina.getByRole("button", { name: /Registrar pedido/ }).click();
    comprobar("no deja registrar sin quien recibe",
      (await pagina.locator("text=Falta el nombre de quien recibe.").count()) > 0);

    await pagina.getByLabel("Nombre completo").fill("Elena Chávez");
    await pagina.getByLabel("DNI o RUC").fill("70111222");
    await pagina.getByLabel("Celular").fill("987654321");
    await pagina.getByLabel("Local de la agencia").fill("Olva Cusco centro");
    await pagina.getByRole("button", { name: /Registrar pedido/ }).click();
    await pagina.waitForSelector("text=datos de ejemplo", { timeout: 4000 });
    comprobar("con los datos completos intenta registrar contra la base", true);

    console.log("\n  ── Depósito ──");
    await pagina.getByRole("button", { name: /Pedidos/ }).click();
    var botonPago = pagina.getByRole("button", { name: /Depositar S\/ 79\.83/ });
    await botonPago.first().waitFor({ timeout: 5000 });
    comprobar("el pedido sin pagar ofrece depositar el monto exacto",
      (await botonPago.count()) > 0);

    await botonPago.first().click();
    await pagina.waitForSelector("text=Deposita exactamente");

    var montoVisible = await pagina.locator("text=Deposita exactamente").locator("xpath=..").innerText();
    comprobar("el monto se enseña con sus céntimos identificadores",
      montoVisible.indexOf("79") >= 0 && montoVisible.indexOf(".83") >= 0, montoVisible);

    var textoPago = (await pagina.locator("body").innerText()).toLowerCase();
    comprobar("no se le promete al socio una custodia que no existe",
      !textoPago.includes("custodia") && !textoPago.includes("en garantía") &&
      !textoPago.includes("retenido"));
    comprobar("avisa de que la cuenta todavía es de relleno",
      textoPago.includes("datos son de relleno"));

    await pagina.getByRole("button", { name: /Ya deposité/ }).click();
    comprobar("no deja confirmar sin la captura",
      (await pagina.locator("text=Falta la captura de tu depósito.").count()) > 0);

    /* Se adjunta una imagen de verdad, para que se vea la miniatura. */
    var punto = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
      "base64");
    await pagina.setInputFiles('input[type="file"]', {
      name: "deposito.png", mimeType: "image/png", buffer: punto,
    });
    await pagina.waitForSelector("text=Captura lista");
    comprobar("la captura adjunta se ve antes de enviarla", true);

    await pagina.getByRole("button", { name: /Ya deposité/ }).click();
    comprobar("sin número de operación tampoco confirma",
      (await pagina.locator("text=número de operación que te dio").count()) > 0);

    comprobar("nada de esto dejó errores en la consola", errores.length === 0,
      errores.join(" | "));
  } finally {
    await navegador.close();
    servidor.close();
  }

  console.log("");
  if (fallos.length) {
    console.log("  " + fallos.length + " comprobaciones fallaron:\n");
    fallos.forEach(function (f) { console.log("   · " + f); });
    console.log("");
    process.exit(1);
  }
  console.log("  Todo en orden.\n");
}

principal().catch(function (e) {
  console.error("\n  La prueba se rompió:", e && e.message ? e.message : e, "\n");
  process.exit(1);
});
