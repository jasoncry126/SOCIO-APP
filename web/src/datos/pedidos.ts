import { base } from "./supabase";
import type { DatosEnvio, EstadoPago, EstadoPedido, ItemPedido, Pedido } from "../tipos";

/* ===========================================================================
   Los pedidos del socio: leerlos, crearlos y pagarlos.

   El orden importa y no es una preferencia de pantalla. El monto a depositar
   lleva unos céntimos que identifican ese pedido y ningún otro en el extracto
   del día, y esos céntimos se derivan del CÓDIGO del pedido. El código no
   existe hasta que el pedido está en la base. Por eso: primero se registra el
   pedido, después se cobra.
   =========================================================================== */

interface FilaPedido {
  id: string;
  codigo: string;
  estado: string;
  destinatario: string;
  detalle_entrega: string | null;
  creado_en: string;
  numero_guia: string | null;
  precio_publico: string | number | null;
  ganancia_socio: string | number | null;
  monto_a_pagar: string | number | null;
  pago_estado: string | null;
  pago_captura: string | null;
  pago_motivo: string | null;
}

const ESTADOS: readonly EstadoPedido[] = [
  "pendiente_pago",
  "pagado",
  "validado",
  "en_camino",
  "entregado",
  "cancelado",
] as const;

const ESTADOS_PAGO: readonly EstadoPago[] = ["declarado", "validado", "rechazado"] as const;

/* Si la base devolviera un estado que esta pantalla no conoce —porque se
   añadió uno después—, se trata como pendiente de pago en vez de romper la
   lista entera. */
function comoEstado(v: string): EstadoPedido {
  return (ESTADOS as readonly string[]).includes(v) ? (v as EstadoPedido) : "pendiente_pago";
}

function comoEstadoPago(v: string | null): EstadoPago | null {
  if (!v) return null;
  return (ESTADOS_PAGO as readonly string[]).includes(v) ? (v as EstadoPago) : null;
}

function comoPedido(f: FilaPedido): Pedido {
  return {
    id: f.id,
    codigo: f.codigo,
    estado: comoEstado(f.estado),
    destinatario: f.destinatario,
    detalleEntrega: f.detalle_entrega ?? "",
    fecha: new Date(f.creado_en).toLocaleDateString("es-PE", { day: "2-digit", month: "short" }),
    numeroGuia: f.numero_guia ?? "",
    total: Number(f.precio_publico ?? 0),
    ganancia: Number(f.ganancia_socio ?? 0),
    montoADepositar: Number(f.monto_a_pagar ?? 0),
    pagoEstado: comoEstadoPago(f.pago_estado),
    pagoCaptura: f.pago_captura ?? "",
    pagoMotivo: f.pago_motivo ?? "",
  };
}

export async function cargarPedidos(): Promise<Pedido[]> {
  const respuesta = await base()
    .from("pedidos_socio")
    .select("*")
    .order("creado_en", { ascending: false });

  if (respuesta.error) {
    throw new Error("No se pudieron leer tus pedidos: " + respuesta.error.message);
  }
  return ((respuesta.data ?? []) as FilaPedido[]).map(comoPedido);
}

/* ---------------------------------------------------------------------------
   Registrar el pedido
   ---------------------------------------------------------------------------
   Ojo con lo que NO se manda: ningún precio. Los montos los calcula
   crear_pedido() leyendo el catálogo y el nivel del socio. Si viajaran desde
   el navegador, cualquiera podría editarlos antes de que salieran. */

export interface PedidoCreado {
  id: string;
  codigo: string;
  montoADepositar: number;
}

interface FilaCreado {
  pedido_id: string;
  codigo: string;
  monto_a_transferir?: string | number | null;
  monto_esperado?: string | number | null;
  precio_socio?: string | number | null;
}

export async function crearPedido(
  items: readonly ItemPedido[],
  envio: DatosEnvio,
  origen: "almacen" | "punto_venta",
  costoEnvio: number,
): Promise<PedidoCreado> {
  const detalle =
    envio.modo === "agencia"
      ? `${envio.agencia} · ${envio.detalle}`
      : envio.detalle + (envio.referencia ? ` (Ref: ${envio.referencia})` : "");

  const res = await base().rpc("crear_pedido", {
    p_items: items,
    p_destinatario: envio.destinatario,
    p_doc: envio.documento,
    p_celular: envio.celular,
    p_origen: origen,
    p_modo_entrega: envio.modo,
    p_detalle_entrega: detalle,
    p_agencia: envio.modo === "agencia" ? envio.agencia : null,
    p_costo_envio: costoEnvio,
  });

  if (res.error) throw new Error("No se pudo registrar tu pedido: " + res.error.message);
  const fila = ((res.data ?? []) as FilaCreado[])[0];
  if (!fila) throw new Error("El pedido no se registró y la base no dijo por qué.");

  return {
    id: fila.pedido_id,
    codigo: fila.codigo,
    montoADepositar: Number(fila.monto_a_transferir ?? fila.monto_esperado ?? 0),
  };
}

/* ---------------------------------------------------------------------------
   La captura del depósito
   ---------------------------------------------------------------------------
   Vive en un cubo privado de Supabase Storage. La ruta empieza por el id del
   socio porque de eso cuelgan los permisos: cada quien escribe y lee solo
   dentro de su carpeta, y SOCIO las ve todas para cruzarlas contra el
   extracto. Nadie puede borrar ni reemplazar una captura ya subida.

   Esto sigue el contrato de la migración del cobro por captura de depósito. */

const CUBO = "vouchers";
const PESO_MAXIMO = 6 * 1024 * 1024; // una foto de celular cabe de sobra

/* Huella del archivo: el mismo archivo da siempre la misma, así que dos
   pedidos con la misma captura se detectan aunque cambie el número de
   operación. La base la rechaza; aquí solo se calcula.

   crypto.subtle solo existe en páginas seguras (https o localhost). Si no
   está, se devuelve null y el pago entra igual, sin esa comprobación. */
async function huellaDe(archivo: File): Promise<string | null> {
  if (!globalThis.crypto?.subtle) return null;
  try {
    const bytes = await archivo.arrayBuffer();
    const resumen = await globalThis.crypto.subtle.digest("SHA-256", bytes);
    return [...new Uint8Array(resumen)].map((b) => b.toString(16).padStart(2, "0")).join("");
  } catch {
    return null;
  }
}

export interface CapturaSubida {
  ruta: string;
  huella: string | null;
}

export async function subirCaptura(archivo: File, codigoPedido: string): Promise<CapturaSubida> {
  const sb = base();

  if (archivo.size > PESO_MAXIMO) {
    throw new Error(
      "La imagen pesa demasiado (máximo 6 MB). Vuelve a sacarle la captura o redúcela.",
    );
  }
  if (archivo.type && !archivo.type.startsWith("image/")) {
    throw new Error("Eso no es una imagen. Sube la captura o la foto de tu depósito.");
  }

  const sesion = await sb.auth.getSession();
  const usuario = sesion.data.session?.user;
  if (!usuario) throw new Error("Tu sesión venció. Vuelve a entrar y reintenta.");

  let ext = (archivo.name || "captura.jpg").split(".").pop()?.toLowerCase() ?? "jpg";
  if (!/^[a-z0-9]{2,5}$/.test(ext)) ext = "jpg";

  /* El nombre lleva la hora: un segundo intento tras un rechazo sube un
     archivo nuevo y no pisa la evidencia del anterior. El cubo no tiene
     permiso de update ni de delete justamente para eso. */
  const ruta = `${usuario.id}/${codigoPedido}-${Date.now()}.${ext}`;

  const subida = await sb.storage.from(CUBO).upload(ruta, archivo, {
    contentType: archivo.type || "image/jpeg",
    upsert: false,
  });
  if (subida.error) {
    throw new Error("No se pudo subir tu captura: " + subida.error.message);
  }

  return { ruta, huella: await huellaDe(archivo) };
}

/* Enlace temporal para volver a mirar una captura ya subida. Vale diez
   minutos: lo justo para revisarla, no para reenviarlo y que siga sirviendo. */
export async function enlaceCaptura(ruta: string): Promise<string | null> {
  if (!ruta) return null;
  const r = await base().storage.from(CUBO).createSignedUrl(ruta, 600);
  if (r.error) throw new Error("No se pudo abrir la captura: " + r.error.message);
  return r.data.signedUrl;
}

/* ---------------------------------------------------------------------------
   Declarar el pago
   --------------------------------------------------------------------------- */

export type MetodoPago = "yape" | "plin" | "transferencia" | "deposito";

export interface PagoDeclarado {
  id: string;
  esperado: number;
  cuadra: boolean;
}

interface FilaPago {
  pago_id: string;
  monto_esperado: string | number;
  cuadra: boolean;
}

export async function declararPago(d: {
  pedidoId: string;
  numeroOperacion: string;
  montoReportado: number;
  metodo: MetodoPago;
  capturaRuta: string;
  huella: string | null;
}): Promise<PagoDeclarado> {
  const res = await base().rpc("declarar_pago", {
    p_pedido_id: d.pedidoId,
    p_numero_operacion: d.numeroOperacion,
    p_monto_reportado: d.montoReportado,
    p_metodo: d.metodo,
    p_voucher_url: d.capturaRuta,
    p_hash_imagen: d.huella,
  });

  if (res.error) throw new Error("No se pudo registrar tu pago: " + res.error.message);
  const fila = ((res.data ?? []) as FilaPago[])[0];
  if (!fila) throw new Error("El pago no se registró y la base no dijo por qué.");

  return { id: fila.pago_id, esperado: Number(fila.monto_esperado), cuadra: Boolean(fila.cuadra) };
}

/** El socio desiste de un pedido que registró y no llegó a pagar. Importa
    porque un pedido registrado ya aparta stock: cancelarlo lo devuelve. */
export async function cancelarPedidoSinPagar(pedidoId: string): Promise<void> {
  const res = await base().rpc("cancelar_pedido_sin_pagar", { p_pedido_id: pedidoId });
  if (res.error) throw new Error("No se pudo cancelar el pedido: " + res.error.message);
}
