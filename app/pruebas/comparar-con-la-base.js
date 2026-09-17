/* Compara el cálculo de la ganancia del socio entre los dos sitios donde vive:
   app/socio-precios.js (lo que ve el socio en pantalla) y ganancia_unitaria()
   en la base (lo que de verdad se le paga).

   Tienen que vivir en dos sitios: si el cálculo viviera solo en el navegador,
   bastaría abrir las herramientas de desarrollo para cobrarse lo que uno
   quiera. Pero dos sitios se desincronizan, y el día que pase alguien cobra de
   menos sin que nadie se entere. Esto lo hace saltar.

   Lee por la entrada estándar el volcado de comparar-sql-y-js.sql:
     publico|mayorista|nivel|ganancia_sql                                     */

var P = require("../socio-precios.js");

var texto = require("fs").readFileSync(0, "utf8").trim();
if (!texto) { console.log("  sin datos de la base — ¿corrió el volcado?"); process.exit(1); }

var filas = texto.split("\n").filter(function (l) { return l.indexOf("|") > -1; });
var pasadas = 0, fallidas = [];

filas.forEach(function (linea) {
  var c = linea.split("|");
  var pub = Number(c[0]), may = Number(c[1]), nivel = c[2].trim(), sql = Number(c[3]);
  var js = P.calcular(may, pub, nivel).ganaSocio;

  if (Math.abs(js - sql) < 0.005) { pasadas++; return; }
  fallidas.push("mayorista " + may.toFixed(2) + " → público " + pub.toFixed(2) +
                " (" + nivel + "):  la base paga " + sql.toFixed(2) +
                ", la pantalla dice " + js.toFixed(2));
});

console.log("\n  " + pasadas + " casos comparados entre la base y la pantalla");
if (fallidas.length) {
  console.log("  " + fallidas.length + " NO COINCIDEN:\n");
  fallidas.forEach(function (f) { console.log("    ✗ " + f); });
  console.log("\n  Uno de los dos cálculos cambió sin el otro. Hasta arreglarlo,");
  console.log("  al socio se le está prometiendo en pantalla algo distinto de lo");
  console.log("  que la base le va a pagar.\n");
  process.exit(1);
}
console.log("  la base y la pantalla dicen lo mismo\n");
