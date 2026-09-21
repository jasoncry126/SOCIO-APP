import { useCallback, useMemo, useState } from "react";
import type { ItemPedido, LineaCarrito, Nivel, Producto, Variante } from "./tipos";
import { precioSocio } from "./precios";
import { stockEn, type OrigenId } from "./envios";

/* ===========================================================================
   El carrito.

   Una regla que no es capricho: todo el pedido es de UNA marca y sale de UN
   origen. La base crea un pedido por marca y le aparta stock a un almacén
   concreto, así que mezclar dos marcas en el mismo carrito no tendría a dónde
   ir. Cuando el socio agrega algo de otra marca, se le avisa en vez de
   aceptarlo en silencio y fallar al registrar.
   =========================================================================== */

export interface EstadoCarrito {
  lineas: readonly LineaCarrito[];
  marcaId: string | null;
  origen: OrigenId;
  unidades: number;
  /** Lo que el socio le transfiere a SOCIO por la mercadería, sin envío. */
  aPagar: number;
  /** Lo que el socio le cobra a su cliente si vende al precio de página. */
  aCobrar: number;
  ganancia: number;
}

export interface Carrito extends EstadoCarrito {
  agregar: (producto: Producto, variante: Variante, cuantas: number) => string | null;
  cambiar: (varianteId: string, cantidad: number) => void;
  quitar: (varianteId: string) => void;
  vaciar: () => void;
  elegirOrigen: (origen: OrigenId) => void;
  paraLaBase: () => ItemPedido[];
}

export function useCarrito(nivel: Nivel): Carrito {
  const [lineas, setLineas] = useState<readonly LineaCarrito[]>([]);
  const [origen, setOrigen] = useState<OrigenId>("almacen");

  const marcaId = lineas[0]?.producto.marcaId ?? null;

  const agregar = useCallback(
    (producto: Producto, variante: Variante, cuantas: number): string | null => {
      if (marcaId && producto.marcaId !== marcaId) {
        return "Tu pedido ya tiene productos de otra marca. Termínalo o vacíalo para empezar otro.";
      }
      const hay = stockEn(variante, origen);
      const yaTiene = lineas.find((l) => l.variante.id === variante.id)?.cantidad ?? 0;
      if (hay !== null && yaTiene + cuantas > hay) {
        return hay === 0
          ? "No queda stock de esa presentación en el origen que elegiste."
          : `Solo quedan ${hay} de esa presentación en el origen que elegiste.`;
      }
      setLineas((antes) => {
        const i = antes.findIndex((l) => l.variante.id === variante.id);
        if (i < 0) return [...antes, { producto, variante, cantidad: cuantas }];
        return antes.map((l, j) => (j === i ? { ...l, cantidad: l.cantidad + cuantas } : l));
      });
      return null;
    },
    [lineas, marcaId, origen],
  );

  const cambiar = useCallback((varianteId: string, cantidad: number) => {
    setLineas((antes) =>
      cantidad <= 0
        ? antes.filter((l) => l.variante.id !== varianteId)
        : antes.map((l) => (l.variante.id === varianteId ? { ...l, cantidad } : l)),
    );
  }, []);

  const quitar = useCallback((varianteId: string) => {
    setLineas((antes) => antes.filter((l) => l.variante.id !== varianteId));
  }, []);

  const vaciar = useCallback(() => setLineas([]), []);

  /* Cambiar de origen con el carrito lleno movería el stock bajo los pies del
     socio, así que solo se permite con el carrito vacío. */
  const elegirOrigen = useCallback(
    (nuevo: OrigenId) => {
      if (lineas.length > 0) return;
      setOrigen(nuevo);
    },
    [lineas.length],
  );

  const totales = useMemo(() => {
    let aPagar = 0;
    let aCobrar = 0;
    let unidades = 0;
    for (const l of lineas) {
      aPagar += precioSocio(l.variante, nivel) * l.cantidad;
      aCobrar += l.variante.precioPagina * l.cantidad;
      unidades += l.cantidad;
    }
    return {
      unidades,
      aPagar: Math.round(aPagar * 100) / 100,
      aCobrar: Math.round(aCobrar * 100) / 100,
      ganancia: Math.round((aCobrar - aPagar) * 100) / 100,
    };
  }, [lineas, nivel]);

  /* Lo que viaja a la base: qué presentación y cuántas. Ningún precio. */
  const paraLaBase = useCallback(
    (): ItemPedido[] =>
      lineas.map((l) => ({ presentacion_id: l.variante.id, cantidad: l.cantidad })),
    [lineas],
  );

  return {
    lineas,
    marcaId,
    origen,
    ...totales,
    agregar,
    cambiar,
    quitar,
    vaciar,
    elegirOrigen,
    paraLaBase,
  };
}
