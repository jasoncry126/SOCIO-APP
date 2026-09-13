/* ===========================================================================
   SOCIO · El cálculo del precio, en un solo sitio
   ---------------------------------------------------------------------------
   Antes cada panel calculaba por su cuenta y no coincidían: la app del
   vendedor descontaba un % plano del precio de página (docs/06) y el panel de
   la marca repartía el margen (docs/07). Con un margen estrecho, la app del
   vendedor le daba al socio TODO el margen y SOCIO se quedaba en cero.
   Ahora los dos llaman aquí.

   Las dos caras del mismo número
   ------------------------------
   Al socio se le habla de "ganas el X% de la venta", porque es lo que se
   entiende y lo que atrae. Por dentro ese X% se paga SIEMPRE del margen —
   la diferencia entre lo que cobra la marca y el precio de página — nunca del
   bolsillo de nadie. Las dos cosas son ciertas a la vez, y coinciden porque
   SOCIO no deja publicar un producto cuyo margen no alcance para pagar la
   comisión prometida (ver MARGEN_MINIMO).

   Por eso el socio nunca ve el precio mayorista ni la comisión de SOCIO:
   no los necesita para saber cuánto gana, y conocerlos solo le daría motivos
   para saltarse la plataforma.
   =========================================================================== */

(function (raiz) {
  "use strict";

  /* Lo que se le promete al socio: porcentaje DE LA VENTA según su nivel.
     Son los mismos números que ya veía en su app. */
  var NIVELES = [
    { id: "bronce",   nombre: "Bronce",   med: "🥉", comision: 0.10, meta: 0,  req: "Al crear tu cuenta" },
    { id: "plata",    nombre: "Plata",    med: "🥈", comision: 0.13, meta: 10, req: "10 ventas entregadas" },
    { id: "oro",      nombre: "Oro",      med: "🥇", comision: 0.16, meta: 25, req: "25 ventas entregadas" },
    { id: "diamante", nombre: "Diamante", med: "💎", comision: 0.20, meta: 50, req: "50 ventas + 3 meses activo" }
  ];

  /* IGV peruano. La comisión de SOCIO se factura CON IGV, así que del importe
     que cobra la plataforma hay una parte que nunca fue suya: es del Estado. */
  var IGV = 0.18;

  /* Lo que a SOCIO le tiene que quedar LIMPIO, ya sin IGV, en porcentaje de la
     venta. Es lo que sostiene la plataforma: validar el pago, coordinar el
     despacho, responder ante un reclamo. */
  var COMISION_NETA_MINIMA = 0.05;

  /* Lo que hay que cobrar para que quede ese 5% limpio. Cobrar 5% pelado sería
     quedarse con 4.24% y regalarle el resto al IGV: por eso se cobra 5.9%. */
  var COMISION_MINIMA_SOCIO = Math.round(COMISION_NETA_MINIMA * (1 + IGV) * 10000) / 10000;  // 0.059

  /* El margen mínimo que una marca debe dejar para poder publicar. No es un
     número al azar: es el 20% que se le prometió al mejor socio, más lo que
     SOCIO necesita cobrar para que le quede su 5% después del IGV. */
  var MARGEN_MINIMO = Math.round(
    (NIVELES[NIVELES.length - 1].comision + COMISION_MINIMA_SOCIO) * 10000) / 10000;      // 0.259

  function redondear(n) { return Math.round(n * 100) / 100; }

  function nivelPorId(id) {
    for (var i = 0; i < NIVELES.length; i++) if (NIVELES[i].id === id) return NIVELES[i];
    return NIVELES[0];
  }

  /* ------------------------------------------------------------------------
     ¿Se puede publicar este precio?
     Devuelve el veredicto y, cuando no alcanza, las dos salidas concretas:
     hasta cuánto bajar el mayorista, o desde cuánto subir el precio de página.
     ------------------------------------------------------------------------ */
  function evaluarMargen(mayorista, publico) {
    var may = Number(mayorista), pub = Number(publico);

    if (!isFinite(may) || !isFinite(pub) || may <= 0 || pub <= 0) {
      return { ok: false, codigo: "sin_precio",
               mensaje: "Falta el precio mayorista o el precio de página." };
    }

    var margen = redondear(pub - may);
    var pct = margen / pub;

    // Los precios sugeridos se redondean HACIA el lado que cumple: el mayorista
    // hacia abajo y el precio de página hacia arriba. Redondeando al más
    // cercano, el propio número que sugiere el mensaje se quedaba a centésimas
    // del mínimo y volvía a ser rechazado — el proveedor hacía justo lo que se
    // le pedía y el sistema le decía otra vez que no.
    var salida = {
      margen: margen,
      porcentaje: Math.round(pct * 1000) / 10,
      minimo: Math.round(MARGEN_MINIMO * 1000) / 10,
      mayoristaSugerido: Math.floor(pub * (1 - MARGEN_MINIMO) * 100) / 100,
      publicoSugerido: Math.ceil(may / (1 - MARGEN_MINIMO) * 100) / 100
    };

    if (margen <= 0) {
      salida.ok = false;
      salida.codigo = "sin_margen";
      salida.mensaje = "El precio de página (S/ " + pub.toFixed(2) + ") tiene que ser mayor " +
        "que tu precio mayorista (S/ " + may.toFixed(2) + "). Tal como está no queda nada " +
        "para pagarle al socio que lo venda.";
      return salida;
    }

    // Un céntimo de tolerancia: sin esto, un margen que es exactamente el
    // mínimo puede caer del lado equivocado por el redondeo a céntimos.
    if (pct < MARGEN_MINIMO - 0.0001) {
      salida.ok = false;
      salida.codigo = "margen_bajo";
      salida.mensaje = "Margen insuficiente: S/ " + margen.toFixed(2) + " (" + salida.porcentaje +
        "% del precio de página). SOCIO necesita al menos " + salida.minimo + "% para poder " +
        "pagarle su comisión al socio que lo venda. Con un margen así, ningún socio va a " +
        "elegir tu producto: ganaría muy poco por el mismo trabajo. Baja tu mayorista a " +
        "S/ " + salida.mayoristaSugerido.toFixed(2) + " o sube el precio de página a " +
        "S/ " + salida.publicoSugerido.toFixed(2) + ".";
      return salida;
    }

    salida.ok = true;
    salida.codigo = "ok";
    salida.mensaje = "Margen S/ " + margen.toFixed(2) + " (" + salida.porcentaje + "%).";
    return salida;
  }

  /* ------------------------------------------------------------------------
     El cálculo de una venta, para un nivel de socio.
     Una sola verdad, la misma para los tres paneles.
     ------------------------------------------------------------------------ */
  function calcular(mayorista, publico, nivelId) {
    var may = redondear(Number(mayorista));
    var pub = redondear(Number(publico));
    var nivel = nivelPorId(nivelId);
    var evaluacion = evaluarMargen(may, pub);

    // Lo prometido al socio: su % de la venta.
    var ganaSocio = redondear(pub * nivel.comision);
    var margen = redondear(pub - may);

    // Red de seguridad: si el producto se publicó antes de esta regla y su
    // margen no alcanza, la comisión se recorta al margen disponible menos lo
    // mínimo de SOCIO. La marca cobra su mayorista íntegro SIEMPRE — eso no se
    // toca nunca, es lo que se le prometió a ella.
    var recortada = false;
    var techo = redondear(margen - pub * COMISION_MINIMA_SOCIO);
    if (ganaSocio > techo) {
      ganaSocio = Math.max(0, techo);
      recortada = true;
    }

    var pagaSocio = redondear(pub - ganaSocio);
    var quedaSocioApp = redondear(margen - ganaSocio);

    return {
      nivel: nivel,
      precioPublico: pub,
      precioMayorista: may,
      margen: margen,

      pagaSocio: pagaSocio,          // lo que el socio le transfiere a SOCIO
      ganaSocio: ganaSocio,          // su comisión
      comisionMostrada: nivel.comision,               // el % que se le promete
      comisionReal: pub > 0 ? Math.round(ganaSocio / pub * 1000) / 10 : 0,

      recibeMarca: may,              // íntegro, en todos los niveles
      quedaSocioApp: quedaSocioApp,  // la comisión de la plataforma, con IGV dentro
      igvComision: redondear(quedaSocioApp * IGV / (1 + IGV)),          // no es de SOCIO
      comisionNeta: redondear(quedaSocioApp / (1 + IGV)),               // lo que sí queda

      publicable: evaluacion.ok,
      comisionRecortada: recortada,
      evaluacion: evaluacion
    };
  }

  /* Todos los niveles de golpe, para las tablas comparativas. */
  function tabla(mayorista, publico) {
    return NIVELES.map(function (n) { return calcular(mayorista, publico, n.id); });
  }

  /* El nivel que le toca a un socio según sus ventas entregadas. */
  function nivelPorVentas(ventas) {
    var v = Number(ventas) || 0, elegido = NIVELES[0];
    for (var i = 0; i < NIVELES.length; i++) if (v >= NIVELES[i].meta) elegido = NIVELES[i];
    return elegido;
  }

  var api = {
    NIVELES: NIVELES,
    MARGEN_MINIMO: MARGEN_MINIMO,
    COMISION_MINIMA_SOCIO: COMISION_MINIMA_SOCIO,
    COMISION_NETA_MINIMA: COMISION_NETA_MINIMA,
    IGV: IGV,
    evaluarMargen: evaluarMargen,
    calcular: calcular,
    tabla: tabla,
    nivelPorId: nivelPorId,
    nivelPorVentas: nivelPorVentas
  };

  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else raiz.SocioPrecios = api;

})(typeof self !== "undefined" ? self : this);
