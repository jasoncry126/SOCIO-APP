import { base } from "./supabase";
import type { EstadoPedido, Pedido } from "../tipos";

/* Una fila de la vista `pedidos_socio`. Trae lo que el socio paga y lo que
   gana, pero no el precio mayorista ni la comisión de SOCIO. */
interface FilaPedido {
  codigo: string;
  estado: string;
  destinatario: string;
  detalle_entrega: string | null;
  creado_en: string;
  numero_guia: string | null;
  precio_publico: string | number | null;
  ganancia_socio: string | number | null;
}

const ESTADOS: readonly EstadoPedido[] = [
  "pendiente_pago",
  "pagado",
  "validado",
  "en_camino",
  "entregado",
  "cancelado",
] as const;

/* Si la base devolviera un estado que esta pantalla no conoce —porque se añadió
   uno después—, se trata como pendiente de pago en vez de romper la lista. */
function comoEstado(v: string): EstadoPedido {
  return (ESTADOS as readonly string[]).includes(v) ? (v as EstadoPedido) : "pendiente_pago";
}

export async function cargarPedidos(): Promise<Pedido[]> {
  const respuesta = await base()
    .from("pedidos_socio")
    .select("*")
    .order("creado_en", { ascending: false });

  if (respuesta.error) {
    throw new Error("No se pudieron leer tus pedidos: " + respuesta.error.message);
  }

  return ((respuesta.data ?? []) as FilaPedido[]).map((f) => ({
    codigo: f.codigo,
    estado: comoEstado(f.estado),
    destinatario: f.destinatario,
    detalleEntrega: f.detalle_entrega ?? "",
    fecha: new Date(f.creado_en).toLocaleDateString("es-PE", { day: "2-digit", month: "short" }),
    numeroGuia: f.numero_guia ?? "",
    total: Number(f.precio_publico ?? 0),
    ganancia: Number(f.ganancia_socio ?? 0),
  }));
}
