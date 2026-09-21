import { useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { ArrowLeft, Building2, Clock, Lightbulb, Store } from "lucide-react";
import type { Nivel, Producto } from "../tipos";
import { gananciaUnitaria, precioSocio, soles } from "../precios";

interface Props {
  producto: Producto;
  nivel: Nivel;
  alVolver: () => void;
}

export function DetalleProducto({ producto, nivel, alVolver }: Props) {
  const [elegida, setElegida] = useState(0);
  const v = producto.variantes[elegida] ?? producto.variantes[0];

  /* Un producto sin presentaciones no se puede vender: la ficha lo dice en vez
     de pintar precios de la nada. En la práctica no pasa —la vista solo trae
     presentaciones publicadas— pero el tipo lo admite y hay que resolverlo. */
  if (!v) {
    return (
      <div className="mx-auto max-w-2xl p-4">
        <button
          type="button"
          onClick={alVolver}
          className="mb-4 flex items-center gap-2 text-sm font-bold text-tinta-suave"
        >
          <ArrowLeft className="h-4 w-4" /> Volver al catálogo
        </button>
        <p className="rounded-2xl border border-dashed border-linea p-8 text-center text-sm text-tinta-suave">
          {producto.nombre} todavía no tiene presentaciones con precio publicado.
        </p>
      </div>
    );
  }

  const socio = precioSocio(v, nivel);
  const ganancia = gananciaUnitaria(v, nivel);

  return (
    <motion.div
      initial={{ opacity: 0, x: 22 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.26, ease: "easeOut" }}
      className="mx-auto max-w-2xl p-4"
    >
      <button
        type="button"
        onClick={alVolver}
        className="mb-4 flex items-center gap-2 text-sm font-bold text-tinta-suave transition-colors hover:text-tinta"
      >
        <ArrowLeft className="h-4 w-4" aria-hidden="true" /> Volver al catálogo
      </button>

      <div className="overflow-hidden rounded-2xl border border-linea bg-tarjeta shadow-sm">
        <div className="flex aspect-[16/9] items-center justify-center bg-fondo text-7xl" aria-hidden="true">
          {producto.emoji}
        </div>

        <div className="p-5">
          <span className="text-xs font-bold tracking-wider text-sol-osc uppercase">
            {producto.marca}
          </span>
          <h2 className="mt-1 font-titulo text-xl font-bold text-tinta">{producto.nombre}</h2>
          <p className="mt-1 text-sm text-tinta-suave">{producto.categoria}</p>

          {producto.descripcion ? (
            <p className="mt-4 text-sm leading-relaxed text-tinta-suave">{producto.descripcion}</p>
          ) : null}

          {producto.variantes.length > 1 ? (
            <div className="mt-5">
              <h3 className="text-xs font-bold tracking-wider text-tinta-suave uppercase">
                Elige la presentación
              </h3>
              <div className="mt-2 flex flex-wrap gap-2">
                {producto.variantes.map((opcion, i) => {
                  const activa = i === elegida;
                  return (
                    <motion.button
                      key={opcion.id}
                      type="button"
                      whileHover={{ y: -2 }}
                      whileTap={{ scale: 0.96 }}
                      onClick={() => setElegida(i)}
                      aria-pressed={activa}
                      className={
                        "rounded-xl border-2 px-3 py-2 text-left text-sm font-bold transition-colors " +
                        (activa
                          ? "border-sol bg-sol-bg text-tinta"
                          : "border-linea bg-tarjeta text-tinta-suave hover:border-sol-osc")
                      }
                    >
                      {opcion.presentacion}
                      <span className="num block text-xs font-semibold text-tinta-suave">
                        {soles(opcion.precioPagina)}
                      </span>
                    </motion.button>
                  );
                })}
              </div>
            </div>
          ) : null}

          {/* Los tres números que el socio necesita. El precio mayorista de la
              marca no está aquí, ni puede estarlo: la vista `catalogo_publico`
              no trae esa columna (regla 1 de CLAUDE.md). */}
          <AnimatePresence mode="wait">
            <motion.div
              key={v.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.25, ease: "easeOut" }}
              className="mt-5 rounded-xl border border-linea bg-fondo p-4"
            >
              <div className="flex items-end justify-between gap-4">
                <div>
                  <span className="block text-xs font-semibold text-tinta-suave">
                    Tu precio socio · {producto.variantes.length > 1 ? v.presentacion : "por unidad"}
                  </span>
                  <span className="num font-titulo text-2xl font-black text-tinta">
                    {soles(socio)}
                  </span>
                </div>
                <div className="text-right">
                  <span className="block text-xs font-semibold text-tinta-suave">
                    Precio de página
                  </span>
                  <span className="num font-titulo text-lg font-bold text-tinta-suave">
                    {soles(v.precioPagina)}
                  </span>
                </div>
              </div>
              <div className="mt-3 rounded-lg bg-chicha-bg px-3 py-2 text-sm font-bold text-chicha">
                <span className="num">Ganas {soles(ganancia)} por unidad</span> con tu nivel{" "}
                {nivel.medalla} {nivel.nombre}
              </div>
              <p className="mt-2 text-xs leading-relaxed text-tinta-suave">
                Es un precio referencial, para que decidas. El definitivo lo calcula la base al
                registrar el pedido, leyendo el catálogo y tu nivel.
              </p>
            </motion.div>
          </AnimatePresence>

          <dl className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Dato
              icono={<Building2 className="h-4 w-4" aria-hidden="true" />}
              titulo="Almacén"
              valor={producto.marcaCiudadAlmacen || "Por confirmar"}
              detalle={v.stockAlmacen === null ? "Sin conteo de stock" : `${v.stockAlmacen} unidades`}
            />
            <Dato
              icono={<Store className="h-4 w-4" aria-hidden="true" />}
              titulo="Punto de venta"
              valor={producto.marcaCiudadPunto || "No disponible"}
              detalle={v.stockPunto === null ? "Sin conteo de stock" : `${v.stockPunto} unidades`}
            />
            {producto.tiempoPreparacion ? (
              <Dato
                icono={<Clock className="h-4 w-4" aria-hidden="true" />}
                titulo="Preparación"
                valor={producto.tiempoPreparacion}
                detalle="Antes de salir a despacho"
              />
            ) : null}
            {producto.recomendaciones ? (
              <Dato
                icono={<Lightbulb className="h-4 w-4" aria-hidden="true" />}
                titulo="Cómo venderlo"
                valor={producto.recomendaciones}
                detalle="Lo que recomienda la marca"
              />
            ) : null}
          </dl>
        </div>
      </div>
    </motion.div>
  );
}

function Dato({
  icono,
  titulo,
  valor,
  detalle,
}: {
  icono: React.ReactNode;
  titulo: string;
  valor: string;
  detalle: string;
}) {
  return (
    <div className="rounded-xl border border-linea bg-tarjeta p-3">
      <dt className="flex items-center gap-2 text-xs font-bold tracking-wide text-tinta-suave uppercase">
        {icono}
        {titulo}
      </dt>
      <dd className="mt-1 text-sm font-bold text-tinta">{valor}</dd>
      <dd className="text-xs text-tinta-suave">{detalle}</dd>
    </div>
  );
}
