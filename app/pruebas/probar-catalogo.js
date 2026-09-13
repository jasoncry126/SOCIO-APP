/* Pruebas de socio-catalogo.js — se corren con:  node app/pruebas/probar-catalogo.js
   No hacen falta librerías: si algo falla, el proceso termina con código 1. */

var C = require("../socio-catalogo.js");

// socio-datos.js se cuelga de window; en node le damos uno de mentira.
global.window = global.window || {};
require("../socio-datos.js");
var D = global.window.SocioDatos;

var pasadas = 0, fallidas = [];

function comprobar(nombre, condicion, detalle) {
  if (condicion) { pasadas++; return; }
  fallidas.push(nombre + (detalle ? "\n      " + detalle : ""));
}

function cabecera(extra) {
  return "producto,presentacion,categoria,contexto,imagen,precio_publico,precio_mayorista" +
         (extra || "") + "\n";
}

/* ------------------------------------------------------------------ */
/* Horas de corte: el desplegable dice "2:00 p. m." y la base quiere      */
/* una hora de 24 h. Sin convertir, Postgres toma el "p." por una zona    */
/* horaria y rechaza el producto entero.                                  */
/* ------------------------------------------------------------------ */
comprobar("mediodía", D.aHora("12:00 p. m.") === "12:00:00");
comprobar("2 de la tarde", D.aHora("2:00 p. m.") === "14:00:00");
comprobar("4 de la tarde", D.aHora("4:00 p. m.") === "16:00:00");
comprobar("5 de la tarde", D.aHora("5:00 p. m.") === "17:00:00");
comprobar("6 de la tarde", D.aHora("6:00 p. m.") === "18:00:00");
comprobar("11 de la mañana", D.aHora("11:00 a. m.") === "11:00:00");
comprobar("1 de la tarde", D.aHora("1:00 p. m.") === "13:00:00");
comprobar("3 de la tarde", D.aHora("3:00 p. m.") === "15:00:00");
comprobar("medianoche no es mediodía", D.aHora("12:00 a. m.") === "00:00:00");
comprobar("con minutos", D.aHora("9:30 a. m.") === "09:30:00");
comprobar("ya en 24 h pasa igual", D.aHora("14:00") === "14:00:00");
comprobar('"Sin corte" es vacío', D.aHora("Sin corte") === null);
comprobar('"No aplica" es vacío', D.aHora("No aplica") === null);
comprobar("vacío es vacío", D.aHora("") === null);
comprobar("nulo es vacío", D.aHora(null) === null);
comprobar("texto cualquiera es vacío", D.aHora("cuando pueda") === null);
comprobar("hora imposible es vacío", D.aHora("99:99") === null);

/* ------------------------------------------------------------------ */
/* Números                                                             */
/* ------------------------------------------------------------------ */
comprobar("número simple", C.aNumero("175") === 175);
comprobar("decimal con punto", C.aNumero("175.50") === 175.5);
comprobar("decimal con coma (como lo escribe Jason)", C.aNumero("175,50") === 175.5);
comprobar("miles con punto y decimal con coma", C.aNumero("1.234,50") === 1234.5);
comprobar("miles con coma y decimal con punto", C.aNumero("1,234.50") === 1234.5);
comprobar("con espacios", C.aNumero("  180  ") === 180);
comprobar("con S/", C.aNumero("S/ 245") === 245);
comprobar("texto no es número", C.aNumero("a cotizar") === null);
comprobar("vacío no es número", C.aNumero("") === null);
comprobar("nulo no es número", C.aNumero(null) === null);

/* ------------------------------------------------------------------ */
/* Lector de CSV                                                       */
/* ------------------------------------------------------------------ */
var conComas = C.leerCSV('a,b\n"uno, con coma","dos"\n');
comprobar("respeta comas dentro de comillas",
  conComas[1][0] === "uno, con coma" && conComas[1][1] === "dos",
  JSON.stringify(conComas[1]));

var conSalto = C.leerCSV('a,b\n"linea uno\nlinea dos",x\n');
comprobar("respeta saltos de línea dentro de comillas",
  conSalto[1][0] === "linea uno\nlinea dos" && conSalto.length === 2,
  JSON.stringify(conSalto));

var conComilla = C.leerCSV('a\n"dice ""hola"" ahi"\n');
comprobar("comillas escapadas", conComilla[1][0] === 'dice "hola" ahi', JSON.stringify(conComilla[1]));

comprobar("quita el BOM de Excel", C.leerCSV("﻿a,b\n")[0][0] === "a");

/* ------------------------------------------------------------------ */
/* Separadores: Excel en español usa ; y el portapapeles usa tabulador */
/* ------------------------------------------------------------------ */
comprobar("detecta la coma", C.detectarSeparador("a,b,c\n1,2,3") === ",");
comprobar("detecta el punto y coma (Excel en español)", C.detectarSeparador("a;b;c\n1;2;3") === ";");
comprobar("detecta el tabulador (pegado desde Excel)", C.detectarSeparador("a\tb\tc\n1\t2\t3") === "\t");
comprobar("no confunde comas dentro de comillas",
  C.detectarSeparador('a;"uno, dos, tres";c\n') === ";",
  "detectó " + JSON.stringify(C.detectarSeparador('a;"uno, dos, tres";c\n')));
comprobar("una sola columna cae a coma", C.detectarSeparador("producto\nBPC") === ",");

var pyc = C.analizar(
  "producto;presentacion;categoria;contexto;imagen;precio_publico;precio_mayorista\n" +
  "BPC-157;Vial 5 mg;Recuperación;Pentadecapéptido;bpc.webp;175;122,50\n");
comprobar("archivo con punto y coma se acepta", pyc.ok === true, JSON.stringify(pyc.errores));
comprobar("y lee bien el precio con coma decimal",
  pyc.productos[0].presentaciones[0].precio_mayorista === 122.5);

var tabs = C.analizar(
  "producto\tpresentacion\tcategoria\tcontexto\timagen\tprecio_publico\tprecio_mayorista\n" +
  "BPC-157\tVial 5 mg\tRecuperación\tPentadecapéptido\tbpc.webp\t175\t122.50\n" +
  "TB-500\tVial 10 mg\tRecuperación\tFragmento\ttb.webp\t245\t171.50\n");
comprobar("pegado desde Excel (tabuladores) se acepta", tabs.ok === true, JSON.stringify(tabs.errores));
comprobar("y agrupa bien", tabs.resumen.productos === 2 && tabs.resumen.presentaciones === 2);

var pycTexto = C.analizar(
  'producto;presentacion;categoria;contexto;imagen;precio_publico;precio_mayorista\n' +
  '"KPV";"Vial 10 mg";"Rec";"Tripéptido, con coma dentro";"k.webp";"215";"150"\n');
comprobar("punto y coma + texto con comas dentro",
  pycTexto.ok && pycTexto.productos[0].descripcion === "Tripéptido, con coma dentro",
  JSON.stringify(pycTexto.errores));

/* ------------------------------------------------------------------ */
/* Casos correctos                                                     */
/* ------------------------------------------------------------------ */
var bueno = C.analizar(cabecera() +
  "BPC-157,Vial 5 mg,Recuperación,Pentadecapéptido...,bpc-157-5.webp,175,122.50\n" +
  "BPC-157,Vial 10 mg,Recuperación,Pentadecapéptido...,bpc-157-10.webp,300,210\n" +
  "TB-500,Vial 10 mg,Recuperación,Fragmento sintético,tb-500-10.webp,245,171.50\n");

comprobar("archivo válido pasa", bueno.ok === true, JSON.stringify(bueno.errores));
comprobar("agrupa presentaciones por producto", bueno.resumen.productos === 2, "productos=" + bueno.resumen.productos);
comprobar("cuenta las presentaciones", bueno.resumen.presentaciones === 3);
comprobar("conserva el orden del archivo", bueno.productos[0].nombre === "BPC-157");
comprobar("BPC-157 con sus 2 presentaciones", bueno.productos[0].presentaciones.length === 2);
comprobar("guarda el mayorista", bueno.productos[0].presentaciones[0].precio_mayorista === 122.5);
comprobar("guarda el precio de página", bueno.productos[0].presentaciones[0].precio_publico === 175);
comprobar("stock por defecto en 0", bueno.productos[0].presentaciones[0].stock_almacen === 0);
comprobar("toma la descripción del producto", bueno.productos[1].descripcion === "Fragmento sintético");

var conStock = C.analizar(cabecera(",stock_almacen,stock_punto") +
  "GHK-Cu,Vial 50 mg,Piel,Cobre,ghk.webp,175,120,20,5\n");
comprobar("lee el stock cuando viene", conStock.productos[0].presentaciones[0].stock_almacen === 20 &&
  conStock.productos[0].presentaciones[0].stock_punto === 5);

var conComasEnTexto = C.analizar(cabecera() +
  '"KPV","Vial 10 mg","Recuperación","Tripéptido terminal, estudiado en vías inflamatorias","kpv.webp","215","150"\n');
comprobar("contexto con comas no rompe el archivo",
  conComasEnTexto.ok && conComasEnTexto.productos[0].descripcion === "Tripéptido terminal, estudiado en vías inflamatorias",
  JSON.stringify(conComasEnTexto.errores));

var conVacias = C.analizar(cabecera() +
  "BPC-157,Vial 5 mg,Rec,ctx,i.webp,175,122\n" +
  "\n" + ",,,,,,\n" +
  "KPV,Vial 10 mg,Rec,ctx,i.webp,215,150\n");
comprobar("ignora filas en blanco", conVacias.ok && conVacias.resumen.presentaciones === 2,
  JSON.stringify(conVacias.errores));

/* ------------------------------------------------------------------ */
/* Casos que deben ser rechazados                                      */
/* ------------------------------------------------------------------ */
function primerError(r) { return r.errores.length ? r.errores[0].motivo : "(sin error)"; }

var sinMargen = C.analizar(cabecera() + "X,Vial 5 mg,C,ctx,i.webp,100,150\n");
comprobar("rechaza mayorista por encima del precio de página",
  !sinMargen.ok && /mayor que tu mayorista/.test(primerError(sinMargen)), primerError(sinMargen));

var igual = C.analizar(cabecera() + "X,Vial 5 mg,C,ctx,i.webp,150,150\n");
comprobar("rechaza margen cero", !igual.ok, primerError(igual));

var sinPrecio = C.analizar(cabecera() + "X,Vial 5 mg,C,ctx,i.webp,,120\n");
comprobar("rechaza sin precio de página (docs/10)",
  !sinPrecio.ok && /precio de página no es un número/.test(primerError(sinPrecio)), primerError(sinPrecio));

var aCotizar = C.analizar(cabecera() + "X,Vial 5 mg,C,ctx,i.webp,a cotizar,120\n");
comprobar('rechaza "a cotizar"', !aCotizar.ok, primerError(aCotizar));

var sinMayorista = C.analizar(cabecera() + "X,Vial 5 mg,C,ctx,i.webp,175,\n");
comprobar("rechaza sin mayorista",
  !sinMayorista.ok && /falta tu precio mayorista/.test(primerError(sinMayorista)), primerError(sinMayorista));

var negativo = C.analizar(cabecera() + "X,Vial 5 mg,C,ctx,i.webp,-175,-120\n");
comprobar("rechaza precios negativos", !negativo.ok, primerError(negativo));

var repetida = C.analizar(cabecera() +
  "X,Vial 5 mg,C,ctx,i.webp,175,120\n" +
  "X,Vial 5 mg,C,ctx,i.webp,180,120\n");
comprobar("detecta presentación repetida",
  !repetida.ok && /repetida/.test(primerError(repetida)), primerError(repetida));
comprobar("dice en qué fila estaba la repetida", /fila 2/.test(primerError(repetida)), primerError(repetida));

var sinNombre = C.analizar(cabecera() + ",Vial 5 mg,C,ctx,i.webp,175,120\n");
comprobar("rechaza producto sin nombre", !sinNombre.ok, primerError(sinNombre));

var sinPres = C.analizar(cabecera() + "X,,C,ctx,i.webp,175,120\n");
comprobar("rechaza presentación sin nombre", !sinPres.ok, primerError(sinPres));

var faltaColumna = C.analizar("producto,presentacion,precio_publico\nX,Vial,175\n");
comprobar("avisa qué columna falta",
  !faltaColumna.ok && /precio_mayorista/.test(primerError(faltaColumna)), primerError(faltaColumna));

var vacio = C.analizar("");
comprobar("archivo vacío", !vacio.ok);

var soloCabecera = C.analizar(cabecera());
comprobar("archivo sin filas", !soloCabecera.ok, primerError(soloCabecera));

/* El número de fila tiene que coincidir con el de la hoja de cálculo */
var filaMala = C.analizar(cabecera() +
  "A,Vial 5 mg,C,ctx,i.webp,175,120\n" +
  "B,Vial 5 mg,C,ctx,i.webp,175,120\n" +
  "C,Vial 5 mg,C,ctx,i.webp,100,150\n");
comprobar("señala la fila correcta (3ª de datos = fila 4)",
  filaMala.errores.length === 1 && filaMala.errores[0].fila === 4,
  JSON.stringify(filaMala.errores));

/* Un error no debe tumbar el resto del análisis */
comprobar("sigue analizando tras un error", filaMala.productos.length === 2,
  "productos válidos=" + filaMala.productos.length);

/* ------------------------------------------------------------------ */
/* Avisos (no bloquean)                                                */
/* ------------------------------------------------------------------ */
var discrepa = C.analizar(cabecera() +
  "X,Vial 5 mg,Piel,contexto uno,i.webp,175,120\n" +
  "X,Vial 10 mg,Cognición,contexto dos,i.webp,300,200\n");
comprobar("avisa si la categoría discrepa", discrepa.ok && discrepa.avisos.length >= 1,
  JSON.stringify(discrepa.avisos));
comprobar("se queda con la primera categoría", discrepa.productos[0].categoria === "Piel");

var stockNeg = C.analizar(cabecera(",stock_almacen") + "X,Vial 5 mg,C,ctx,i.webp,175,120,-3\n");
comprobar("stock negativo avisa y se toma como 0",
  stockNeg.ok && stockNeg.productos[0].presentaciones[0].stock_almacen === 0 && stockNeg.avisos.length === 1);

/* ------------------------------------------------------------------ */
/* El CSV real del proveedor                                           */
/* ------------------------------------------------------------------ */
var fs = require("fs"), path = require("path");
var ruta = path.join(__dirname, "..", "..", "supabase", "datos", "catalogo-proveedor.csv");
if (fs.existsSync(ruta)) {
  var real = fs.readFileSync(ruta, "utf8");

  var sinMay = C.analizar(real);
  comprobar("el CSV del proveedor sin mayoristas se rechaza entero",
    !sinMay.ok && sinMay.errores.length === 63,
    "errores=" + sinMay.errores.length);

  // el mismo archivo con los mayoristas completados
  var lineas = real.split("\n");
  var conMay = lineas.map(function (l, i) {
    if (i === 0 || !l.trim()) return l;
    var campos = C.leerCSV(l + "\n")[0];
    var pub = C.aNumero(campos[5]);
    campos[6] = pub ? (pub * 0.7).toFixed(2) : "";
    return campos.map(function (c) {
      return /[",\n]/.test(c) ? '"' + c.replace(/"/g, '""') + '"' : c;
    }).join(",");
  }).join("\n");

  var r = C.analizar(conMay);
  comprobar("el CSV real del proveedor pasa con mayoristas",
    r.ok === true, JSON.stringify(r.errores.slice(0, 3)));
  comprobar("y da 47 productos / 63 presentaciones",
    r.resumen.productos === 47 && r.resumen.presentaciones === 63,
    r.resumen.productos + " productos, " + r.resumen.presentaciones + " presentaciones");
  comprobar("sin avisos de descripciones discrepantes", r.avisos.length === 0,
    JSON.stringify(r.avisos.slice(0, 3)));
} else {
  fallidas.push("no encontré el CSV del proveedor en " + ruta);
}

/* ------------------------------------------------------------------ */
console.log("\n  " + pasadas + " pruebas pasadas");
if (fallidas.length) {
  console.log("  " + fallidas.length + " FALLIDAS:\n");
  fallidas.forEach(function (f) { console.log("    ✗ " + f); });
  process.exit(1);
}
console.log("  todo en orden\n");
