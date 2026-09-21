import type { ModoEntrega, Producto, Variante } from "./tipos";

/* ===========================================================================
   De dónde sale el pedido y cuánto cuesta mandarlo.

   Los ORÍGENES salen de la propia marca, no de una lista fija. La app de hoy
   tiene "Cusco" y "Lima" escritos a mano y compartidos por toda la plataforma,
   que es justo lo que CLAUDE.md pide generalizar antes de cargar una segunda
   marca. Aquí cada marca trae sus dos ciudades en el catálogo, así que una
   marca de otro rubro que despache desde Arequipa funciona sin tocar código.
   =========================================================================== */

export type OrigenId = "almacen" | "punto_venta";

export interface Origen {
  id: OrigenId;
  nombre: string;
  ciudad: string;
  plazo: string;
  /** Formas de entrega que admite este origen. */
  modos: readonly ModoEntrega[];
}

export function origenesDe(producto: Producto): Origen[] {
  const lista: Origen[] = [];
  if (producto.marcaCiudadAlmacen) {
    lista.push({
      id: "almacen",
      nombre: "Almacén " + producto.marcaCiudadAlmacen,
      ciudad: producto.marcaCiudadAlmacen,
      plazo: "2 a 5 días según agencia",
      modos: ["agencia"],
    });
  }
  if (producto.marcaCiudadPunto) {
    lista.push({
      id: "punto_venta",
      nombre: "Punto de venta " + producto.marcaCiudadPunto,
      ciudad: producto.marcaCiudadPunto,
      plazo: "24 a 48 horas en la ciudad",
      modos: ["domicilio", "agencia"],
    });
  }
  return lista;
}

export function stockEn(v: Variante, origen: OrigenId): number | null {
  return origen === "almacen" ? v.stockAlmacen : v.stockPunto;
}

/* Las agencias y sus tarifas, tal como las aplica la app de hoy. Son de Lab
   Péptidos, la marca piloto: cuando haya una segunda marca esto tendrá que
   vivir en la base, igual que los orígenes. */
export interface Agencia {
  id: string;
  nombre: string;
  nota: string;
  /** false = el recojo lo paga el cliente, no el socio. */
  lasPagaElSocio: boolean;
  lima: number;
  provincia: number;
}

export const AGENCIAS: readonly Agencia[] = [
  {
    id: "olva",
    nombre: "Olva Courier",
    nota: "Vía aérea · lo pagas tú",
    lasPagaElSocio: true,
    lima: 18,
    provincia: 25,
  },
  {
    id: "shalom",
    nombre: "Shalom",
    nota: "El recojo lo paga el cliente",
    lasPagaElSocio: false,
    lima: 0,
    provincia: 0,
  },
] as const;

/** Entrega a domicilio dentro de la ciudad del punto de venta. Este número
    está por confirmar con datos reales de reparto. */
export const ENTREGA_LOCAL = 15;

export function costoDeEnvio(
  modo: ModoEntrega,
  agenciaId: string,
  esLima: boolean,
): number {
  if (modo === "domicilio") return ENTREGA_LOCAL;
  const a = AGENCIAS.find((x) => x.id === agenciaId);
  if (!a || !a.lasPagaElSocio) return 0;
  return esLima ? a.lima : a.provincia;
}
