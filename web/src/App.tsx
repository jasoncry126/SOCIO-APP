import { useEffect, useMemo, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { AlertTriangle, LayoutGrid, PackageSearch } from "lucide-react";
import { CatalogoProductos } from "./componentes/CatalogoProductos";
import { DetalleProducto } from "./componentes/DetalleProducto";
import { SeguimientoPedido } from "./componentes/SeguimientoPedido";
import { EsqueletoCatalogo, EsqueletoSeguimiento } from "./componentes/Esqueleto";
import { cargarCatalogo, categoriasDe } from "./datos/catalogo";
import { cargarPedidos } from "./datos/pedidos";
import { PEDIDOS_DEMO, PRODUCTOS_DEMO } from "./datos/demostracion";
import { hayConexion } from "./datos/supabase";
import { nivelPorId } from "./precios";
import type { Pedido, Producto } from "./tipos";

type Pestana = "catalogo" | "pedidos";

export default function App() {
  const [productos, setProductos] = useState<readonly Producto[]>([]);
  const [pedidos, setPedidos] = useState<readonly Pedido[]>([]);
  const [cargando, setCargando] = useState(true);
  const [aviso, setAviso] = useState("");
  const [pestana, setPestana] = useState<Pestana>("catalogo");
  const [elegido, setElegido] = useState<Producto | null>(null);
  const [categoria, setCategoria] = useState("todas");

  /* El nivel lo decide la base por ventas ENTREGADAS (regla 5). Mientras esta
     versión no tenga sesión iniciada no hay ficha de socio que leer, así que
     se muestra el nivel de entrada en vez de inventar uno. */
  const nivel = nivelPorId("bronce");

  useEffect(() => {
    let vigente = true;

    async function traer() {
      if (!hayConexion) {
        setProductos(PRODUCTOS_DEMO);
        setPedidos(PEDIDOS_DEMO);
        setAviso(
          "Estás viendo datos de ejemplo. Copia .env.example como .env.local con tu " +
            "Project URL y tu clave anon para conectar con la base real.",
        );
        setCargando(false);
        return;
      }
      try {
        const [conCatalogo, conPedidos] = await Promise.all([cargarCatalogo(), cargarPedidos()]);
        if (!vigente) return;
        setProductos(conCatalogo);
        setPedidos(conPedidos);
      } catch (e) {
        if (!vigente) return;
        /* Si la base falla se enseñan los datos de ejemplo y se dice claramente
           que lo son. Lo que no se hace nunca es dejarlos pasar por reales. */
        setProductos(PRODUCTOS_DEMO);
        setPedidos(PEDIDOS_DEMO);
        setAviso(
          (e instanceof Error ? e.message : "No se pudo leer de la base") +
            " · Mientras tanto, estás viendo datos de ejemplo.",
        );
      } finally {
        if (vigente) setCargando(false);
      }
    }

    void traer();
    return () => {
      vigente = false;
    };
  }, []);

  const categorias = useMemo(() => ["todas", ...categoriasDe(productos)], [productos]);
  const visibles = useMemo(
    () => (categoria === "todas" ? productos : productos.filter((p) => p.categoria === categoria)),
    [productos, categoria],
  );

  return (
    <div className="min-h-screen bg-fondo">
      <header className="sticky top-0 z-20 border-b border-linea bg-fondo/90 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
          <span className="font-titulo text-xl font-black tracking-wide text-tinta">
            S<span className="text-sol">O</span>CIO
          </span>
          <nav className="flex gap-1 rounded-xl bg-linea/50 p-1">
            <Pestanya
              activa={pestana === "catalogo"}
              alTocar={() => {
                setPestana("catalogo");
                setElegido(null);
              }}
              icono={<LayoutGrid className="h-4 w-4" aria-hidden="true" />}
              texto="Catálogo"
            />
            <Pestanya
              activa={pestana === "pedidos"}
              alTocar={() => setPestana("pedidos")}
              icono={<PackageSearch className="h-4 w-4" aria-hidden="true" />}
              texto="Pedidos"
            />
          </nav>
          <span className="hidden text-xs font-bold text-tinta-suave sm:block">
            {nivel.medalla} {nivel.nombre}
          </span>
        </div>
      </header>

      {aviso ? (
        <div className="mx-auto mt-4 flex max-w-6xl items-start gap-3 rounded-xl border border-alerta/40 bg-alerta-bg px-4 py-3 text-sm text-alerta">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
          <p className="leading-relaxed">{aviso}</p>
        </div>
      ) : null}

      <main className="pb-16">
        {pestana === "catalogo" ? (
          cargando ? (
            <EsqueletoCatalogo />
          ) : (
            <AnimatePresence mode="wait">
              {elegido ? (
                <DetalleProducto
                  key={elegido.id}
                  producto={elegido}
                  nivel={nivel}
                  alVolver={() => setElegido(null)}
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
                  <CatalogoProductos productos={visibles} nivel={nivel} alElegir={setElegido} />
                </motion.div>
              )}
            </AnimatePresence>
          )
        ) : cargando ? (
          <div className="px-4 pt-6">
            <EsqueletoSeguimiento />
          </div>
        ) : pedidos.length === 0 ? (
          <p className="mx-auto mt-10 max-w-2xl rounded-2xl border border-dashed border-linea p-10 text-center text-sm text-tinta-suave">
            Aún no tienes pedidos. Cuando cierres tu primera venta aparecerá aquí con su código de
            seguimiento.
          </p>
        ) : (
          <div className="flex flex-col gap-5 px-4 pt-6">
            {pedidos.map((p) => (
              <SeguimientoPedido key={p.codigo} pedido={p} />
            ))}
          </div>
        )}
      </main>
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
