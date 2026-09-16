const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType,
  Table, TableRow, TableCell, WidthType, ShadingType, BorderStyle, PageBreak,
  LevelFormat, convertInchesToTwip
} = require("docx");
const fs = require("fs");

const TINTA = "16232E", GRIS = "5A6B72", VERDE = "0F6E5C", ROJO = "B4432C";
const FUENTE = "Calibri";

const p = (texto, o = {}) => new Paragraph({
  spacing: { after: o.after ?? 140, line: 276 },
  alignment: o.alignment,
  indent: o.indent,
  children: [new TextRun({
    text: texto, font: FUENTE, size: o.size ?? 22,
    bold: o.bold, italics: o.italics, color: o.color ?? TINTA
  })]
});

/* Párrafo con partes en negrita: pMix(["texto ", ["negrita", true], " más"]) */
const pMix = (partes, o = {}) => new Paragraph({
  spacing: { after: o.after ?? 140, line: 276 },
  indent: o.indent,
  children: partes.map(x => {
    const [t, b] = Array.isArray(x) ? x : [x, false];
    return new TextRun({ text: t, font: FUENTE, size: o.size ?? 22, bold: b, color: o.color ?? TINTA });
  })
});

const h1 = (t) => new Paragraph({
  heading: HeadingLevel.HEADING_1, spacing: { before: 340, after: 160 },
  children: [new TextRun({ text: t, font: FUENTE, size: 30, bold: true, color: TINTA })]
});

const h2 = (t) => new Paragraph({
  heading: HeadingLevel.HEADING_2, spacing: { before: 260, after: 120 },
  children: [new TextRun({ text: t, font: FUENTE, size: 24, bold: true, color: VERDE })]
});

const bullet = (t, nivel = 0) => new Paragraph({
  numbering: { reference: "vinetas", level: nivel },
  spacing: { after: 90, line: 276 },
  children: [new TextRun({ text: t, font: FUENTE, size: 22, color: TINTA })]
});

const pregunta = (n, t) => new Paragraph({
  spacing: { before: 200, after: 90, line: 276 },
  children: [
    new TextRun({ text: n + ".  ", font: FUENTE, size: 22, bold: true, color: VERDE }),
    new TextRun({ text: t, font: FUENTE, size: 22, bold: true, color: TINTA })
  ]
});

const nota = (t) => new Paragraph({
  spacing: { after: 120, line: 276 }, indent: { left: 360 },
  children: [new TextRun({ text: t, font: FUENTE, size: 21, color: GRIS, italics: true })]
});

const linea = () => new Paragraph({
  spacing: { before: 200, after: 200 },
  border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: "D8DEDB" } },
  children: [new TextRun({ text: "", font: FUENTE, size: 2 })]
});

/* ---- tablas ---- */
const celda = (t, o = {}) => new TableCell({
  width: { size: o.w, type: WidthType.DXA },
  shading: o.fondo ? { type: ShadingType.CLEAR, fill: o.fondo, color: "auto" } : undefined,
  margins: { top: 80, bottom: 80, left: 110, right: 110 },
  children: [new Paragraph({
    alignment: o.der ? AlignmentType.RIGHT : AlignmentType.LEFT,
    spacing: { after: 0 },
    children: [new TextRun({
      text: t, font: FUENTE, size: o.size ?? 20,
      bold: o.bold, color: o.color ?? TINTA
    })]
  })]
});

function tabla(anchos, cabecera, filas, alineDerechaDesde = 1) {
  const total = anchos.reduce((a, b) => a + b, 0);
  return new Table({
    width: { size: total, type: WidthType.DXA },
    columnWidths: anchos,
    rows: [
      new TableRow({
        tableHeader: true,
        children: cabecera.map((t, i) =>
          celda(t, { w: anchos[i], fondo: "EAF1EE", bold: true, size: 19, der: i >= alineDerechaDesde }))
      }),
      ...filas.map(f => new TableRow({
        children: f.map((c, i) => {
          const texto = Array.isArray(c) ? c[0] : c;
          const opts = Array.isArray(c) ? c[1] : {};
          return celda(texto, Object.assign({ w: anchos[i], der: i >= alineDerechaDesde }, opts));
        })
      }))
    ]
  });
}

const A = 9360;  // ancho útil con márgenes de 1"

const doc = new Document({
  numbering: {
    config: [{
      reference: "vinetas",
      levels: [
        { level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 360, hanging: 200 } } } },
        { level: 1, format: LevelFormat.BULLET, text: "–", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 200 } } } }
      ]
    }]
  },
  sections: [{
    properties: { page: { margin: { top: 1440, bottom: 1440, left: 1440, right: 1440 } } },
    children: [

      /* ================= PORTADA ================= */
      new Paragraph({
        spacing: { after: 60 },
        children: [new TextRun({ text: "CONSULTA TRIBUTARIA", font: FUENTE, size: 20, bold: true, color: VERDE, characterSpacing: 40 })]
      }),
      new Paragraph({
        spacing: { after: 120 },
        children: [new TextRun({ text: "SOCIO", font: FUENTE, size: 52, bold: true, color: TINTA })]
      }),
      p("Plataforma de venta por red de vendedores independientes", { size: 24, color: GRIS, after: 60 }),
      p("Documento preparado para la sesión con el contador · Lima, Perú", { size: 20, color: GRIS, after: 40 }),
      p("Versión de trabajo — septiembre 2026", { size: 20, color: GRIS }),

      linea(),

      p("Este documento describe cómo funciona el negocio y el flujo del dinero, y plantea las preguntas concretas que necesitamos resolver antes de constituir la estructura y empezar a operar con dinero real.", { size: 23 }),
      pMix([["No contiene una propuesta tributaria: ", true],
            "las opciones que se mencionan son las que hemos identificado leyendo, y precisamente lo que buscamos es que usted nos diga cuál corresponde y qué nos falta."], { size: 23 }),

      /* ================= 1. EL NEGOCIO ================= */
      h1("1. Qué es SOCIO"),

      p("SOCIO es una plataforma que conecta dos partes que hoy no se encuentran: empresas que tienen producto y quieren venderlo más, y personas que quieren generar ingresos vendiendo sin poner inventario ni capital."),

      p("No es una tienda. No compramos mercadería, no tenemos almacén y no fijamos los precios: cada marca carga su catálogo, define el precio al que ella cobra y el precio de venta al público. Nosotros ponemos la plataforma, validamos que el pago del cliente sea real, coordinamos el despacho con la marca y respondemos ante un reclamo."),

      pMix([["Intervienen tres partes en cada venta:"]], { after: 100 }),
      bullet("La MARCA (proveedor). Tiene el producto, lo despacha y cobra su precio mayorista."),
      bullet("El SOCIO (vendedor independiente). Consigue al cliente y cierra la venta. Gana una comisión. No tiene contrato laboral con nosotros ni con la marca."),
      bullet("SOCIO (la plataforma, nosotros). Intermediamos. Nuestro ingreso es una comisión por cada venta."),

      p("Hoy estamos por lanzar un piloto con una sola marca — Lab Péptidos Perú, empresa del titular de este proyecto — y entre 10 y 20 vendedores. El objetivo posterior es abrir a marcas de terceros de cualquier rubro.", { after: 200 }),

      /* ================= 2. EL FLUJO DEL DINERO ================= */
      h1("2. Cómo se mueve el dinero en una venta"),

      p("Este es el punto donde necesitamos su orientación, así que lo ponemos con números reales de un producto que ya está cargado en el sistema."),

      h2("El ejemplo"),
      pMix([["Producto: ", true], "GHK-Cu, vial de 50 mg."], { after: 80 }),
      pMix([["Precio mayorista de la marca: ", true], "S/ 129.67 (lo que la marca quiere cobrar por unidad)."], { after: 80 }),
      pMix([["Precio de venta al público: ", true], "S/ 175.00 (lo que paga el cliente final)."], { after: 80 }),
      pMix([["Diferencia disponible: ", true], "S/ 45.33, que se reparte entre el vendedor y la plataforma."], { after: 160 }),

      p("El porcentaje del vendedor sube según su historial de ventas entregadas (de 10 % a 20 % del precio de venta). La marca cobra siempre lo mismo: el aumento del vendedor sale de nuestra comisión, no del bolsillo de la marca.", { after: 160 }),

      tabla(
        [1700, 1500, 1600, 1600, 1500, 1460],
        ["Nivel del vendedor", "Cliente paga", "Vendedor gana", "Marca cobra", "Queda para SOCIO", "Neto sin IGV"],
        [
          ["Bronce (10 %)", "175.00", "17.50", "129.67", "27.83", ["23.58", { color: VERDE, bold: true }]],
          ["Plata (13 %)",  "175.00", "22.75", "129.67", "22.58", ["19.14", { color: VERDE, bold: true }]],
          ["Oro (16 %)",    "175.00", "28.00", "129.67", "17.33", ["14.69", { color: VERDE, bold: true }]],
          ["Diamante (20 %)", "175.00", "35.00", "129.67", "10.33", ["8.75", { color: VERDE, bold: true }]]
        ]
      ),
      nota("Importes en soles. La columna final es nuestra comisión ya sin el IGV que asumimos que debemos facturar sobre ella — justamente uno de los puntos a confirmar."),

      h2("El recorrido del dinero, hoy"),
      p("Tal como está planteado el piloto, el dinero se mueve así:"),
      bullet("El cliente final le paga al vendedor, directamente (Yape, Plin, efectivo o transferencia)."),
      bullet("El vendedor transfiere a una cuenta de SOCIO el precio de venta menos su comisión. En el ejemplo, un vendedor Bronce transfiere S/ 157.50 y se queda con S/ 17.50."),
      bullet("SOCIO valida ese pago contra el estado de cuenta y recién ahí le avisa a la marca que despache."),
      bullet("SOCIO le transfiere a la marca su precio mayorista (S/ 129.67), reteniendo su comisión."),

      p("Es decir: por nuestras cuentas pasa dinero que no es nuestro. De los S/ 157.50 que recibimos, S/ 129.67 son de la marca y solo S/ 27.83 nos corresponden.", { after: 200 }),

      new Paragraph({ children: [new PageBreak()] }),

      /* ================= 3. LO QUE HEMOS ENTENDIDO ================= */
      h1("3. Las dos figuras que hemos identificado"),

      p("Leyendo sobre el tema encontramos dos caminos posibles. Los resumimos como los entendimos, con la advertencia de que puede haber errores de concepto — parte de lo que le pedimos es corregirlos."),

      h2("Figura A — Comisión mercantil (intermediación)"),
      p("La venta sería de la marca al cliente final. Nosotros nunca compramos ni vendemos el producto: solo intermediamos, y nuestro único ingreso es la comisión, por la que emitiríamos factura con IGV."),
      pMix([["Lo que nos atrae: ", true], "tributaríamos solo sobre lo que realmente ganamos."], { after: 80 }),
      pMix([["Lo que nos preocupa: ", true], "que el dinero que pasa por nuestras cuentas sea tratado como ingreso nuestro. Entendemos que hace falta contrato de comisión con cada marca y liquidaciones documentadas, pero no sabemos si eso basta ni cómo debe estar hecho."], { after: 160 }),

      h2("Figura B — Compra y reventa"),
      p("Le compraríamos a la marca con factura y venderíamos al cliente con comprobante propio, pagando IGV solo sobre nuestro margen por la vía del crédito fiscal."),
      pMix([["Lo que nos atrae: ", true], "control total del comprobante que recibe el cliente."], { after: 80 }),
      pMix([["Lo que nos preocupa: ", true], "exige factura de todas las marcas, más capital de trabajo y más contabilidad. Y nos deja dudas sobre cómo encaja el vendedor independiente en el medio."], { after: 200 }),

      /* ================= 4. EL PROBLEMA CONCRETO ================= */
      h1("4. El problema que nos trajo aquí: la boleta que viaja en el paquete"),

      p("En el Perú el paquete debe salir con su comprobante de venta. Aquí es donde nos trabamos, porque en una misma operación hay tres importes distintos y no sabemos cuál debe figurar ni quién debe emitirlo."),

      tabla(
        [3000, 1900, 4460],
        ["Importe", "Monto", "De quién es"],
        [
          ["Precio de venta al público", "175.00", "Lo que efectivamente paga el cliente"],
          ["Precio mayorista", "129.67", "Lo que cobra la marca"],
          ["Comisión del vendedor", "17.50", "Lo que retiene el vendedor"]
        ],
        1
      ),
      nota("En el ejemplo con un vendedor Bronce."),

      p("Nuestro razonamiento — que puede estar equivocado — es que la boleta debería decir S/ 175.00, porque es lo que el cliente pagó, y que emitirla por S/ 129.67 generaría dos problemas: el cliente vería un monto distinto al que pagó, y el comprobante no reflejaría la operación real.", { after: 100 }),

      p("Pero si la boleta la emite la marca por S/ 175.00, la marca estaría declarando un ingreso de S/ 175.00 cuando en realidad recibe S/ 129.67. Suponemos que la diferencia se deduce como gasto por las comisiones, pero no sabemos si eso es correcto ni cómo se documenta.", { after: 200 }),

      /* ================= 5. PREGUNTAS ================= */
      h1("5. Nuestras preguntas"),

      p("Estas son las decisiones que no podemos tomar solos y que bloquean el desarrollo. El sistema está construido de forma que podemos programar la regla que usted defina; lo que no queremos es inventarla.", { after: 180 }),

      pregunta(1, "¿Qué figura corresponde: comisión mercantil, compra-reventa, o una mixta según si el producto es propio o de un tercero?"),
      nota("Nos inclinamos por la mixta, pero no sabemos si complica más de lo que resuelve."),

      pregunta(2, "¿Quién emite el comprobante al cliente final y por qué monto?"),
      nota("Es el problema de la sección 4. Necesitamos una respuesta que podamos programar."),

      pregunta(3, "¿El dinero de terceros que pasa por nuestras cuentas puede tratarse como recaudación por cuenta de la marca, y no como ingreso nuestro?"),
      nota("Y si es así: ¿qué documentación exige exactamente? ¿Sirve una liquidación automática por marca que detalle lo recaudado, la comisión y lo transferido? Podemos generar ese documento por cada período; díganos qué campos debe llevar."),

      pregunta(4, "¿Cómo tributa el vendedor independiente, y qué obligación nos genera a nosotros?"),
      nota("Hoy el vendedor cobra directo a su cliente y retiene su comisión. Entendemos que sería un negocio independiente responsable de sus propios impuestos, y así lo declararían los términos de uso. Si en el futuro centralizamos el cobro y le pagamos nosotros: ¿recibo por honorarios? ¿retención de renta de cuarta categoría? ¿Nos conviene ofrecerle retenerle el impuesto automáticamente?"),

      pregunta(5, "¿La comisión mercantil está afecta a detracciones (SPOT)? ¿Desde qué monto y con qué porcentaje?"),
      nota("Lo mencionamos porque lo leímos, pero no lo entendemos bien."),

      pregunta(6, "¿Qué régimen tributario nos corresponde para arrancar, y en qué momento habría que cambiarlo?"),
      nota("Suponemos MYPE Tributario, pero no lo hemos validado."),

      pregunta(7, "¿Qué porcentaje mínimo de comisión deberíamos cobrar para que, después de impuestos, la operación se sostenga?"),
      nota("Hoy el sistema exige que cada producto deje al menos 25.9 % de diferencia entre el precio mayorista y el de venta, calculado así: 20 % para el mejor vendedor más 5.9 % para nosotros, que con el IGV nos deja 5 % limpio. No hemos considerado el Impuesto a la Renta en ese cálculo, y sospechamos que deberíamos."),

      linea(),

      /* ================= 6. LO QUE EL SISTEMA REGISTRA ================= */
      h1("6. Qué información puede entregar el sistema"),

      p("Mencionamos esto porque puede ahorrarnos trabajo manual: el sistema ya guarda cada operación en una base de datos, con los montos separados desde el momento de la venta. De cada pedido queda registrado:"),

      bullet("Código de pedido, fecha, marca y vendedor."),
      bullet("Precio de venta al público, precio mayorista, comisión del vendedor y comisión de la plataforma — cada uno en su propio campo."),
      bullet("Datos del cliente final: nombre, documento y dirección de entrega."),
      bullet("El pago: número de operación bancaria, monto, método y fecha en que se validó contra el estado de cuenta."),
      bullet("Las fechas de despacho y de entrega confirmada."),
      bullet("Una bitácora que registra quién hizo cada cosa y cuándo, y que no se puede editar ni borrar."),

      p("Con eso podemos generar automáticamente el reporte que usted necesite, en el formato y con la periodicidad que indique. Si hay campos que faltan para el sustento ante SUNAT, agregarlos ahora es sencillo; hacerlo con mil pedidos encima, no.", { after: 200 }),

      linea(),

      /* ================= CIERRE ================= */
      h1("Lo que esperamos de esta sesión"),
      bullet("Definir la figura y, con ella, quién emite qué comprobante y por qué monto."),
      bullet("Saber qué documentación debemos producir y conservar desde el primer pedido."),
      bullet("Un borrador de contrato de comisión con las marcas."),
      bullet("La lista de campos que debe tener la liquidación por marca, para programarla."),

      p("Preferimos gastar en resolverlo ahora que corregirlo con operaciones hechas.", { after: 200, italics: true }),

      new Paragraph({
        spacing: { before: 300 },
        border: { top: { style: BorderStyle.SINGLE, size: 6, color: "D8DEDB" } },
        children: [new TextRun({
          text: "Contacto: Jason Cruz  ·  Proyecto SOCIO  ·  Lima, Perú",
          font: FUENTE, size: 19, color: GRIS
        })]
      })
    ]
  }]
});

Packer.toBuffer(doc).then(b => {
  fs.writeFileSync(process.argv[2] || "SOCIO-consulta-contador.docx", b);
  console.log("escrito:", process.argv[2]);
});
