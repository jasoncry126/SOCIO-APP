import { motion, type Variants } from "framer-motion";
import { Package, ShoppingBag } from "lucide-react";
import type { Nivel, Producto, Variante } from "../tipos";
import { gananciaUnitaria, precioSocio, soles } from "../precios";

/* La cuadrícula aparece de una, y las tarjetas entran una detrás de otra. */
const contenedor: Variants = {
  oculto: { opacity: 0 },
  visible: { opacity: 1, transition: { when: "beforeChildren" } },
};

/* Cada tarjeta recibe su posición por `custom` y se calcula su retraso a
   partir de ahí, en vez de usar staggerChildren. El motivo es práctico: el
   catálogo de una marca puede tener 47 productos, y 47 × 0,08 s son casi
   cuatro segundos hasta que termina de aparecer el último. Cortando el
   retraso en el séptimo se conserva el mismo ritmo de entrada sin que la
   lista tarde en asentarse. */
const tarjeta: Variants = {
  oculto: { opacity: 0, y: 20 },
  visible: (posicion: number) => ({
    opacity: 1,
    y: 0,
    transition: { duration: 0.4, ease: "easeOut", delay: Math.min(posicion, 6) * 0.08 },
  }),
};

function stockTotal(v: Variante): number | null {
  if (v.stockAlmacen === null && v.stockPunto === null) return null;
  return (v.stockAlmacen ?? 0) + (v.stockPunto ?? 0);
}

interface Props {
  productos: readonly Producto[];
  nivel: Nivel;
  alElegir: (producto: Producto) => void;
}

export function CatalogoProductos({ productos, nivel, alElegir }: Props) {
  if (productos.length === 0) {
    return (
      <div className="mx-auto max-w-6xl rounded-2xl border border-dashed border-linea p-10 text-center">
        <ShoppingBag className="mx-auto h-8 w-8 text-tinta-suave" />
        <h3 className="mt-3 font-titulo text-base font-bold text-tinta">
          Esta marca todavía no tiene productos aprobados
        </h3>
        <p className="mt-1 text-sm text-tinta-suave">
          Cuando la marca publique su catálogo, aparecerá aquí con sus precios.
        </p>
      </div>
    );
  }

  return (
    <motion.div
      variants={contenedor}
      initial="oculto"
      animate="visible"
      /* Dos columnas ya en el teléfono: el diseño de referencia traía una
         sola, pero el catálogo de una marca puede tener 47 productos y eso
         sería un producto por pantalla. Para volver a una columna basta con
         cambiar grid-cols-2 por grid-cols-1. */
      className="mx-auto grid max-w-6xl grid-cols-2 gap-4 p-4 sm:gap-6 lg:grid-cols-3"
    >
      {productos.map((prod, posicion) => {
        const v = prod.variantes[0];
        if (!v) return null;
        const socio = precioSocio(v, nivel);
        const ganancia = gananciaUnitaria(v, nivel);
        const stock = stockTotal(v);
        const agotado = stock === 0;

        return (
          <motion.button
            key={prod.id}
            type="button"
            custom={posicion}
            variants={tarjeta}
            whileHover={{ y: -4, transition: { duration: 0.2 } }}
            whileTap={{ scale: 0.98 }}
            onClick={() => alElegir(prod)}
            className="flex flex-col justify-between rounded-2xl border border-linea bg-tarjeta p-4 text-left shadow-sm transition-shadow hover:shadow-md focus:outline-2 focus:outline-offset-2 focus:outline-sol"
          >
            <div className="mb-4 aspect-square overflow-hidden rounded-xl bg-fondo">
              <motion.div
                whileHover={{ scale: 1.05 }}
                transition={{ duration: 0.3 }}
                className="flex h-full w-full items-center justify-center text-5xl sm:text-7xl"
                aria-hidden="true"
              >
                {prod.emoji}
              </motion.div>
            </div>

            <div>
              <span className="text-xs font-bold tracking-wider text-sol-osc uppercase">
                {prod.marca}
              </span>
              <h3 className="mt-1 line-clamp-2 font-titulo text-sm font-bold text-tinta sm:text-base">
                {prod.nombre}
              </h3>
              <p className="mt-1 text-xs text-tinta-suave">
                {prod.categoria}
                {prod.variantes.length > 1 ? ` · ${prod.variantes.length} presentaciones` : ""}
              </p>

              {/* Lo que el socio necesita para decidir: lo que paga, a cuánto
                  lo vende y lo que se queda. El precio mayorista de la marca
                  NO aparece —regla 1 de CLAUDE.md— y de hecho no llega hasta
                  aquí: la vista de la base no tiene esa columna. */}
              <div className="mt-3 flex flex-col gap-1 border-t border-linea pt-3 sm:flex-row sm:items-baseline sm:justify-between sm:gap-2">
                <div>
                  <span className="block text-xs text-tinta-suave">Precio socio</span>
                  <span className="num font-titulo text-lg font-bold text-tinta">
                    {soles(socio)}
                  </span>
                </div>
                <div className="sm:text-right">
                  <span className="block text-xs text-tinta-suave">Precio de página</span>
                  <span className="num text-sm font-semibold text-tinta-suave">
                    {soles(v.precioPagina)}
                  </span>
                </div>
              </div>

              <div className="mt-3 flex flex-wrap items-center gap-2">
                <span className="num rounded-full bg-chicha-bg px-2.5 py-1 text-xs font-bold text-chicha">
                  Ganas {soles(ganancia)}/u
                </span>
                {stock === null ? (
                  <span className="rounded-full bg-fondo px-2.5 py-1 text-xs font-semibold text-tinta-suave">
                    <Package className="mr-1 inline h-3 w-3" aria-hidden="true" />
                    Disponible
                  </span>
                ) : (
                  <span
                    className={
                      "num rounded-full px-2.5 py-1 text-xs font-semibold " +
                      (agotado
                        ? "bg-alerta-bg text-alerta"
                        : stock <= 10
                          ? "bg-alerta-bg text-alerta"
                          : "bg-fondo text-tinta-suave")
                    }
                  >
                    {agotado ? "Sin stock" : `${stock} en stock`}
                  </span>
                )}
              </div>
            </div>
          </motion.button>
        );
      })}
    </motion.div>
  );
}
