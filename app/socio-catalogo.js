/* ===========================================================================
   SOCIO · Lectura y validación del catálogo de una marca
   ---------------------------------------------------------------------------
   Convierte el archivo que sube la marca (CSV) en productos y presentaciones
   listos para guardar, o en una lista de errores entendibles.

   No sabe nada de Supabase ni del navegador: entra texto, sale un resultado.
   Por eso se puede probar sola (ver pruebas/probar-catalogo.js).

   Las reglas que aplica son las mismas que ya aplicaba el asistente de carga
   uno-por-uno, para que subir 60 productos de golpe no sea una puerta trasera
   que se salte las validaciones:

     · sin precio de página no se publica            (docs/10)
     · el precio de página supera al mayorista       (docs/07 y la base)
     · el socio nunca ve el mayorista                (CLAUDE.md regla nº 1)
   =========================================================================== */

(function (raiz) {
  "use strict";

  var COLUMNAS = ["producto", "presentacion", "categoria", "contexto",
                  "imagen", "precio_publico", "precio_mayorista",
                  "stock_almacen", "stock_punto", "nombre_comprobante"];
  var OBLIGATORIAS = ["producto", "presentacion", "precio_publico", "precio_mayorista"];

  /* ---------------------------------------------------------------------
     Lector de tablas de texto
     Hecho a mano y no con split() porque el contexto de un producto lleva
     comas, comillas y a veces saltos de línea.

     El separador se detecta solo, porque no siempre es la coma:
       ·  ;   Excel en español (y en Perú) guarda así los CSV. Es lo normal,
              no una rareza: sin esto, casi ningún archivo real entraría.
       · tab  lo que va al portapapeles al copiar celdas desde Excel.
       ·  ,   el CSV clásico.
     --------------------------------------------------------------------- */

  /* Cuenta separadores en la primera línea, ignorando lo que va entrecomillado. */
  function detectarSeparador(texto) {
    var linea = "", enComillas = false;
    for (var i = 0; i < texto.length; i++) {
      var c = texto[i];
      if (c === '"') { enComillas = !enComillas; linea += c; continue; }
      if (c === "\n" && !enComillas) break;
      linea += c;
    }
    var cuenta = { "\t": 0, ";": 0, ",": 0 };
    enComillas = false;
    for (var j = 0; j < linea.length; j++) {
      var d = linea[j];
      if (d === '"') { enComillas = !enComillas; continue; }
      if (!enComillas && cuenta[d] !== undefined) cuenta[d]++;
    }
    if (cuenta["\t"] > 0 && cuenta["\t"] >= cuenta[";"] && cuenta["\t"] >= cuenta[","]) return "\t";
    if (cuenta[";"] > cuenta[","]) return ";";
    return ",";
  }

  function leerCSV(texto, separador) {
    if (texto.charCodeAt(0) === 0xFEFF) texto = texto.slice(1); // BOM de Excel
    var sep = separador || detectarSeparador(texto);
    var filas = [], campo = "", fila = [], enComillas = false, i = 0;

    while (i < texto.length) {
      var c = texto[i];
      if (enComillas) {
        if (c === '"') {
          if (texto[i + 1] === '"') { campo += '"'; i += 2; continue; }
          enComillas = false; i++; continue;
        }
        campo += c; i++; continue;
      }
      if (c === '"') { enComillas = true; i++; continue; }
      if (c === sep) { fila.push(campo); campo = ""; i++; continue; }
      if (c === "\r") { i++; continue; }
      if (c === "\n") { fila.push(campo); filas.push(fila); fila = []; campo = ""; i++; continue; }
      campo += c; i++;
    }
    fila.push(campo);
    if (fila.length > 1 || fila[0] !== "") filas.push(fila);
    return filas;
  }

  /* Acepta "1.234,50", "1234.50", "1,234.50" o "  180 ". Devuelve null si no
     es un número usable. */
  function aNumero(v) {
    if (v === null || v === undefined) return null;
    var s = String(v).trim().replace(/\s/g, "").replace(/^S\/\.?/i, "");
    if (!s) return null;
    var tieneComa = s.indexOf(",") !== -1, tienePunto = s.indexOf(".") !== -1;
    if (tieneComa && tienePunto) {
      // el separador decimal es el que aparece más a la derecha
      s = s.lastIndexOf(",") > s.lastIndexOf(".")
        ? s.replace(/\./g, "").replace(",", ".")
        : s.replace(/,/g, "");
    } else if (tieneComa) {
      s = s.replace(",", ".");
    }
    if (!/^-?\d+(\.\d+)?$/.test(s)) return null;
    var n = parseFloat(s);
    return isFinite(n) ? n : null;
  }

  function aEntero(v) {
    var n = aNumero(v);
    if (n === null) return null;
    return Math.trunc(n);
  }

  function normalizar(s) {
    return String(s == null ? "" : s).trim();
  }

  /* ---------------------------------------------------------------------
     Validación
     --------------------------------------------------------------------- */
  function analizar(texto) {
    var errores = [], avisos = [];
    var filas = leerCSV(String(texto == null ? "" : texto));

    if (!filas.length) {
      return { ok: false, productos: [], errores: [{ fila: 0, motivo: "El archivo está vacío." }], avisos: [] };
    }

    var cabecera = filas[0].map(function (c) { return normalizar(c).toLowerCase(); });
    var faltan = OBLIGATORIAS.filter(function (c) { return cabecera.indexOf(c) === -1; });
    if (faltan.length) {
      return {
        ok: false, productos: [], avisos: [],
        errores: [{
          fila: 1,
          motivo: "Al archivo le faltan columnas: " + faltan.join(", ") +
                  ". Se esperaban: " + COLUMNAS.slice(0, 7).join(", ") + "."
        }]
      };
    }

    var idx = {};
    cabecera.forEach(function (c, i) { if (idx[c] === undefined) idx[c] = i; });
    function celda(fila, nombre) {
      var i = idx[nombre];
      return i === undefined ? "" : normalizar(fila[i]);
    }

    var porProducto = {};   // nombre -> producto acumulado
    var orden = [];         // para conservar el orden del archivo
    var vistas = {};        // producto|presentacion -> nº de fila, para duplicados

    for (var f = 1; f < filas.length; f++) {
      var fila = filas[f];
      var nFila = f + 1;    // como lo numera una hoja de cálculo

      // Fila completamente vacía: se ignora sin ruido.
      var algo = fila.some(function (c) { return normalizar(c) !== ""; });
      if (!algo) continue;

      var producto = celda(fila, "producto");
      var presentacion = celda(fila, "presentacion");
      var pub = aNumero(celda(fila, "precio_publico"));
      var may = aNumero(celda(fila, "precio_mayorista"));

      if (!producto) { errores.push({ fila: nFila, motivo: "Falta el nombre del producto." }); continue; }
      if (!presentacion) { errores.push({ fila: nFila, motivo: '"' + producto + '": falta el nombre de la presentación.' }); continue; }

      var clave = producto.toLowerCase() + "|" + presentacion.toLowerCase();
      if (vistas[clave]) {
        errores.push({
          fila: nFila,
          motivo: '"' + producto + " — " + presentacion + '" está repetida (ya venía en la fila ' + vistas[clave] + ")."
        });
        continue;
      }
      vistas[clave] = nFila;

      var etiqueta = '"' + producto + " — " + presentacion + '"';

      if (pub === null) {
        errores.push({ fila: nFila, motivo: etiqueta + ": el precio de página no es un número." });
        continue;
      }
      if (may === null) {
        errores.push({ fila: nFila, motivo: etiqueta + ": falta tu precio mayorista, o no es un número." });
        continue;
      }
      if (pub <= 0 || may <= 0) {
        errores.push({ fila: nFila, motivo: etiqueta + ": los precios tienen que ser mayores que cero." });
        continue;
      }
      // docs/07: el margen es lo que se reparte entre el socio y SOCIO. Sin
      // margen no hay nada que repartir, y la base rechaza la fila.
      if (pub <= may) {
        errores.push({
          fila: nFila,
          motivo: etiqueta + ": el precio de página (S/ " + pub + ") tiene que ser mayor que tu mayorista (S/ " + may + ")."
        });
        continue;
      }

      var stockA = aEntero(celda(fila, "stock_almacen"));
      var stockB = aEntero(celda(fila, "stock_punto"));
      if (stockA !== null && stockA < 0) { avisos.push({ fila: nFila, motivo: etiqueta + ": stock de almacén negativo, se toma como 0." }); stockA = 0; }
      if (stockB !== null && stockB < 0) { avisos.push({ fila: nFila, motivo: etiqueta + ": stock de punto de venta negativo, se toma como 0." }); stockB = 0; }

      var p = porProducto[producto.toLowerCase()];
      if (!p) {
        p = porProducto[producto.toLowerCase()] = {
          nombre: producto,
          categoria: celda(fila, "categoria") || null,
          descripcion: celda(fila, "contexto") || null,
          nombre_comprobante: celda(fila, "nombre_comprobante") || null,
          presentaciones: []
        };
        orden.push(p);
      } else {
        // Dos filas del mismo producto que discrepan en categoría o contexto:
        // se queda la primera y se avisa, en vez de elegir en silencio.
        var cat = celda(fila, "categoria");
        if (cat && p.categoria && cat !== p.categoria) {
          avisos.push({ fila: nFila, motivo: '"' + producto + '": la categoría dice "' + cat + '" pero antes decía "' + p.categoria + '". Se usa la primera.' });
        }
        var ctx = celda(fila, "contexto");
        if (ctx && p.descripcion && ctx !== p.descripcion) {
          avisos.push({ fila: nFila, motivo: '"' + producto + '": la descripción no coincide con la de sus otras presentaciones. Se usa la primera.' });
        }
        if (!p.categoria && cat) p.categoria = cat;
        if (!p.descripcion && ctx) p.descripcion = ctx;
        if (!p.nombre_comprobante) p.nombre_comprobante = celda(fila, "nombre_comprobante") || null;
      }

      p.presentaciones.push({
        nombre: presentacion,
        precio_mayorista: Math.round(may * 100) / 100,
        precio_publico: Math.round(pub * 100) / 100,
        stock_almacen: stockA === null ? 0 : stockA,
        stock_punto: stockB === null ? 0 : stockB,
        imagen: celda(fila, "imagen") || null,
        fila: nFila
      });
    }

    if (!orden.length && !errores.length) {
      errores.push({ fila: 0, motivo: "El archivo no tiene ninguna fila de producto." });
    }

    return {
      ok: errores.length === 0 && orden.length > 0,
      productos: orden,
      errores: errores,
      avisos: avisos,
      resumen: {
        productos: orden.length,
        presentaciones: orden.reduce(function (n, p) { return n + p.presentaciones.length; }, 0)
      }
    };
  }

  var api = {
    COLUMNAS: COLUMNAS,
    leerCSV: leerCSV,
    detectarSeparador: detectarSeparador,
    aNumero: aNumero,
    analizar: analizar
  };

  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else raiz.SocioCatalogo = api;

})(typeof self !== "undefined" ? self : this);
