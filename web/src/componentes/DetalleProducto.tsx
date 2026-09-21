import { useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { ArrowLeft, Building2, Clock, Lightbulb, Minus, Plus, ShoppingCart, Store } from "lucide-react";
import type { Nivel, Producto, Variante } from "../tipos";
import { gananciaUnitaria, precioSocio, soles } from "../precios";
import { stockEn, type OrigenId } from "../envios";
import { Foto } from "./Foto";

interface Props {
  producto: Producto;
  nivel: Nivel;
  /** De dónde saldría el pedido: decide qué stock cuenta. */
  origen: OrigenId;
  /** Devuelve null si entró al carrito, o el motivo por el que no. */
  alAgregar: (variante: Variante, cuantas: number) => string | null;
  alVolver: () => void;
}

export function DetalleProducto({ producto, nivel, origen, alAgregar, alVolver }: Props) {
  const [elegida, setElegida] = useState(0);
  const [cuantas, setCuantas] = useState(1);
  const [aviso, setAviso] = useState("");
  const [entro, setEntro] = useState(false);
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
        {/* Alto de 4:3 y la foto entera dentro: las fotos de producto suelen
            ser cuadradas, y un recorte a 16:9 le corta la mitad al frasco. */}
        <div className="aspect-[4/3] overflow-hidden bg-fondo p-4">
          <Foto
            imagen={v.imagen}
            emoji={producto.emoji}
            alt={`${producto.nombre} · ${v.presentacion}`}
            clase="text-7xl"
            ajuste="contener"
          />
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
                      onClick={() => {
                        setElegida(i);
                        setCuantas(1);
                        setAviso("");
                        setEntro(false);
                      }}
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

          {/* ---- Al carrito ---- */}
          <div className="mt-4 flex items-center gap-3">
            <div className="flex items-center gap-1 rounded-xl border border-linea">
              <button
                type="button"
                aria-label="Una menos"
                onClick={() => setCuantas((n) => Math.max(1, n - 1))}
                className="px-3 py-2.5 text-tinta transition-transform active:scale-90"
              >
                <Minus className="h-4 w-4" aria-hidden="true" />
              </button>
              <span className="num w-8 text-center font-titulo font-bold text-tinta">{cuantas}</span>
              <button
                type="button"
                aria-label="Una más"
                onClick={() => setCuantas((n) => n + 1)}
                className="px-3 py-2.5 text-tinta transition-transform active:scale-90"
              >
                <Plus className="h-4 w-4" aria-hidden="true" />
              </button>
            </div>

            <motion.button
              type="button"
              whileHover={{ y: -2 }}
              whileTap={{ scale: 0.98 }}
              animate={entro ? { scale: [1, 1.04, 1] } : { scale: 1 }}
              transition={{ duration: 0.3 }}
              onClick={() => {
                const problema = alAgregar(v, cuantas);
                setAviso(problema ?? "");
                setEntro(!problema);
                if (!problema) setCuantas(1);
              }}
              className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-sol px-4 py-3 font-titulo font-bold text-tinta"
            >
              <ShoppingCart className="h-4 w-4" aria-hidden="true" />
              {entro ? "Agregado ✓" : "Agregar al pedido"}
            </motion.button>
          </div>

          {aviso ? (
            <p role="alert" className="mt-2 rounded-lg bg-alerta-bg px-3 py-2 text-xs font-semibold text-alerta">
              {aviso}
            </p>
          ) : (
            <p className="mt-2 text-xs text-tinta-suave">
              {stockEn(v, origen) === null
                ? "La marca no lleva conteo de stock en el origen que elegiste."
                : `Quedan ${String(stockEn(v, origen))} en el origen que elegiste.`}
            </p>
          )}

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
