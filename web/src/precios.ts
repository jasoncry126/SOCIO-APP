import type { Nivel, NivelId, Variante } from "./tipos";

/* Los cuatro niveles, con la misma comisión que aplica la app de hoy.
   El nivel NO se calcula aquí: lo decide la base cuando un pedido pasa a
   entregado (regla 5 de CLAUDE.md). Esta tabla solo traduce el id que llega
   de la base a lo que se enseña en pantalla. */
export const NIVELES: readonly Nivel[] = [
  { id: "bronce", nombre: "Socio Bronce", medalla: "🥉", comision: 0.1, meta: 0, requisito: "Al crear tu cuenta" },
  { id: "plata", nombre: "Socio Plata", medalla: "🥈", comision: 0.13, meta: 10, requisito: "10 ventas entregadas" },
  { id: "oro", nombre: "Socio Oro", medalla: "🥇", comision: 0.16, meta: 25, requisito: "25 ventas entregadas" },
  { id: "diamante", nombre: "Socio Diamante", medalla: "💎", comision: 0.2, meta: 50, requisito: "50 ventas + 3 meses activo" },
] as const;

const PREDETERMINADO: Nivel = NIVELES[0] as Nivel;

export function nivelPorId(id: string | null | undefined): Nivel {
  return NIVELES.find((n) => n.id === id) ?? PREDETERMINADO;
}

export function esNivelId(v: string): v is NivelId {
  return NIVELES.some((n) => n.id === v);
}

/* Lo que el socio le paga a SOCIO por una presentación: el precio de página
   menos su comisión. Es el mismo cálculo que hace la app de hoy.

   Este número es REFERENCIAL, para que el socio decida si le conviene la
   venta. El definitivo lo calcula crear_pedido() en la base leyendo el
   catálogo y el nivel del socio: si el precio viajara desde el teléfono,
   cualquiera podría editarlo antes de que saliera. */
export function precioSocio(v: Variante, nivel: Nivel): number {
  return Math.round(v.precioPagina * (1 - nivel.comision) * 100) / 100;
}

/** Lo que el socio se queda por unidad si vende al precio de página. */
export function gananciaUnitaria(v: Variante, nivel: Nivel): number {
  return Math.round((v.precioPagina - precioSocio(v, nivel)) * 100) / 100;
}

export function soles(n: number): string {
  return "S/ " + n.toFixed(2);
}
