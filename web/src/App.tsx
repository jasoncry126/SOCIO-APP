import { useCallback, useEffect, useMemo, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { AlertTriangle, LayoutGrid, LogOut, PackageSearch, ShoppingCart } from "lucide-react";
import { CatalogoProductos } from "./componentes/CatalogoProductos";
import { Checkout } from "./componentes/Checkout";
import { DetalleProducto } from "./componentes/DetalleProducto";
import { Ingreso } from "./componentes/Ingreso";
import { PagoDeposito } from "./componentes/PagoDeposito";
import { SeguimientoPedido } from "./componentes/SeguimientoPedido";
import { EsqueletoCatalogo, EsqueletoSeguimiento } from "./componentes/Esqueleto";
import { cargarCatalogo, categoriasDe } from "./datos/catalogo";
import { cargarPedidos, crearPedido } from "./datos/pedidos";
import { salir, socioActual } from "./datos/auth";
import { PEDIDOS_DEMO, PRODUCTOS_DEMO, SOCIO_DEMO } from "./datos/demostracion";
import { hayConexion } from "./datos/supabase";
import { useCarrito } from "./carrito";
import { nivelPorId, soles } from "./precios";
import type { DatosEnvio, Pedido, Producto, Socio } from "./tipos";

/* ===========================================================================
   El recorrido completo del socio: catálogo → ficha → pedido → depósito.

   Dos cosas que no se deciden aquí y por eso no se calculan aquí:

   · El NIVEL del socio, que lo pone la base según ventas entregadas (regla 5).
     Esta pantalla lo lee de su ficha y lo usa para enseñar precios
     referenciales; el precio que se cobra lo calcula la base al registrar.

   · El MONTO a depositar, con sus céntimos identificadores, que sale del
     código del pedido. Por eso el pedido se registra primero y se cobra
     después: antes de existir no hay código del que derivarlos.
   =========================================================================== */

type Pantalla = "catalogo" | "detalle" | "checkout" | "pago" | "pedidos";

const AVISO_DEMO =
  "Estás viendo datos de ejemplo. Copia .env.example como .env.local con tu Project URL y tu " +
  "clave anon para entrar con tu cuenta y registrar pedidos de verdad.";

export default function App() {
  const [socio, setSocio] = useState<Socio | null>(null);
  const [revisandoSesion, setRevisandoSesion] = useState(true);
  const [productos, setProductos] = useState<readonly Producto[]>([]);
  const [pedidos, setPedidos] = useState<readonly Pedido[]>([]);
  const [cargando, setCargando] = useState(true);
  const [aviso, setAviso] = useState("");
  const [pantalla, setPantalla] = useState<Pantalla>("catalogo");
  const [elegido, setElegido] = useState<Producto | null>(null);
  const [enPago, setEnPago] = useState<Pedido | null>(null);
  const [categoria, setCategoria] = useState("todas");

  /* Sin conexión configurada no hay a quién pedirle una sesión: se entra en
     modo demostración para poder mirar las pantallas, y se dice en pantalla
     que los datos son inventados. Nunca se mezclan con los reales. */
  const modoDemo = !hayConexion;
  const nivel = nivelPorId(socio?.nivel);
  const carrito = useCarrito(nivel);

  useEffect(() => {
    let vigente = true;

    async function mirarSesion() {
      if (modoDemo) {
        setSocio(SOCIO_DEMO);
        setRevisandoSesion(false);
        return;
      }
      try {
        const quien = await socioActual();
        if (vigente) setSocio(quien);
      } catch {
        if (vigente) setSocio(null);
      } finally {
        if (vigente) setRevisandoSesion(false);
      }
    }

    void mirarSesion();
    return () => {
      vigente = false;
    };
  }, [modoDemo]);

  const traerTodo = useCallback(async () => {
    if (modoDemo) {
      setProductos(PRODUCTOS_DEMO);
      setPedidos(PEDIDOS_DEMO);
      setAviso(AVISO_DEMO);
      setCargando(false);
      return;
    }
    setCargando(true);
    try {
      const [conCatalogo, conPedidos] = await Promise.all([cargarCatalogo(), cargarPedidos()]);
      setProductos(conCatalogo);
      setPedidos(conPedidos);
      setAviso("");
    } catch (e) {
      /* Si la base falla se enseñan los datos de ejemplo y se dice claramente
         que lo son. Lo que no se hace nunca es dejarlos pasar por reales. */
      setProductos(PRODUCTOS_DEMO);
      setPedidos(PEDIDOS_DEMO);
      setAviso(
        (e instanceof Error ? e.message : "No se pudo leer de la base") +
          " · Mientras tanto, estás viendo datos de ejemplo.",
      );
    } finally {
      setCargando(false);
    }
  }, [modoDemo]);

  useEffect(() => {
    if (!socio) return;
    void traerTodo();
  }, [socio, traerTodo]);

  const categorias = useMemo(() => ["todas", ...categoriasDe(productos)], [productos]);
  const visibles = useMemo(
    () => (categoria === "todas" ? productos : productos.filter((p) => p.categoria === categoria)),
    [productos, categoria],
  );

  /* Los orígenes y el envío salen de la marca del carrito, así que el checkout
     necesita un producto de esa marca para leerlos. */
  const muestra = carrito.lineas[0]?.producto ?? null;

  async function registrar(envio: DatosEnvio, costoEnvio: number) {
    if (modoDemo) {
      throw new Error(
        "Estás en datos de ejemplo: para registrar un pedido de verdad falta configurar la conexión.",
      );
    }
    const creado = await crearPedido(carrito.paraLaBase(), envio, carrito.origen, costoEnvio);
    carrito.vaciar();

    /* El pedido recién creado se relee de la base en vez de armarlo aquí: el
       monto con céntimos, el precio y la ganancia los calculó ella.

       Con una salvedad: mientras la vista `pedidos_socio` no traiga la
       columna del monto a pagar, la relectura viene en cero y el socio no
       sabría cuánto depositar. En ese caso vale el monto que devolvió
       crear_pedido, que es el mismo número y sale de la misma función. */
    const frescos = await cargarPedidos();
    setPedidos(frescos);
    const guardado = frescos.find((p) => p.id === creado.id) ?? null;
    setEnPago(
      guardado && guardado.montoADepositar <= 0
        ? { ...guardado, montoADepositar: creado.montoADepositar }
        : guardado,
    );
    setPantalla("pago");
  }

  async function volverDelPago(mensaje?: string) {
    setEnPago(null);
    setPantalla("pedidos");
    if (!modoDemo) await traerTodo();
    /* Después de releer, porque una lectura buena limpia el aviso. */
    if (mensaje) setAviso(mensaje);
  }

  if (revisandoSesion) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-fondo">
        <span className="h-8 w-8 animate-spin rounded-full border-2 border-linea border-t-sol" />
      </div>
    );
  }

  if (!socio) {
    return <Ingreso alEntrar={setSocio} hayConexion={hayConexion} />;
  }

  const pendiente = pedidos.filter(
    (p) => p.estado === "pendiente_pago" || p.pagoEstado === "rechazado",
  ).length;

  return (
    <div className="min-h-screen bg-fondo">
      <header className="sticky top-0 z-20 border-b border-linea bg-fondo/90 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
          <span className="font-titulo text-xl font-black tracking-wide text-tinta">
            S<span className="text-sol">O</span>CIO
          </span>
          <nav className="flex gap-1 rounded-xl bg-linea/50 p-1">
            <Pestanya
              activa={pantalla === "catalogo" || pantalla === "detalle"}
              alTocar={() => {
                setPantalla("catalogo");
                setElegido(null);
              }}
              icono={<LayoutGrid className="h-4 w-4" aria-hidden="true" />}
              texto="Catálogo"
            />
            <Pestanya
              activa={pantalla === "pedidos" || pantalla === "pago"}
              alTocar={() => {
                setEnPago(null);
                setPantalla("pedidos");
              }}
              icono={<PackageSearch className="h-4 w-4" aria-hidden="true" />}
              texto={pendiente > 0 ? `Pedidos (${String(pendiente)})` : "Pedidos"}
            />
          </nav>
          <div className="flex items-center gap-3">
            <span className="hidden text-xs font-bold text-tinta-suave sm:block">
              {nivel.medalla} {nivel.nombre}
            </span>
            {modoDemo ? null : (
              <button
                type="button"
                aria-label="Salir de tu cuenta"
                onClick={() => {
                  void salir().then(() => setSocio(null));
                }}
                className="rounded-lg p-1.5 text-tinta-suave transition-colors hover:text-tinta"
              >
                <LogOut className="h-4 w-4" aria-hidden="true" />
              </button>
            )}
          </div>
        </div>
      </header>

      {aviso ? (
        <div className="mx-auto mt-4 flex max-w-6xl items-start gap-3 rounded-xl border border-alerta/40 bg-alerta-bg px-4 py-3 text-sm text-alerta">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
          <p className="leading-relaxed">{aviso}</p>
        </div>
      ) : null}

      <main className="pb-28">
        <AnimatePresence mode="wait">
          {pantalla === "checkout" && muestra ? (
            <Checkout
              key="checkout"
              carrito={carrito}
              nivel={nivel}
              muestra={muestra}
              alVolver={() => setPantalla("catalogo")}
              alRegistrar={registrar}
            />
          ) : pantalla === "pago" && enPago ? (
            <PagoDeposito
              key={"pago-" + enPago.id}
              pedido={enPago}
              alDeclarar={(mensaje) => void volverDelPago(mensaje)}
              alVolver={() => void volverDelPago()}
              alCancelar={() => void volverDelPago()}
            />
          ) : pantalla === "pedidos" || pantalla === "pago" ? (
            <motion.div key="pedidos" className="flex flex-col gap-5 px-4 pt-6">
              {cargando ? (
                <EsqueletoSeguimiento />
              ) : pedidos.length === 0 ? (
                <p className="mx-auto mt-6 max-w-2xl rounded-2xl border border-dashed border-linea p-10 text-center text-sm text-tinta-suave">
                  Aún no tienes pedidos. Cuando cierres tu primera venta aparecerá aquí con su
                  código de seguimiento.
                </p>
              ) : (
                pedidos.map((p) => (
                  <SeguimientoPedido
                    key={p.codigo}
                    pedido={p}
                    accion={
                      p.estado === "pendiente_pago" || p.pagoEstado === "rechazado" ? (
                        <motion.button
                          type="button"
                          whileHover={{ y: -2 }}
                          whileTap={{ scale: 0.98 }}
                          onClick={() => {
                            setEnPago(p);
                            setPantalla("pago");
                          }}
                          className="w-full rounded-xl bg-sol px-4 py-3 font-titulo font-bold text-tinta"
                        >
                          {p.pagoEstado === "rechazado"
                            ? "Subir otra captura"
                            : `Depositar ${soles(p.montoADepositar)} y subir la captura`}
                        </motion.button>
                      ) : null
                    }
                  />
                ))
              )}
            </motion.div>
          ) : cargando ? (
            <EsqueletoCatalogo key="esqueleto" />
          ) : elegido ? (
            <DetalleProducto
              key={elegido.id}
              producto={elegido}
              nivel={nivel}
              origen={carrito.origen}
              alAgregar={(variante, cuantas) => carrito.agregar(elegido, variante, cuantas)}
              alVolver={() => {
                setElegido(null);
                setPantalla("catalogo");
              }}
            />
          ) : (
            <motion.div key="cuadricula">
              {categorias.length > 2 ? (
                <div className="mx-auto flex max-w-6xl flex-wrap gap-2 px-4 pt-4">
                  {categorias.map((c) => (
                    <motion.button
                      key={c}
                      type="button"
                      whileHover={{ y: -2 }}
                      whileTap={{ scale: 0.96 }}
                      onClick={() => setCategoria(c)}
                      className={
                        "rounded-full border-2 px-3 py-1.5 text-xs font-bold transition-colors " +
                        (categoria === c
                          ? "border-sol bg-sol-bg text-tinta"
                          : "border-linea bg-tarjeta text-tinta-suave hover:border-sol-osc")
                      }
                    >
                      {c === "todas" ? "Todas" : c}
                    </motion.button>
                  ))}
                </div>
              ) : null}
              <CatalogoProductos
                productos={visibles}
                nivel={nivel}
                alElegir={(p) => {
                  setElegido(p);
                  setPantalla("detalle");
                }}
              />
            </motion.div>
          )}
        </AnimatePresence>
      </main>

      {/* La barra del carrito solo aparece mientras se compra: en el checkout y
          en el depósito estorbaría, y el pedido ya está en pantalla. */}
      <AnimatePresence>
        {carrito.unidades > 0 && (pantalla === "catalogo" || pantalla === "detalle") ? (
          <motion.div
            initial={{ y: 80 }}
            animate={{ y: 0 }}
            exit={{ y: 80 }}
            transition={{ duration: 0.25, ease: "easeOut" }}
            className="fixed inset-x-0 bottom-0 z-30 border-t border-linea bg-tarjeta px-4 py-3 shadow-[0_-4px_16px_rgba(20,38,30,.09)]"
          >
            <div className="mx-auto flex max-w-2xl items-center gap-4">
              <div className="leading-tight">
                <span className="block text-xs font-bold tracking-wide text-tinta-suave uppercase">
                  {carrito.unidades === 1 ? "1 artículo" : `${String(carrito.unidades)} artículos`}
                </span>
                <span className="num font-titulo font-black text-tinta">
                  {soles(carrito.aPagar)}
                </span>
                <span className="num ml-2 text-xs font-bold text-chicha">
                  ganas {soles(carrito.ganancia)}
                </span>
              </div>
              <motion.button
                type="button"
                whileHover={{ y: -2 }}
                whileTap={{ scale: 0.98 }}
                onClick={() => setPantalla("checkout")}
                className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-sol px-4 py-3 font-titulo font-bold text-tinta"
              >
                <ShoppingCart className="h-4 w-4" aria-hidden="true" />
                Ver mi pedido
              </motion.button>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  );
}

function Pestanya({
  activa,
  alTocar,
  icono,
  texto,
}: {
  activa: boolean;
  alTocar: () => void;
  icono: React.ReactNode;
  texto: string;
}) {
  return (
    <motion.button
      type="button"
      whileTap={{ scale: 0.96 }}
      onClick={alTocar}
      aria-current={activa ? "page" : undefined}
      className={
        "flex items-center gap-2 rounded-lg px-3 py-1.5 text-sm font-bold transition-colors " +
        (activa ? "bg-tarjeta text-tinta shadow-sm" : "text-tinta-suave hover:text-tinta")
      }
    >
      {icono}
      {texto}
    </motion.button>
  );
}
