import { base } from "./supabase";
import type { Marca, Producto, Variante } from "../tipos";

/* Una fila de la vista `catalogo_publico`: llega una por PRESENTACIÓN, con los
   datos del producto y de la marca repetidos. Fíjate en lo que no está: no hay
   precio mayorista ni costo del proveedor. La vista no tiene esas columnas, así
   que el dato no existe de este lado ni manipulando el código. */
interface FilaCatalogo {
  id: string;
  producto_id: string;
  producto: string;
  marca_id: string;
  marca: string;
  marca_giro: string | null;
  marca_ciudad_almacen: string | null;
  marca_ciudad_punto: string | null;
  categoria: string | null;
  emoji: string | null;
  descripcion: string | null;
  recomendaciones: string | null;
  tiempo_prep: string | null;
  presentacion: string;
  precio_publico: string | number;
  stock_almacen: string | number | null;
  stock_punto: string | number | null;
}

function numeroONulo(v: string | number | null): number | null {
  return v === null || v === undefined ? null : Number(v);
}

/** Lee el catálogo y lo agrupa: una entrada por producto, con sus variantes. */
export async function cargarCatalogo(): Promise<Producto[]> {
  const respuesta = await base()
    .from("catalogo_publico")
    .select("*")
    .order("producto", { ascending: true });

  if (respuesta.error) {
    throw new Error("No se pudo leer el catálogo: " + respuesta.error.message);
  }

  const filas = (respuesta.data ?? []) as FilaCatalogo[];
  const porProducto = new Map<string, Producto>();

  for (const f of filas) {
    let p = porProducto.get(f.producto_id);
    if (!p) {
      p = {
        id: f.producto_id,
        marcaId: f.marca_id,
        marca: f.marca,
        marcaGiro: f.marca_giro ?? "",
        marcaCiudadAlmacen: f.marca_ciudad_almacen ?? "",
        marcaCiudadPunto: f.marca_ciudad_punto ?? "",
        nombre: f.producto,
        categoria: f.categoria ?? "Sin categoría",
        emoji: f.emoji ?? "📦",
        descripcion: f.descripcion ?? "",
        recomendaciones: f.recomendaciones ?? "",
        tiempoPreparacion: f.tiempo_prep ?? "",
        variantes: [],
      };
      porProducto.set(f.producto_id, p);
    }
    const v: Variante = {
      id: f.id,
      presentacion: f.presentacion,
      precioPagina: Number(f.precio_publico),
      stockAlmacen: numeroONulo(f.stock_almacen),
      stockPunto: numeroONulo(f.stock_punto),
    };
    p.variantes.push(v);
  }

  return [...porProducto.values()];
}

/* Las marcas salen del propio catálogo, no de la tabla `marcas`: los permisos
   no dejan al socio leerla —ahí están el RUC y el historial de cada
   proveedor— y tampoco hace falta. */
export function marcasDelCatalogo(productos: readonly Producto[]): Marca[] {
  const vistas = new Map<string, Marca>();
  for (const p of productos) {
    if (vistas.has(p.marcaId)) continue;
    vistas.set(p.marcaId, {
      id: p.marcaId,
      nombre: p.marca,
      giro: p.marcaGiro || "Varios",
      ciudadAlmacen: p.marcaCiudadAlmacen,
      ciudadPunto: p.marcaCiudadPunto,
    });
  }
  return [...vistas.values()];
}

export function categoriasDe(productos: readonly Producto[]): string[] {
  const vistas = new Set<string>();
  for (const p of productos) if (p.categoria) vistas.add(p.categoria);
  return [...vistas];
}
