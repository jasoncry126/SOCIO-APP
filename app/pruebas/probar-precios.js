/* Pruebas del cálculo de precios — node app/pruebas/probar-precios.js
   Lo que se protege aquí es dinero: si algo de esto se rompe, alguien cobra
   de menos o SOCIO trabaja gratis. */

var P = require("../socio-precios.js");

var pasadas = 0, fallidas = [];
function comprobar(nombre, cond, detalle) {
  if (cond) { pasadas++; return; }
  fallidas.push(nombre + (detalle ? "\n      " + detalle : ""));
}

/* ------------------------------------------------------------------ */
/* La regla de oro: la marca cobra su mayorista íntegro, siempre       */
/* ------------------------------------------------------------------ */
[[120, 175], [131.25, 175], [80, 115], [10, 100]].forEach(function (par) {
  P.tabla(par[0], par[1]).forEach(function (r) {
    comprobar("la marca cobra íntegro (" + par[0] + "→" + par[1] + ", " + r.nivel.id + ")",
      r.recibeMarca === par[0], "recibió " + r.recibeMarca);
  });
});

/* ------------------------------------------------------------------ */
/* SOCIO nunca trabaja gratis ni pone dinero                           */
/* ------------------------------------------------------------------ */
[[120, 175], [131.25, 175], [140, 175], [170, 175], [174, 175]].forEach(function (par) {
  P.tabla(par[0], par[1]).forEach(function (r) {
    comprobar("SOCIO nunca queda en negativo (" + par[0] + "→" + par[1] + ", " + r.nivel.id + ")",
      r.quedaSocioApp >= 0, "quedó " + r.quedaSocioApp);
  });
});

/* El caso exacto que Jason detectó: 20% de 175 = 35 = todo el margen */
var elCaso = P.calcular(140, 175, "diamante");
comprobar("el caso que Jason detectó ya no deja a SOCIO en cero",
  elCaso.quedaSocioApp > 0, "quedó " + elCaso.quedaSocioApp);
comprobar("y ese producto no es publicable", elCaso.publicable === false);

/* ------------------------------------------------------------------ */
/* Las cuentas cuadran: nada se pierde ni se inventa                   */
/* ------------------------------------------------------------------ */
[[120, 175], [131.25, 175], [80, 115], [140, 186.67]].forEach(function (par) {
  P.tabla(par[0], par[1]).forEach(function (r) {
    comprobar("marca + SOCIO + socio = precio de página (" + par[0] + "→" + par[1] + ", " + r.nivel.id + ")",
      Math.abs((r.recibeMarca + r.quedaSocioApp + r.ganaSocio) - r.precioPublico) < 0.02,
      r.recibeMarca + " + " + r.quedaSocioApp + " + " + r.ganaSocio + " ≠ " + r.precioPublico);
    comprobar("lo que paga el socio + lo que gana = precio de página (" + r.nivel.id + ")",
      Math.abs((r.pagaSocio + r.ganaSocio) - r.precioPublico) < 0.02);
  });
});

/* ------------------------------------------------------------------ */
/* La promesa al socio se cumple cuando el margen alcanza              */
/* ------------------------------------------------------------------ */
P.tabla(120, 175).forEach(function (r) {
  comprobar("con margen suficiente se paga el % prometido (" + r.nivel.id + ")",
    Math.abs(r.ganaSocio - r.precioPublico * r.nivel.comision) < 0.02,
    "prometido " + (r.precioPublico * r.nivel.comision).toFixed(2) + ", pagado " + r.ganaSocio);
  comprobar("y no hubo que recortarla (" + r.nivel.id + ")", r.comisionRecortada === false);
});

comprobar("el socio sube de nivel y gana más",
  P.calcular(120, 175, "diamante").ganaSocio > P.calcular(120, 175, "bronce").ganaSocio);
comprobar("y esa diferencia sale de SOCIO, no de la marca",
  P.calcular(120, 175, "diamante").quedaSocioApp < P.calcular(120, 175, "bronce").quedaSocioApp &&
  P.calcular(120, 175, "diamante").recibeMarca === P.calcular(120, 175, "bronce").recibeMarca);

/* ------------------------------------------------------------------ */
/* El margen mínimo                                                    */
/* ------------------------------------------------------------------ */
comprobar("el mínimo cubre al mejor socio más lo de SOCIO",
  Math.abs(P.MARGEN_MINIMO - (0.20 + P.COMISION_MINIMA_SOCIO)) < 1e-9,
  "es " + P.MARGEN_MINIMO);

var justo = P.evaluarMargen(131.25, 175);       // exactamente 25%
comprobar("justo en el mínimo se publica", justo.ok === true, JSON.stringify(justo.mensaje));

var bajo = P.evaluarMargen(140, 175);           // 20%
comprobar("por debajo del mínimo se rechaza", bajo.ok === false);
comprobar("y dice el código correcto", bajo.codigo === "margen_bajo", bajo.codigo);
comprobar("explica que ningún socio lo elegiría", /ningún socio/.test(bajo.mensaje));
comprobar("propone bajar el mayorista", Math.abs(bajo.mayoristaSugerido - 131.25) < 0.01,
  "sugirió " + bajo.mayoristaSugerido);
comprobar("propone subir el precio de página", Math.abs(bajo.publicoSugerido - 186.67) < 0.01,
  "sugirió " + bajo.publicoSugerido);
comprobar("las dos salidas dan exactamente el mínimo",
  P.evaluarMargen(bajo.mayoristaSugerido, 175).ok === true &&
  P.evaluarMargen(140, bajo.publicoSugerido).ok === true);

var invertido = P.evaluarMargen(200, 175);
comprobar("mayorista por encima del público se rechaza", invertido.ok === false);
comprobar("con su propio código", invertido.codigo === "sin_margen", invertido.codigo);

comprobar("sin precios, se avisa", P.evaluarMargen(0, 175).codigo === "sin_precio");
comprobar("con texto, se avisa", P.evaluarMargen("hola", 175).codigo === "sin_precio");

/* ------------------------------------------------------------------ */
/* Red de seguridad para lo ya publicado con margen bajo               */
/* ------------------------------------------------------------------ */
var apretado = P.calcular(140, 175, "diamante");
comprobar("con margen bajo la comisión se recorta", apretado.comisionRecortada === true);
comprobar("pero la marca sigue cobrando íntegro", apretado.recibeMarca === 140);
comprobar("y a SOCIO le queda su mínimo",
  apretado.quedaSocioApp >= Math.round(175 * P.COMISION_MINIMA_SOCIO * 100) / 100 - 0.01,
  "quedó " + apretado.quedaSocioApp);
comprobar("el socio nunca gana negativo", apretado.ganaSocio >= 0);

/* ------------------------------------------------------------------ */
/* Niveles por ventas entregadas (CLAUDE.md regla nº 5)                */
/* ------------------------------------------------------------------ */
comprobar("socio nuevo es bronce", P.nivelPorVentas(0).id === "bronce");
comprobar("9 ventas sigue bronce", P.nivelPorVentas(9).id === "bronce");
comprobar("10 ventas es plata", P.nivelPorVentas(10).id === "plata");
comprobar("24 sigue plata", P.nivelPorVentas(24).id === "plata");
comprobar("25 es oro", P.nivelPorVentas(25).id === "oro");
comprobar("49 sigue oro", P.nivelPorVentas(49).id === "oro");
comprobar("50 es diamante", P.nivelPorVentas(50).id === "diamante");
comprobar("500 sigue diamante", P.nivelPorVentas(500).id === "diamante");

/* ------------------------------------------------------------------ */
console.log("\n  " + pasadas + " pruebas pasadas");
if (fallidas.length) {
  console.log("  " + fallidas.length + " FALLIDAS:\n");
  fallidas.forEach(function (f) { console.log("    ✗ " + f); });
  process.exit(1);
}
console.log("  todo en orden\n");
