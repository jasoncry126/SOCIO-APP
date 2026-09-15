(function () {
  "use strict";

  window.__BRAND__ = {
    name: "LAB PEPTIDOS PERU",
    tagline: "Marketing por Recomendación",
    est: "Est. 2026",
    whatsapp: "+51 930722800",
    whatsappRaw: "51930722800",

    // Categorías del catálogo (color por categoría)
    categories: {
      recuperacion: { label: "Recuperación", color: "#00C6A2" },
      crecimiento:  { label: "Crecimiento",  color: "#1A6EF5" },
      metabolismo:  { label: "Metabolismo",  color: "#E08A3C" },
      longevidad:   { label: "Longevidad",   color: "#C9A227" },
      piel:         { label: "Piel",         color: "#F5D67A" },
      cognicion:    { label: "Cognición",    color: "#8E7CF0" },
      vitalidad:    { label: "Vitalidad",    color: "#E0637A" },
      combos:       { label: "Combos",       color: "#3FC6B7" },
      accesorios:   { label: "Accesorios",   color: "#96A7BF" }
    },

    // Catálogo completo de péptidos para investigación
    products: [
      { id: "bpc-157", name: "BPC-157", cat: "recuperacion", conc: [5, 10], prices: { "5": 175, "10": 300 }, blurb: "Pentadecapéptido derivado de una proteína gástrica, ampliamente estudiado en modelos de investigación por su papel en la señalización de reparación de tejidos." },
      { id: "tb-500", name: "TB-500", cat: "recuperacion", conc: [5, 10], prices: { "10": 245 }, blurb: "Fragmento sintético relacionado con la Timosina Beta-4, investigado por su rol en la organización de la actina y la movilidad celular." },
      { id: "kpv", name: "KPV", cat: "recuperacion", conc: [10], prices: { "10": 215 }, blurb: "Tripéptido terminal de la α-MSH, estudiado en investigación por su relación con las vías de señalización inflamatoria." },
      { id: "goralatide", name: "Goralatide", cat: "recuperacion", conc: [5], blurb: "Tetrapéptido (AcSDKP) investigado por su participación en la regulación de la proliferación de células madre hematopoyéticas." },
      { id: "ara-290", name: "ARA-290", cat: "recuperacion", conc: [10], blurb: "Péptido derivado de la eritropoyetina (cibinetida), investigado por su acción sobre el receptor de reparación innata y su papel en la protección tisular y la modulación de la inflamación." },
      { id: "ipamorelin", name: "Ipamorelin", cat: "crecimiento", conc: [5, 10], prices: { "5": 215, "10": 370 }, blurb: "Pentapéptido selectivo estudiado como secretagogo en la investigación del eje de la hormona de crecimiento." },
      { id: "sermorelin", name: "Sermorelin", cat: "crecimiento", conc: [5, 10], prices: { "5": 215 }, blurb: "Análogo del GHRH (1-29) investigado por su interacción con los receptores de liberación de hormona de crecimiento." },
      { id: "cjc-1295-sin-dac", name: "CJC-1295 sin DAC", label: "CJC-1295", name2: "SIN DAC", cat: "crecimiento", conc: [2, 5], prices: { "2": 215, "5": 360 }, blurb: "Análogo del GHRH (Mod GRF 1-29) de vida media corta, estudiado en investigación del eje somatotropo." },
      { id: "cjc-1295-con-dac", name: "CJC-1295 con DAC", label: "CJC-1295", name2: "CON DAC", cat: "crecimiento", conc: [2, 5], prices: { "2": 255, "5": 450 }, blurb: "Análogo del GHRH con Drug Affinity Complex, investigado por su vida media extendida en modelos de laboratorio." },
      { id: "aod-9604", name: "AOD-9604", cat: "metabolismo", conc: [5, 10], prices: { "5": 330 }, blurb: "Fragmento (176-191) de la hormona de crecimiento, estudiado en investigación por su relación con el metabolismo de los lípidos." },
      { id: "mots-c", name: "MOTS-c", cat: "metabolismo", conc: [10], prices: { "10": 255 }, blurb: "Péptido derivado del ADN mitocondrial, investigado por su papel en la homeostasis metabólica celular." },
      { id: "retatrutide", name: "Retatrutide", label: "RETA", cat: "metabolismo", conc: [5, 10, 20, 30, 40, 50], img: "reta", blurb: "Triple agonista de los receptores GIP, GLP-1 y glucagón, investigado por su potente acción sobre el gasto energético, la lipólisis y el control del apetito. Estudiado en el contexto de la definición corporal y el manejo del peso, con enfoque en el tejido adiposo." },
      { id: "tirzepatide", name: "Tirzepatide", label: "TIRSEP", cat: "metabolismo", conc: [2.5, 5, 10, 20, 30, 40, 50, 60], img: "tirsep", blurb: "Doble agonista de los receptores GIP y GLP-1, investigado por su marcado efecto sobre el control glucémico, la saciedad y la reducción de la masa grasa en modelos metabólicos." },
      { id: "tesamorelin", name: "Tesamorelin", label: "TESA", cat: "metabolismo", conc: [2, 5, 10], prices: { "2": 215, "5": 400, "10": 580 }, img: "tesa", blurb: "Análogo estabilizado de la GHRH, investigado por su acción sobre el eje de la hormona de crecimiento y, en particular, por su relación con la reducción de la grasa visceral." },
      { id: "n-acetil-epitalon", name: "N-Acetil Epitalon", label: "EPITALON", name2: "N-ACETIL", cat: "longevidad", conc: [10, 50], prices: { "10": 215, "50": 370 }, blurb: "Tetrapéptido bioregulador acetilado, estudiado en investigación por su relación con la telomerasa y los ritmos de la pineal." },
      { id: "foxo4-dri", name: "FoxO4-DRI", cat: "longevidad", conc: [5, 10], prices: { "10": 785 }, blurb: "Péptido D-retro-inverso investigado en la ciencia de la senescencia celular y la interacción FoxO4–p53." },
      { id: "pinealon", name: "Pinealon", cat: "longevidad", conc: [20], prices: { "20": 275 }, blurb: "Tripéptido bioregulador para la pineal, estudiado en investigación de la función neuronal." },
      { id: "cardiogen", name: "Cardiogen", cat: "longevidad", conc: [20], prices: { "20": 265 }, blurb: "Bioregulador peptídico estudiado en investigación asociada al tejido cardíaco." },
      { id: "cortagen", name: "Cortagen", cat: "longevidad", conc: [20], prices: { "20": 265 }, blurb: "Bioregulador peptídico corto investigado en el contexto del tejido nervioso periférico." },
      { id: "crystagen", name: "Crystagen", cat: "longevidad", conc: [20], prices: { "20": 265 }, blurb: "Bioregulador peptídico estudiado en investigación relacionada con la respuesta inmunitaria." },
      { id: "ovagen", name: "Ovagen", cat: "longevidad", conc: [20], prices: { "20": 245 }, blurb: "Bioregulador peptídico investigado en el contexto de la función hepática en modelos de laboratorio." },
      { id: "prostamax", name: "Prostamax", cat: "longevidad", conc: [20], prices: { "20": 375 }, blurb: "Complejo peptídico estudiado en investigación asociada al tejido prostático." },
      { id: "vesilute", name: "Vesilute", cat: "longevidad", conc: [20], prices: { "20": 215 }, blurb: "Bioregulador peptídico investigado en el contexto del tejido de las vías urinarias." },
      { id: "thymalin", name: "Thymalin", cat: "longevidad", conc: [10, 20], prices: { "20": 295 }, blurb: "Extracto peptídico del timo ampliamente estudiado en investigación de la modulación inmunitaria." },
      { id: "timosina-alpha-1", name: "Timosina Alpha-1", label: "TIMOSINA", name2: "ALPHA-1", cat: "longevidad", conc: [5, 10], prices: { "5": 235, "10": 400 }, blurb: "Péptido de 28 aminoácidos investigado por su papel en la señalización del sistema inmunitario." },
      { id: "ghk-cu", name: "GHK-Cu", cat: "piel", conc: [50, 100], prices: { "50": 175, "100": 300 }, blurb: "Tripéptido de cobre presente de forma natural en el plasma, muy estudiado en cosmética por su afinidad con el cobre y la matriz dérmica." },
      { id: "matrixyl", name: "Matrixyl", cat: "piel", conc: [50], blurb: "Palmitoil pentapéptido de uso cosmético estudiado por su relación con las proteínas de la matriz extracelular." },
      { id: "argireline", name: "Argireline", cat: "piel", conc: [50], blurb: "Acetil hexapéptido-8 de uso cosmético estudiado por su efecto sobre la contracción muscular de expresión." },
      { id: "snap-8", name: "SNAP-8", cat: "piel", conc: [10, 50], prices: { "10": 215 }, blurb: "Acetil octapéptido-3 de uso cosmético, extensión del hexapéptido, estudiado en el cuidado de la piel de expresión." },
      { id: "selank", name: "Selank", cat: "cognicion", conc: [5, 10], prices: { "5": 165, "10": 230 }, blurb: "Heptapéptido sintético derivado de la tuftsina, investigado en el contexto de la modulación de la ansiedad y la cognición." },
      { id: "semax", name: "Semax", cat: "cognicion", conc: [5, 10], prices: { "10": 175 }, blurb: "Péptido derivado de la ACTH (4-10), estudiado en investigación nootrópica y de neuroprotección." },
      { id: "pt-141", name: "PT-141", cat: "vitalidad", conc: [10], prices: { "10": 255 }, blurb: "Bremelanotida, análogo de la melanocortina investigado por su interacción con los receptores MC en modelos de laboratorio." },
      { id: "melanotan-ii", name: "Melanotan II", label: "MELANOTAN", name2: "II", cat: "vitalidad", conc: [10], prices: { "10": 235 }, blurb: "Análogo de la α-MSH estudiado en investigación por su relación con la síntesis de melanina." },
      { id: "kisspeptina-10", name: "Kisspeptina-10", cat: "vitalidad", conc: [10], prices: { "10": 275 }, blurb: "Fragmento de 10 aminoácidos de la kisspeptina, investigado por su papel en la señalización del eje reproductivo y la liberación de GnRH." },
      { id: "klow", name: "KLOW", cat: "combos", conc: [null], prices: { "blend": 680 }, unit: "blend", blend: [{n:"BPC-157",mg:10},{n:"TB-500",mg:10},{n:"KPV",mg:10},{n:"GHK-Cu",mg:50}], blurb: "Blend de investigación en un solo vial: BPC-157 (10 mg), TB-500 (10 mg), KPV (10 mg) y GHK-Cu (50 mg). Formulado para estudios de barrera, recuperación y reparación." },
      { id: "glow-30", name: "GLOW 30", cat: "combos", conc: [null], prices: { "blend": 340 }, unit: "blend", blend: [{n:"BPC-157",mg:5},{n:"TB-500",mg:5},{n:"GHK-Cu",mg:20}], blurb: "Combinación de investigación en un solo vial de 30 mg totales: BPC-157 (5 mg), TB-500 (5 mg) y GHK-Cu (20 mg). Estudiada en el contexto de piel, cabello y reparación tisular." },
      { id: "glow-50", name: "GLOW 50", cat: "combos", conc: [null], prices: { "blend": 470 }, unit: "blend", blend: [{n:"BPC-157",mg:5},{n:"TB-500",mg:10},{n:"GHK-Cu",mg:35}], blurb: "Versión potenciada del blend regenerativo en un solo vial de 50 mg totales: BPC-157 (5 mg), TB-500 (10 mg) y GHK-Cu (35 mg). Estudiada en el contexto de piel, cabello y reparación tisular." },
      { id: "wolverine", name: "Wolverine", cat: "combos", conc: [10, 20], prices: { "10": 255, "20": 440 }, unit: "mg", blend: [{n:"BPC-157",mg:5},{n:"TB-500",mg:5}], blurb: "Blend de reparación que combina BPC-157 y TB-500 en un mismo vial. La presentación de 10 mg contiene 5 mg de cada uno; la de 20 mg contiene 10 mg de cada uno. Estudiado en el contexto de recuperación de tejidos conectivos." },
      { id: "stack-cardio", name: "Stack Cardio", cat: "combos", conc: [null], unit: "blend", blend: [{n:"Vesugen",mg:10},{n:"Cardiogen",mg:10},{n:"Epitalon",mg:10}], blurb: "Stack de bioreguladores en un solo vial de 30 mg totales (Vesugen · Cardiogen · Epitalon), orientado en investigación al eje vascular y la longevidad celular." },
      { id: "stack-neuro", name: "Stack Neuro", cat: "combos", conc: [null], unit: "blend", blend: [{n:"Pinealon",mg:10},{n:"Epitalon",mg:10},{n:"Cortagen",mg:10}], blurb: "Stack de bioreguladores en un solo vial de 30 mg totales (Pinealon · Epitalon · Cortagen), estudiado en el contexto de la función neuro-cognitiva y el envejecimiento celular." },
      { id: "agua-bacteriostatica", name: "Agua Bacteriostática", label: "AGUA BAC", name2: "", cat: "accesorios", conc: [3, 10], prices: { "3": 10, "10": 15 }, unit: "ml", blurb: "Agua estéril con alcohol bencílico al 0.9%, libre de pirógenos, para la reconstitución de péptidos liofilizados en investigación." },
      { id: "follistatin-315", name: "Follistatin-315", label: "FOLLISTATIN", name2: "315", cat: "crecimiento", conc: [1], prices: { "1": 175 }, blurb: "Fragmento de la folistatina investigado por su capacidad de unir y neutralizar la miostatina, en el contexto del crecimiento y la reparación del músculo esquelético." },
      { id: "ghrp-2", name: "GHRP-2", cat: "crecimiento", conc: [2, 5], prices: { "2": 175, "5": 300 }, blurb: "Secretagogo de la hormona de crecimiento (péptido liberador de GH) estudiado por estimular su secreción a través de la vía de la grelina." },
      { id: "ghrp-6", name: "GHRP-6", cat: "crecimiento", conc: [2, 5], prices: { "2": 175, "5": 300 }, blurb: "Péptido liberador de hormona de crecimiento investigado por inducir picos de GH y por su marcado efecto sobre el apetito." },
      { id: "gonadorelina", name: "Gonadorelina", cat: "crecimiento", conc: [5], prices: { "5": 215 }, blurb: "Análogo de la GnRH investigado por su acción sobre la hipófisis para regular la liberación de LH y FSH del eje reproductivo." },
      { id: "igf-1-lr3", name: "IGF-1 LR3", label: "IGF-1", name2: "LR3", cat: "crecimiento", conc: [1], prices: { "1": 435 }, blurb: "Variante de larga duración del factor de crecimiento insulínico tipo 1, estudiada por su potente señalización anabólica sobre el crecimiento y la reparación celular." },
      { id: "dsip", name: "DSIP", cat: "cognicion", conc: [5, 10], prices: { "5": 175, "10": 300 }, blurb: "Péptido delta inductor del sueño, investigado por su relación con la arquitectura del sueño profundo y la modulación del estrés." },
      { id: "dihexa", name: "Dihexa", cat: "cognicion", conc: [5, 10], prices: { "5": 385, "10": 700 }, blurb: "Derivado de la angiotensina IV investigado como potente nootrópico por su relación con la sinaptogénesis y el factor de crecimiento hepatocitario." },
      { id: "oxitocina", name: "Oxitocina", cat: "cognicion", conc: [10], prices: { "10": 175 }, blurb: "Nonapéptido neurohipofisario estudiado por su papel en el vínculo social, la confianza y la modulación del estado de ánimo." },
      { id: "peg-mgf", name: "PEG-MGF", cat: "recuperacion", conc: [5], prices: { "5": 355 }, blurb: "Factor de crecimiento mecánico pegilado, investigado por su rol en la activación de células satélite y la reparación del músculo tras el esfuerzo." },
      { id: "ll-37", name: "LL-37", cat: "longevidad", conc: [5], prices: { "5": 275 }, blurb: "Péptido de la catelicidina humana investigado por su amplia actividad antimicrobiana y su papel en la inmunidad innata y la reparación tisular." },
      { id: "humanin", name: "Humanin", cat: "longevidad", conc: [10], prices: { "10": 685 }, blurb: "Péptido derivado del ADN mitocondrial estudiado por su rol citoprotector y su relación con el metabolismo y el envejecimiento celular." },
      { id: "melanotan-1", name: "Melanotan I", label: "MELANOTAN", name2: "I", cat: "vitalidad", conc: [10], prices: { "10": 235 }, blurb: "Análogo de la α-MSH (afamelanotida) investigado por su relación con la síntesis de melanina y la fotoprotección de la piel." },
      { id: "livagen", name: "Livagen", cat: "longevidad", conc: [20], prices: { "20": 245 }, blurb: "Bioregulador peptídico corto estudiado en investigación asociada a la función hepática y a la regulación celular." },
      { id: "pancreagen", name: "Pancreagen", cat: "longevidad", conc: [20], prices: { "20": 245 }, blurb: "Bioregulador peptídico investigado en el contexto del tejido pancreático y la regulación de su función." }
    ],

    steps: [
      {
        n: "01",
        title: "Define tu objetivo",
        text: "¿Hipertrofia, pérdida de grasa o antienvejecimiento? Todo protocolo empieza por una meta clara y medible."
      },
      {
        n: "02",
        title: "Selecciona el péptido ideal",
        text: "Consulta nuestra guía y los estudios de referencia. Cada molécula tiene un mecanismo y una evidencia distinta."
      },
      {
        n: "03",
        title: "Realiza tu pedido seguro",
        text: "Confirma por WhatsApp y recibe tu vial liofilizado, sellado y con trazabilidad, de forma segura en todo el Perú."
      }
    ],

    knowledge: [
      {
        id: "atom",
        title: "Interacción Molecular",
        text: "Visualiza cómo los aminoácidos se enlazan para formar la cadena peptídica y su geometría en el espacio."
      },
      {
        id: "receptor",
        title: "Mecanismo de Acción",
        text: "Observa la unión ligando–receptor: cómo el péptido activa la señalización celular que dispara el efecto biológico."
      },
      {
        id: "cycle",
        title: "Guías de Ciclos",
        text: "Comprende la cinética de un protocolo: fase de carga, meseta y descanso a lo largo de las semanas."
      }
    ]
  };
})();
