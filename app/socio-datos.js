/* ===========================================================================
   SOCIO · Capa de datos (Supabase)
   ---------------------------------------------------------------------------
   Todo lo que los tres paneles necesitan para hablar con la base vive aquí, en
   un solo sitio. Los paneles no saben de Supabase: llaman a estas funciones.

   Cómo se relaciona la cuenta con la ficha
   ----------------------------------------
   Los permisos de la base comparan auth.uid() con el id de la fila. Por eso al
   registrar una marca su fila en 'marcas' se guarda con el MISMO id que le dio
   Supabase Auth. Si no coincidieran, la marca no vería ni su propio perfil.

   Celular y clave, no correo
   --------------------------
   El panel pide celular + clave, pero Supabase Auth trabaja con correo. Se
   construye uno interno a partir del celular (9x xxx xxx → 9xxxxxxxx@…) que el
   usuario nunca ve ni escribe. Y como Supabase exige claves de 6 caracteres y
   el panel acepta 4 dígitos, se le añade un sufijo fijo: no cambia la fuerza de
   la clave, solo cumple el mínimo.
   =========================================================================== */

(function (raiz) {
  "use strict";

  var DOMINIO_MARCAS = "marcas.socio.local";
  var DOMINIO_SOCIOS = "socios.socio.local";
  var SUFIJO_CLAVE = "-socioapp";

  var cliente = null;
  var errorConfig = null;

  /* ------------------------------------------------------------------ */
  /* Arranque                                                            */
  /* ------------------------------------------------------------------ */

  function configurado() {
    var c = raiz.SOCIO_CONFIG || {};
    return !!(c.URL && c.ANON);
  }

  function iniciar() {
    if (cliente) return cliente;
    var c = raiz.SOCIO_CONFIG || {};
    if (!c.URL || !c.ANON) {
      errorConfig = "Falta configurar la conexión: abre socio-config.js y pega " +
                    "el Project URL y la clave anon de tu proyecto Supabase.";
      return null;
    }
    if (!raiz.supabase || !raiz.supabase.createClient) {
      errorConfig = "No cargó la librería de Supabase. Revisa tu conexión a internet.";
      return null;
    }
    cliente = raiz.supabase.createClient(c.URL, c.ANON);
    return cliente;
  }

  function exigirCliente() {
    var c = iniciar();
    if (!c) throw new Error(errorConfig || "Sin conexión a la base.");
    return c;
  }

  /* Traduce los errores de Supabase a algo que una persona entienda. */
  function explicar(error, contexto) {
    if (!error) return null;
    var m = (error.message || "").toLowerCase();

    if (m.indexOf("email not confirmed") !== -1)
      return "La cuenta se creó pero pide confirmar el correo. En Supabase: " +
             "Authentication → Sign In / Providers → desactiva «Confirm email».";
    if (m.indexOf("invalid login credentials") !== -1)
      return "Celular o clave incorrectos.";
    if (m.indexOf("already registered") !== -1 || m.indexOf("already been registered") !== -1)
      return "Ese celular ya tiene una cuenta.";
    if (m.indexOf("duplicate key") !== -1 && m.indexOf("ruc") !== -1)
      return "Ese RUC ya está registrado por otra marca.";
    if (m.indexOf("duplicate key") !== -1 && m.indexOf("celular") !== -1)
      return "Ese celular ya está registrado.";
    if (m.indexOf("duplicate key") !== -1 && m.indexOf("numero_operacion") !== -1)
      return "Ese número de operación ya se usó en otro pedido.";
    if (m.indexOf("row-level security") !== -1)
      return "La base no permitió esta operación. Suele ser que falta aplicar " +
             "la migración de permisos (20260912100000_permisos_para_operar.sql).";
    if (m.indexOf("presentaciones_check") !== -1)
      return "El precio de página tiene que ser mayor que el mayorista.";
    if (m.indexOf("failed to fetch") !== -1)
      return "No se pudo conectar con la base. Revisa tu internet y el Project URL.";

    return (contexto ? contexto + ": " : "") + (error.message || "Error desconocido");
  }

  function correoDe(celular, dominio) {
    return String(celular).replace(/\D/g, "") + "@" + dominio;
  }

  function claveDe(clave) {
    return String(clave) + SUFIJO_CLAVE;
  }

  /* ------------------------------------------------------------------ */
  /* Cuentas de marca                                                    */
  /* ------------------------------------------------------------------ */

  async function registrarMarca(d) {
    var sb = exigirCliente();

    var alta = await sb.auth.signUp({
      email: correoDe(d.celular, DOMINIO_MARCAS),
      password: claveDe(d.clave)
    });
    if (alta.error) throw new Error(explicar(alta.error, "No se pudo crear la cuenta"));

    var usuario = alta.data && alta.data.user;
    var sesion = alta.data && alta.data.session;
    if (!usuario) throw new Error("Supabase no devolvió la cuenta creada.");
    if (!sesion) {
      // Sin sesión, el insert de abajo lo rechazarían los permisos.
      throw new Error("La cuenta se creó pero quedó pendiente de confirmar correo. " +
                      "En Supabase: Authentication → Sign In / Providers → desactiva «Confirm email», " +
                      "y vuelve a intentar.");
    }

    var fila = {
      id: usuario.id,                    // debe coincidir con auth.uid()
      nombre: d.nombre,
      ruc: d.ruc,
      giro: d.giro,
      ciudad_almacen: d.almacen,
      ciudad_punto: d.punto || null,
      celular: d.celular,
      clave_hash: "gestionado_por_supabase_auth"
    };

    var res = await sb.from("marcas").insert(fila).select().single();
    if (res.error) throw new Error(explicar(res.error, "No se pudo guardar la marca"));
    return res.data;
  }

  async function ingresarMarca(celular, clave) {
    var sb = exigirCliente();
    var r = await sb.auth.signInWithPassword({
      email: correoDe(celular, DOMINIO_MARCAS),
      password: claveDe(clave)
    });
    if (r.error) throw new Error(explicar(r.error, "No se pudo entrar"));
    return await marcaActual();
  }

  async function marcaActual() {
    var sb = iniciar();
    if (!sb) return null;
    var s = await sb.auth.getSession();
    if (!s.data || !s.data.session) return null;
    var res = await sb.from("marcas").select("*").eq("id", s.data.session.user.id).maybeSingle();
    if (res.error) throw new Error(explicar(res.error, "No se pudo leer tu marca"));
    return res.data;
  }

  async function salir() {
    var sb = iniciar();
    if (sb) await sb.auth.signOut();
  }

  /* ------------------------------------------------------------------ */
  /* Cuentas de socio                                                    */
  /* ------------------------------------------------------------------ */

  async function registrarSocio(d) {
    var sb = exigirCliente();

    var alta = await sb.auth.signUp({
      email: correoDe(d.celular, DOMINIO_SOCIOS),
      password: claveDe(d.clave)
    });
    if (alta.error) throw new Error(explicar(alta.error, "No se pudo crear tu cuenta"));

    var usuario = alta.data && alta.data.user;
    var sesion = alta.data && alta.data.session;
    if (!usuario) throw new Error("Supabase no devolvió la cuenta creada.");
    if (!sesion) {
      throw new Error("La cuenta se creó pero quedó pendiente de confirmar correo. " +
                      "En Supabase: Authentication → Sign In / Providers → desactiva «Confirm email», " +
                      "y vuelve a intentar.");
    }

    var fila = {
      id: usuario.id,                    // debe coincidir con auth.uid()
      nombre: d.nombre,
      dni: d.dni,
      celular: d.celular,
      ciudad: d.ciudad,
      clave_hash: "gestionado_por_supabase_auth"
    };

    var res = await sb.from("usuarios_socios").insert(fila).select().single();
    if (res.error) throw new Error(explicar(res.error, "No se pudo guardar tu ficha"));
    return res.data;
  }

  async function ingresarSocio(celular, clave) {
    var sb = exigirCliente();
    var r = await sb.auth.signInWithPassword({
      email: correoDe(celular, DOMINIO_SOCIOS),
      password: claveDe(clave)
    });
    if (r.error) throw new Error(explicar(r.error, "No se pudo entrar"));
    return await socioActual();
  }

  async function socioActual() {
    var sb = iniciar();
    if (!sb) return null;
    var s = await sb.auth.getSession();
    if (!s.data || !s.data.session) return null;
    var res = await sb.from("usuarios_socios").select("*")
                      .eq("id", s.data.session.user.id).maybeSingle();
    if (res.error) throw new Error(explicar(res.error, "No se pudo leer tu ficha"));
    return res.data;
  }

  /* ------------------------------------------------------------------ */
  /* El catálogo que ve el socio                                         */
  /* ------------------------------------------------------------------ */

  /* Se lee de la VISTA catalogo_publico, no de las tablas. La vista no tiene
     columna de precio mayorista: aunque alguien manipule esta función desde la
     consola del navegador, ese dato no está del otro lado (CLAUDE.md regla 1). */
  async function cargarCatalogoPublico() {
    var sb = exigirCliente();
    var res = await sb.from("catalogo_publico")
                      .select("*")
                      .order("producto", { ascending: true });
    if (res.error) throw new Error(explicar(res.error, "No se pudo leer el catálogo"));

    // Llega una fila por presentación; el panel las quiere agrupadas por
    // producto, y los productos agrupados por marca.
    var porProducto = {};
    var orden = [];
    (res.data || []).forEach(function (f) {
      var p = porProducto[f.producto_id];
      if (!p) {
        p = porProducto[f.producto_id] = {
          id: f.producto_id,
          marcaId: f.marca_id,
          marca: f.marca,
          marcaGiro: f.marca_giro || "",
          marcaCiudadAlmacen: f.marca_ciudad_almacen || "",
          marcaCiudadPunto: f.marca_ciudad_punto || "",
          nombre: f.producto,
          nombreComprobante: f.nombre_comprobante || "",
          cat: f.categoria || "",
          emoji: f.emoji || "📦",
          desc: f.descripcion || "",
          reco: f.recomendaciones || "",
          prep: f.tiempo_prep || "",
          cobertura: f.cobertura || "",
          corteNac: f.corte_nacional || "",
          corteLoc: f.corte_local || "",
          dias: f.dias_despacho || "",
          variantes: []
        };
        orden.push(p);
      }
      p.variantes.push({
        id: f.id,
        pres: f.presentacion,
        sug: Number(f.precio_publico),     // precio de página; NO hay mayorista
        stockAlmacen: f.stock_almacen === null ? null : Number(f.stock_almacen),
        stockPunto: f.stock_punto === null ? null : Number(f.stock_punto)
      });
    });
    return orden;
  }

  /* Las marcas salen del propio catálogo, no de la tabla 'marcas': los permisos
     no dejan al socio leerla —ahí están el RUC y el historial de cada
     proveedor— y no hace falta, porque la vista ya trae lo que necesita ver. */
  function marcasDelCatalogo(filas) {
    var vistas = {}, orden = [];
    (filas || []).forEach(function (f) {
      if (vistas[f.marcaId]) return;
      vistas[f.marcaId] = true;
      orden.push({
        id: f.marcaId,
        nombre: f.marca,
        giro: f.marcaGiro,
        ciudadAlmacen: f.marcaCiudadAlmacen,
        ciudadPunto: f.marcaCiudadPunto
      });
    });
    return orden;
  }

  /* ------------------------------------------------------------------ */
  /* Registrar la venta                                                  */
  /* ------------------------------------------------------------------ */

  /* Ojo con lo que NO se manda: ningún precio. Los cuatro montos los calcula
     crear_pedido() leyendo el catálogo y el nivel del socio. Si se mandaran
     desde aquí, cualquiera podría editarlos antes de que salgan. */
  async function crearPedido(d) {
    var sb = exigirCliente();
    var res = await sb.rpc("crear_pedido", {
      p_items: d.items,                        // [{presentacion_id, cantidad}]
      p_destinatario: d.destinatario,
      p_doc: d.doc,
      p_celular: d.celular,
      p_origen: d.origen,                      // 'almacen' | 'punto_venta'
      p_modo_entrega: d.modoEntrega,           // 'agencia' | 'domicilio'
      p_detalle_entrega: d.detalleEntrega,
      p_agencia: d.agencia || null,
      p_costo_envio: d.costoEnvio || 0
    });
    if (res.error) throw new Error(explicar(res.error, "No se pudo registrar el pedido"));
    var fila = (res.data || [])[0];
    if (!fila) throw new Error("El pedido no se registró y la base no dijo por qué.");
    return {
      id: fila.pedido_id,
      codigo: fila.codigo,
      pagas: Number(fila.precio_socio),
      ganas: Number(fila.ganancia_socio),
      precioPublico: Number(fila.precio_publico),
      montoATransferir: Number(fila.monto_esperado)
    };
  }

  /* El monto esperado tampoco se manda: se recalcula del lado de la base. */
  async function declararPago(d) {
    var sb = exigirCliente();
    var res = await sb.rpc("declarar_pago", {
      p_pedido_id: d.pedidoId,
      p_numero_operacion: d.numeroOperacion,
      p_monto_reportado: d.montoReportado,
      p_metodo: d.metodo,                      // yape | plin | transferencia | deposito
      p_voucher_url: d.voucherUrl || null,
      p_hash_imagen: d.hashImagen || null
    });
    if (res.error) throw new Error(explicar(res.error, "No se pudo registrar tu pago"));
    var fila = (res.data || [])[0];
    if (!fila) throw new Error("El pago no se registró y la base no dijo por qué.");
    return { id: fila.pago_id, esperado: Number(fila.monto_esperado), cuadra: !!fila.cuadra };
  }

  /* ------------------------------------------------------------------ */
  /* La captura del depósito                                             */
  /* ------------------------------------------------------------------ */
  /*
     Mientras no haya pasarela de pago, esto es la prueba que el socio deja de
     que depositó. Vive en un cubo privado de Supabase Storage: no se sirve por
     URL pública, y para verla hay que pedir un enlace firmado que caduca.

     Lo que se guarda en 'pagos.imagen_voucher_url' NO es una URL sino la ruta
     dentro del cubo. Una URL firmada caduca; la ruta no, así que es lo único
     que sirve para volver a abrir la captura meses después, cuando alguien
     reclame.
  */

  var CUBO_VOUCHERS = "vouchers";
  var PESO_MAXIMO_VOUCHER = 6 * 1024 * 1024;   // una foto de celular cabe de sobra

  /* Huella del archivo. El mismo archivo da siempre la misma, así que dos
     pedidos con la misma captura se detectan aunque cambien el número de
     operación. La base la rechaza; esto solo la calcula.

     crypto.subtle solo existe en páginas seguras (https, o localhost). Si no
     está, se devuelve null: el pago entra igual, sin esa comprobación. */
  async function huellaDe(archivo) {
    if (!raiz.crypto || !raiz.crypto.subtle || !archivo.arrayBuffer) return null;
    try {
      var bytes = await archivo.arrayBuffer();
      var resumen = await raiz.crypto.subtle.digest("SHA-256", bytes);
      return Array.prototype.map.call(new Uint8Array(resumen), function (b) {
        return ("0" + b.toString(16)).slice(-2);
      }).join("");
    } catch (e) {
      return null;
    }
  }

  /* Sube la captura y devuelve { ruta, huella }. La ruta empieza por el id del
     socio porque de eso cuelgan los permisos del cubo: cada quien escribe solo
     dentro de su carpeta. */
  async function subirVoucher(archivo, codigoPedido) {
    var sb = exigirCliente();

    if (!archivo) throw new Error("No elegiste ninguna imagen.");
    if (archivo.size > PESO_MAXIMO_VOUCHER)
      throw new Error("La imagen pesa demasiado (máximo 6 MB). Vuelve a sacarle la captura o reduce su tamaño.");
    if (archivo.type && archivo.type.indexOf("image/") !== 0)
      throw new Error("Eso no es una imagen. Sube la captura o la foto de tu depósito.");

    var s = await sb.auth.getSession();
    if (!s.data || !s.data.session) throw new Error("Tu sesión venció. Vuelve a entrar y reintenta.");

    var ext = (archivo.name || "captura.jpg").split(".").pop().toLowerCase();
    if (!/^[a-z0-9]{2,5}$/.test(ext)) ext = "jpg";

    /* El nombre lleva la hora: un segundo intento tras un rechazo sube un
       archivo nuevo y no pisa la evidencia del anterior. El cubo no tiene
       permiso de update ni de delete justamente para eso. */
    var ruta = s.data.session.user.id + "/" + codigoPedido + "-" + Date.now() + "." + ext;

    var subida = await sb.storage.from(CUBO_VOUCHERS).upload(ruta, archivo, {
      contentType: archivo.type || "image/jpeg",
      upsert: false
    });
    if (subida.error)
      throw new Error(explicar(subida.error, "No se pudo subir tu captura") ||
                      "No se pudo subir tu captura. Revisa tu conexión y reintenta.");

    return { ruta: ruta, huella: await huellaDe(archivo) };
  }

  /* Enlace temporal para mirar una captura ya subida. Vale 10 minutos: lo justo
     para revisarla, no para reenviarlo por WhatsApp y que siga sirviendo. */
  async function enlaceVoucher(ruta) {
    if (!ruta) return null;
    var sb = exigirCliente();
    var r = await sb.storage.from(CUBO_VOUCHERS).createSignedUrl(ruta, 600);
    if (r.error) throw new Error(explicar(r.error, "No se pudo abrir la captura"));
    return r.data && r.data.signedUrl;
  }

  /* El socio desiste de un pedido que registró y no llegó a pagar. Importa que
     exista: el pedido aparta stock desde que se crea, así que uno abandonado
     deja mercadería reservada para nadie. */
  async function cancelarPedidoSinPagar(pedidoId) {
    var sb = exigirCliente();
    var res = await sb.rpc("cancelar_pedido_sin_pagar", { p_pedido_id: pedidoId });
    if (res.error) throw new Error(explicar(res.error, "No se pudo cancelar el pedido"));
    return true;
  }

  async function misPedidos() {
    var sb = exigirCliente();
    var res = await sb.from("pedidos_socio").select("*")
                      .order("creado_en", { ascending: false });
    if (res.error) throw new Error(explicar(res.error, "No se pudieron leer tus pedidos"));
    return res.data || [];
  }

  async function registrarComprobante(d) {
    var sb = exigirCliente();
    var res = await sb.rpc("registrar_comprobante", {
      p_pedido_id: d.pedidoId,
      p_tipo: d.tipo,                          // 'boleta' | 'factura'
      p_serie: d.serie,
      p_numero: d.numero,
      p_url: d.url || null
    });
    if (res.error) throw new Error(explicar(res.error, "No se pudo registrar el comprobante"));
    return true;
  }

  /* ------------------------------------------------------------------ */
  /* Catálogo                                                            */
  /* ------------------------------------------------------------------ */

  /* Devuelve los productos de la marca con sus presentaciones anidadas. */
  async function cargarCatalogo(marcaId) {
    var sb = exigirCliente();
    var res = await sb
      .from("productos")
      .select("id, nombre, nombre_comprobante, categoria, emoji, descripcion, recomendaciones, tiempo_prep, " +
              "cobertura, corte_nacional, corte_local, dias_despacho, estado, activo, creado_en, " +
              "presentaciones ( id, nombre, precio_mayorista, precio_publico, stock_almacen, stock_punto )")
      .eq("marca_id", marcaId)
      .order("creado_en", { ascending: false });
    if (res.error) throw new Error(explicar(res.error, "No se pudo leer tu catálogo"));
    return res.data || [];
  }

  /* Carga masiva.
     Reglas: no borra nada nunca (una presentación ya vendida no se puede
     borrar sin romper el pedido que la referencia), y lo que entra va a
     revisión igual que en el asistente — subir 60 de golpe no puede ser una
     puerta trasera para autopublicarse. */
  async function importarCatalogo(marcaId, productos, avance) {
    var sb = exigirCliente();

    var existentes = await cargarCatalogo(marcaId);
    var porNombre = {};
    existentes.forEach(function (p) { porNombre[p.nombre.toLowerCase()] = p; });

    var cuenta = { productosNuevos: 0, productosActualizados: 0,
                   presentacionesNuevas: 0, presentacionesActualizadas: 0 };
    var hechos = 0;

    for (var i = 0; i < productos.length; i++) {
      var p = productos[i];
      var previo = porNombre[p.nombre.toLowerCase()];
      var productoId;

      if (previo) {
        productoId = previo.id;
        var upd = await sb.from("productos").update({
          categoria: p.categoria,
          descripcion: p.descripcion,
          nombre_comprobante: p.nombre_comprobante
        }).eq("id", productoId);
        if (upd.error) throw new Error(explicar(upd.error, 'Al actualizar "' + p.nombre + '"'));
        cuenta.productosActualizados++;
      } else {
        var ins = await sb.from("productos").insert({
          marca_id: marcaId,
          nombre: p.nombre,
          nombre_comprobante: p.nombre_comprobante,
          categoria: p.categoria,
          descripcion: p.descripcion,
          estado: "revision",
          activo: false
        }).select("id").single();
        if (ins.error) throw new Error(explicar(ins.error, 'Al crear "' + p.nombre + '"'));
        productoId = ins.data.id;
        cuenta.productosNuevos++;
      }

      var previas = {};
      if (previo) (previo.presentaciones || []).forEach(function (v) {
        previas[v.nombre.toLowerCase()] = v;
      });

      var nuevas = [];
      for (var j = 0; j < p.presentaciones.length; j++) {
        var v = p.presentaciones[j];
        var yaEstaba = previas[v.nombre.toLowerCase()];
        var campos = {
          nombre: v.nombre,
          precio_mayorista: v.precio_mayorista,
          precio_publico: v.precio_publico,
          stock_almacen: v.stock_almacen,
          stock_punto: v.stock_punto
        };
        if (yaEstaba) {
          var u = await sb.from("presentaciones").update(campos).eq("id", yaEstaba.id);
          if (u.error) throw new Error(explicar(u.error, 'En "' + p.nombre + " — " + v.nombre + '"'));
          cuenta.presentacionesActualizadas++;
        } else {
          campos.producto_id = productoId;
          nuevas.push(campos);
        }
      }
      if (nuevas.length) {
        var ip = await sb.from("presentaciones").insert(nuevas);
        if (ip.error) throw new Error(explicar(ip.error, 'En las presentaciones de "' + p.nombre + '"'));
        cuenta.presentacionesNuevas += nuevas.length;
      }

      hechos++;
      if (typeof avance === "function") avance(hechos, productos.length, p.nombre);
    }

    return cuenta;
  }

  /* El panel se dibujó contra la forma que tenían los datos en el navegador
     (variantes/pres/may/sug/stockA/stockB). La base usa otros nombres. En vez
     de reescribir todo el dibujado, se traduce aquí. Cada fila conserva su id
     real en _id para poder actualizarla después. */
  function aFormatoPanel(productos) {
    return (productos || []).map(function (p) {
      return {
        _id: p.id,
        nombre: p.nombre,
        nombreComprobante: p.nombre_comprobante || "",
        cat: p.categoria || "",
        emoji: p.emoji || "📦",
        desc: p.descripcion || "",
        reco: p.recomendaciones || "",
        prep: p.tiempo_prep || "—",
        cobertura: p.cobertura || "",
        corteNac: p.corte_nacional || "",
        corteLoc: p.corte_local || "",
        dias: p.dias_despacho || "",
        estado: p.estado,
        activo: !!p.activo,
        kit: { fotos: false, videos: false, textos: false },
        creado: p.creado_en,
        variantes: (p.presentaciones || [])
          .slice()
          .sort(function (a, b) { return Number(a.precio_publico) - Number(b.precio_publico); })
          .map(function (v) {
            return {
              _id: v.id,
              pres: v.nombre,
              may: Number(v.precio_mayorista),
              sug: Number(v.precio_publico),
              stockA: v.stock_almacen == null ? 0 : v.stock_almacen,
              stockB: v.stock_punto == null ? 0 : v.stock_punto
            };
          })
      };
    });
  }

  /* Las horas de corte se eligen en un desplegable que dice "2:00 p. m.",
     porque es como se escribe la hora en español. La base guarda horas de
     verdad y no entiende ese texto: el "p." lo toma por una zona horaria y
     rechaza el producto entero. Aquí se traduce a 24 horas.

     "Sin corte" y "No aplica" no son horas: significan que no hay corte, y
     eso en la base es un vacío. */
  function aHora(v) {
    var s = String(v == null ? "" : v).trim();
    if (!s) return null;

    var suelto = s.toLowerCase().replace(/\./g, "").replace(/\s+/g, " ");
    if (suelto === "sin corte" || suelto === "no aplica" || suelto === "ninguno") return null;

    // "2:00 p m", "11:30 a m", "2 pm", "14:00"
    var m = suelto.match(/^(\d{1,2})(?::(\d{2}))?\s*(a m|p m|am|pm)?$/);
    if (!m) return null;

    var h = parseInt(m[1], 10);
    var min = m[2] ? parseInt(m[2], 10) : 0;
    var suf = m[3] ? m[3].replace(/\s/g, "") : null;

    if (h > 23 || min > 59) return null;
    if (suf === "pm" && h < 12) h += 12;
    if (suf === "am" && h === 12) h = 0;      // 12 de la noche
    if (!suf && h > 23) return null;

    return (h < 10 ? "0" : "") + h + ":" + (min < 10 ? "0" : "") + min + ":00";
  }

  async function crearProducto(marcaId, p) {
    var sb = exigirCliente();
    var ins = await sb.from("productos").insert({
      marca_id: marcaId,
      nombre: p.nombre,
      nombre_comprobante: p.nombreComprobante || null,
      categoria: p.cat || null,
      emoji: p.emoji || "📦",
      descripcion: p.desc || null,
      recomendaciones: p.reco || null,
      tiempo_prep: p.prep || null,
      cobertura: p.cobertura || null,
      corte_nacional: aHora(p.corteNac),
      corte_local: aHora(p.corteLoc),
      dias_despacho: p.dias || null,
      estado: "revision",
      activo: false
    }).select("id").single();
    if (ins.error) throw new Error(explicar(ins.error, "No se pudo crear el producto"));

    var filas = (p.variantes || []).map(function (v) {
      return {
        producto_id: ins.data.id,
        nombre: v.pres,
        precio_mayorista: Number(v.may),
        precio_publico: Number(v.sug),
        stock_almacen: Number(v.stockA) || 0,
        stock_punto: Number(v.stockB) || 0
      };
    });
    if (filas.length) {
      var ip = await sb.from("presentaciones").insert(filas);
      if (ip.error) throw new Error(explicar(ip.error, "No se pudieron guardar las presentaciones"));
    }
    return ins.data.id;
  }

  async function guardarStock(presentacionId, campo, valor) {
    var sb = exigirCliente();
    var cambio = {};
    cambio[campo] = valor;
    var r = await sb.from("presentaciones").update(cambio).eq("id", presentacionId);
    if (r.error) throw new Error(explicar(r.error, "No se pudo guardar el stock"));
  }

  async function alternarActivo(productoId, activo) {
    var sb = exigirCliente();
    var r = await sb.from("productos").update({ activo: activo }).eq("id", productoId);
    if (r.error) throw new Error(explicar(r.error, "No se pudo cambiar la publicación"));
  }

  /* ------------------------------------------------------------------ */
  /* SOCIO · la cola de validación                                       */
  /* ------------------------------------------------------------------ */
  /*
     El administrador no se registra desde la app: su cuenta se crea a mano en
     el tablero de Supabase (Authentication → Users) y su fila se añade a la
     tabla 'administradores' con ese mismo id. Por eso aquí solo hay entrada,
     no alta, y por eso entra con su correo de verdad y no con el celular.

     Si alguien que no es administrador entra igual, no ve nada: la vista
     'cola_de_validacion' solo devuelve filas si es_admin() dice que sí, y
     validar_pago() falla con un mensaje claro. La base decide, no la pantalla.
  */

  async function ingresarAdmin(correo, clave) {
    var sb = exigirCliente();
    var r = await sb.auth.signInWithPassword({
      email: String(correo).trim(),
      password: String(clave)
    });
    if (r.error) throw new Error(explicar(r.error, "No se pudo entrar"));
    var quien = await adminActual();
    if (!quien) {
      await sb.auth.signOut();
      throw new Error("Esa cuenta existe pero no es administradora de SOCIO. " +
                      "Se añade a mano en la tabla 'administradores' de Supabase.");
    }
    return quien;
  }

  async function adminActual() {
    var sb = iniciar();
    if (!sb) return null;
    var s = await sb.auth.getSession();
    if (!s.data || !s.data.session) return null;
    var res = await sb.from("administradores").select("*")
                      .eq("id", s.data.session.user.id).maybeSingle();
    if (res.error) return null;
    return res.data;
  }

  /* Los pagos por resolver primero, y dentro de ellos el que más lleva
     esperando: un socio con el dinero ya depositado no puede ir al final de la
     lista porque su pedido sea más barato. */
  async function colaDeValidacion() {
    var sb = exigirCliente();
    var res = await sb.from("cola_de_validacion").select("*")
                      .order("declarado_en", { ascending: true });
    if (res.error) throw new Error(explicar(res.error, "No se pudo leer la cola de validación"));
    var filas = res.data || [];
    var orden = { pendiente: 0, rechazado: 1, validado: 2 };
    return filas.sort(function (a, b) {
      return (orden[a.pago_estado] - orden[b.pago_estado]) ||
             (new Date(a.declarado_en) - new Date(b.declarado_en));
    });
  }

  /* Validar libera el pedido a la marca. Rechazar devuelve el pedido a
     'pendiente de pago' para que el socio pueda declarar otra vez — el motivo
     es obligatorio porque es lo que él va a leer para saber qué corregir. */
  async function validarPago(pagoId, aprobado, motivo) {
    var sb = exigirCliente();
    var res = await sb.rpc("validar_pago", {
      p_pago_id: pagoId,
      p_validado: !!aprobado,
      p_motivo: motivo || null
    });
    if (res.error) throw new Error(explicar(res.error, "No se pudo resolver el pago"));
    return true;
  }

  /* ------------------------------------------------------------------ */
  /* La marca · despachar y cobrar                                       */
  /* ------------------------------------------------------------------ */
  /*
     El último tramo del recorrido. La marca ve aquí solo lo que SOCIO ya
     validó: un pedido sin pago cruzado no le llega, porque la vista
     'pedidos_marca' le muestra su estado y el panel filtra por él.

     Lo que NO está en esta sección, a propósito: confirmar la entrega. Ese
     paso le suelta a la marca el resto de su dinero, así que lo da el socio
     —o SOCIO— desde confirmarEntrega(), más abajo.
  */

  var CUBO_GUIAS = "guias";
  var PESO_MAXIMO_GUIA = 6 * 1024 * 1024;

  async function pedidosDeMiMarca() {
    var sb = exigirCliente();
    var res = await sb.from("pedidos_marca").select("*")
                      .order("creado_en", { ascending: false });
    if (res.error) throw new Error(explicar(res.error, "No se pudieron leer tus pedidos"));
    return res.data || [];
  }

  /* Qué hay que empacar en cada uno. Vienen todos de golpe y el panel los
     agrupa: son pocos y así no se hace una consulta por pedido. */
  async function itemsDeMisPedidos() {
    var sb = exigirCliente();
    var res = await sb.from("pedido_items_marca").select("*");
    if (res.error) throw new Error(explicar(res.error, "No se pudo leer el detalle de los pedidos"));
    var porPedido = {};
    (res.data || []).forEach(function (i) {
      (porPedido[i.pedido_id] = porPedido[i.pedido_id] || []).push(i);
    });
    return porPedido;
  }

  /* La foto de la guía de remisión. La base no deja despachar sin ella: es la
     evidencia de que el paquete salió. Se acepta también un PDF, porque varias
     agencias entregan la guía así. */
  async function subirGuia(archivo, codigoPedido) {
    var sb = exigirCliente();

    if (!archivo) throw new Error("No elegiste ningún archivo.");
    if (archivo.size > PESO_MAXIMO_GUIA)
      throw new Error("El archivo pesa demasiado (máximo 6 MB). Sácale una foto más liviana.");
    var tipo = archivo.type || "";
    if (tipo && tipo.indexOf("image/") !== 0 && tipo.indexOf("pdf") === -1)
      throw new Error("Sube una foto de la guía de remisión, o el PDF que te dio la agencia.");

    var s = await sb.auth.getSession();
    if (!s.data || !s.data.session) throw new Error("Tu sesión venció. Vuelve a entrar y reintenta.");

    var ext = (archivo.name || "guia.jpg").split(".").pop().toLowerCase();
    if (!/^[a-z0-9]{2,5}$/.test(ext)) ext = "jpg";

    /* La primera carpeta es el id de la marca: es en lo que se apoyan las
       reglas del cubo para que nadie escriba en la carpeta de otra. */
    var ruta = s.data.session.user.id + "/" + codigoPedido + "-" + Date.now() + "." + ext;

    var subida = await sb.storage.from(CUBO_GUIAS).upload(ruta, archivo, {
      contentType: tipo || "image/jpeg",
      upsert: false
    });
    if (subida.error)
      throw new Error(explicar(subida.error, "No se pudo subir la foto de la guía") ||
                      "No se pudo subir la foto de la guía. Revisa tu conexión y reintenta.");

    return ruta;
  }

  async function enlaceGuia(ruta) {
    if (!ruta) return null;
    var sb = exigirCliente();
    var r = await sb.storage.from(CUBO_GUIAS).createSignedUrl(ruta, 600);
    if (r.error) throw new Error(explicar(r.error, "No se pudo abrir la guía"));
    return r.data && r.data.signedUrl;
  }

  /* Despachar es un solo update con las cinco columnas: el estado y su
     evidencia van juntos porque la base los comprueba a la vez. Si falta algo,
     falla entero y el pedido no se mueve. */
  async function despacharPedido(d) {
    var sb = exigirCliente();
    var res = await sb.from("pedidos").update({
      estado: "en_camino",
      numero_guia: String(d.guia || "").trim(),
      courier: d.courier ? String(d.courier).trim() : null,
      tracking: d.tracking ? String(d.tracking).trim() : null,
      guia_url: d.guiaRuta || null
    }).eq("id", d.pedidoId);
    if (res.error) throw new Error(explicar(res.error, "No se pudo registrar el despacho"));
    return true;
  }

  /* El dinero de la marca: lo que los hitos ya le liberaron, menos lo que ya
     pidió retirar. El número lo da la base, no la pantalla. */
  async function saldoDisponible() {
    var sb = exigirCliente();
    var res = await sb.rpc("saldo_disponible");
    if (res.error) throw new Error(explicar(res.error, "No se pudo leer tu saldo"));
    return Number(res.data) || 0;
  }

  async function misLiberaciones() {
    var sb = exigirCliente();
    var res = await sb.from("liberaciones_dinero").select("*")
                      .order("liberado_en", { ascending: false });
    if (res.error) throw new Error(explicar(res.error, "No se pudo leer tu dinero liberado"));
    return res.data || [];
  }

  async function misRetiros() {
    var sb = exigirCliente();
    var res = await sb.from("retiros").select("*")
                      .order("solicitado_en", { ascending: false });
    if (res.error) throw new Error(explicar(res.error, "No se pudieron leer tus retiros"));
    return res.data || [];
  }

  async function solicitarRetiro(monto) {
    var sb = exigirCliente();
    var res = await sb.rpc("solicitar_retiro", { p_monto: Number(monto) });
    if (res.error) throw new Error(explicar(res.error, "No se pudo pedir el retiro"));
    var f = (res.data && res.data[0]) || {};
    return { monto: Number(f.monto) || 0, saldoRestante: Number(f.saldo_restante) || 0 };
  }

  /* ------------------------------------------------------------------ */
  /* El socio · dar el pedido por recibido                               */
  /* ------------------------------------------------------------------ */
  /*
     El paso que cierra el circuito: suelta el resto del pago de la marca, suma
     la venta entregada del socio (que es de donde sale su nivel) y abre su
     saldo para retirar. Lo da quien tiene al cliente al teléfono, no quien
     cobra por el envío.
  */

  async function confirmarEntrega(pedidoId) {
    var sb = exigirCliente();
    var res = await sb.rpc("confirmar_entrega", { p_pedido_id: pedidoId });
    if (res.error) throw new Error(explicar(res.error, "No se pudo confirmar la entrega"));
    return (res.data && res.data[0]) || null;
  }

  /* La revisión trimestral de niveles (docs/09). La lanza SOCIO desde su
     panel; devuelve solo los socios cuyo nivel cambió. */
  async function revisarNivelesTrimestrales() {
    var sb = exigirCliente();
    var res = await sb.rpc("revisar_niveles_trimestrales");
    if (res.error) throw new Error(explicar(res.error, "No se pudo revisar los niveles"));
    return res.data || [];
  }

  raiz.SocioDatos = {
    configurado: configurado,
    iniciar: iniciar,
    errorConfig: function () { return errorConfig; },
    explicar: explicar,
    registrarMarca: registrarMarca,
    ingresarMarca: ingresarMarca,
    marcaActual: marcaActual,
    registrarSocio: registrarSocio,
    ingresarSocio: ingresarSocio,
    socioActual: socioActual,
    cargarCatalogoPublico: cargarCatalogoPublico,
    marcasDelCatalogo: marcasDelCatalogo,
    crearPedido: crearPedido,
    declararPago: declararPago,
    subirVoucher: subirVoucher,
    cancelarPedidoSinPagar: cancelarPedidoSinPagar,
    enlaceVoucher: enlaceVoucher,
    ingresarAdmin: ingresarAdmin,
    adminActual: adminActual,
    colaDeValidacion: colaDeValidacion,
    validarPago: validarPago,
    misPedidos: misPedidos,
    registrarComprobante: registrarComprobante,
    salir: salir,
    cargarCatalogo: cargarCatalogo,
    importarCatalogo: importarCatalogo,
    aFormatoPanel: aFormatoPanel,
    aHora: aHora,
    crearProducto: crearProducto,
    guardarStock: guardarStock,
    alternarActivo: alternarActivo,
    pedidosDeMiMarca: pedidosDeMiMarca,
    itemsDeMisPedidos: itemsDeMisPedidos,
    subirGuia: subirGuia,
    enlaceGuia: enlaceGuia,
    despacharPedido: despacharPedido,
    saldoDisponible: saldoDisponible,
    misLiberaciones: misLiberaciones,
    misRetiros: misRetiros,
    solicitarRetiro: solicitarRetiro,
    confirmarEntrega: confirmarEntrega,
    revisarNivelesTrimestrales: revisarNivelesTrimestrales
  };

})(window);
