import { useMemo, useState, type FormEvent } from "react";
import { motion } from "framer-motion";
import { ArrowLeft, Home, Minus, Plus, Store, Trash2, Truck } from "lucide-react";
import type { Carrito } from "../carrito";
import type { DatosEnvio, ModoEntrega, Nivel, Producto } from "../tipos";
import { precioSocio, soles } from "../precios";
import { AGENCIAS, costoDeEnvio, origenesDe } from "../envios";

interface Props {
  carrito: Carrito;
  nivel: Nivel;
  /** Un producto cualquiera de la marca del carrito, para saber sus orígenes. */
  muestra: Producto;
  alVolver: () => void;
  alRegistrar: (envio: DatosEnvio, costoEnvio: number) => Promise<void>;
}

export function Checkout({ carrito, nivel, muestra, alVolver, alRegistrar }: Props) {
  const origenes = useMemo(() => origenesDe(muestra), [muestra]);
  const origenActual = origenes.find((o) => o.id === carrito.origen) ?? origenes[0];
  const modosPermitidos: readonly ModoEntrega[] = origenActual?.modos ?? ["agencia"];

  const [modo, setModo] = useState<ModoEntrega>(modosPermitidos[0] ?? "agencia");
  const [destinatario, setDestinatario] = useState("");
  const [documento, setDocumento] = useState("");
  const [celular, setCelular] = useState("");
  const [detalle, setDetalle] = useState("");
  const [referencia, setReferencia] = useState("");
  const [agencia, setAgencia] = useState(AGENCIAS[0]?.id ?? "olva");
  const [esLima, setEsLima] = useState(true);
  const [error, setError] = useState("");
  const [registrando, setRegistrando] = useState(false);

  const envio = costoDeEnvio(modo, agencia, esLima);
  const aDepositar = Math.round((carrito.aPagar + envio) * 100) / 100;

  async function enviar(e: FormEvent) {
    e.preventDefault();
    setError("");

    if (!destinatario.trim()) return setError("Falta el nombre de quien recibe.");
    if (!/^\d{8}$/.test(documento) && !/^\d{11}$/.test(documento)) {
      return setError("El documento es un DNI de 8 dígitos o un RUC de 11.");
    }
    if (!/^9\d{8}$/.test(celular)) return setError("El celular son nueve dígitos y empieza por 9.");
    if (!detalle.trim()) {
      return setError(
        modo === "agencia" ? "Falta el local de la agencia." : "Falta la dirección de entrega.",
      );
    }

    setRegistrando(true);
    try {
      await alRegistrar(
        {
          destinatario: destinatario.trim(),
          documento: documento.trim(),
          celular: celular.trim(),
          modo,
          detalle: detalle.trim(),
          referencia: referencia.trim(),
          agencia,
        },
        envio,
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "No se pudo registrar el pedido.");
      setRegistrando(false);
    }
  }

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
        <ArrowLeft className="h-4 w-4" aria-hidden="true" /> Seguir comprando
      </button>

      <h2 className="font-titulo text-xl font-bold text-tinta">Tu pedido</h2>

      {/* ---- Lo que lleva ---- */}
      <ul className="mt-3 divide-y divide-linea rounded-2xl border border-linea bg-tarjeta">
        {carrito.lineas.map((l) => (
          <li key={l.variante.id} className="flex items-center gap-3 p-3">
            <span className="text-2xl" aria-hidden="true">
              {l.producto.emoji}
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-bold text-tinta">
                {l.producto.nombre} · {l.variante.presentacion}
              </p>
              <p className="num text-xs text-tinta-suave">
                {soles(precioSocio(l.variante, nivel))} c/u · vendes a{" "}
                {soles(l.variante.precioPagina)}
              </p>
            </div>
            <div className="flex items-center gap-1 rounded-lg border border-linea">
              <button
                type="button"
                aria-label={`Quitar uno de ${l.producto.nombre}`}
                onClick={() => carrito.cambiar(l.variante.id, l.cantidad - 1)}
                className="px-2 py-1.5 text-tinta transition-transform active:scale-90"
              >
                <Minus className="h-3.5 w-3.5" aria-hidden="true" />
              </button>
              <span className="num w-6 text-center font-titulo text-sm font-bold">
                {l.cantidad}
              </span>
              <button
                type="button"
                aria-label={`Agregar uno de ${l.producto.nombre}`}
                onClick={() => carrito.cambiar(l.variante.id, l.cantidad + 1)}
                className="px-2 py-1.5 text-tinta transition-transform active:scale-90"
              >
                <Plus className="h-3.5 w-3.5" aria-hidden="true" />
              </button>
            </div>
            <button
              type="button"
              aria-label={`Eliminar ${l.producto.nombre} del pedido`}
              onClick={() => carrito.quitar(l.variante.id)}
              className="rounded-lg p-1.5 text-tinta-suave transition-colors hover:bg-alerta-bg hover:text-alerta"
            >
              <Trash2 className="h-4 w-4" aria-hidden="true" />
            </button>
          </li>
        ))}
      </ul>

      <form onSubmit={enviar} className="mt-5">
        {/* ---- Cómo se entrega ---- */}
        <h3 className="text-xs font-bold tracking-wider text-tinta-suave uppercase">
          Cómo se entrega
        </h3>
        <p className="mt-1 text-xs text-tinta-suave">
          Sale de {origenActual?.nombre ?? "el almacén"} · {origenActual?.plazo ?? ""}
        </p>

        <div className="mt-2 grid grid-cols-2 gap-3">
          {(["agencia", "domicilio"] as const).map((m) => {
            const permitido = modosPermitidos.includes(m);
            const activo = modo === m;
            return (
              <motion.button
                key={m}
                type="button"
                disabled={!permitido}
                {...(permitido ? { whileHover: { y: -2 }, whileTap: { scale: 0.97 } } : {})}
                onClick={() => setModo(m)}
                className={
                  "rounded-xl border-2 p-3 text-center transition-colors disabled:opacity-40 " +
                  (activo ? "border-sol bg-sol-bg" : "border-linea bg-tarjeta")
                }
              >
                {m === "agencia" ? (
                  <Truck className="mx-auto h-5 w-5 text-tinta" aria-hidden="true" />
                ) : (
                  <Home className="mx-auto h-5 w-5 text-tinta" aria-hidden="true" />
                )}
                <span className="mt-1 block text-sm font-bold text-tinta">
                  {m === "agencia" ? "Por agencia" : "A domicilio"}
                </span>
                <span className="block text-xs text-tinta-suave">
                  {m === "agencia"
                    ? "A todo el país"
                    : permitido
                      ? `Dentro de ${origenActual?.ciudad ?? "la ciudad"}`
                      : "No sale de este origen"}
                </span>
              </motion.button>
            );
          })}
        </div>

        {modo === "agencia" ? (
          <div className="mt-3">
            <div className="flex gap-2">
              {AGENCIAS.map((a) => (
                <button
                  key={a.id}
                  type="button"
                  onClick={() => setAgencia(a.id)}
                  className={
                    "flex-1 rounded-xl border-2 p-2.5 text-center text-sm font-bold transition-colors " +
                    (agencia === a.id
                      ? "border-sol bg-sol-bg text-tinta"
                      : "border-linea bg-tarjeta text-tinta-suave")
                  }
                >
                  {a.nombre}
                  <span className="block text-xs font-semibold text-tinta-suave">
                    {a.lasPagaElSocio ? `Lima ${soles(a.lima)} · Prov. ${soles(a.provincia)}` : a.nota}
                  </span>
                </button>
              ))}
            </div>
            <label className="mt-3 flex items-center gap-2 text-sm text-tinta-suave">
              <input
                type="checkbox"
                checked={esLima}
                onChange={(e) => setEsLima(e.target.checked)}
                className="h-4 w-4 accent-sol"
              />
              El destino está en Lima
            </label>
          </div>
        ) : null}

        {/* ---- Quién recibe ---- */}
        <h3 className="mt-5 text-xs font-bold tracking-wider text-tinta-suave uppercase">
          Quién recibe
        </h3>
        <div className="mt-2 grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Campo etiqueta="Nombre completo" valor={destinatario} alCambiar={setDestinatario} />
          <Campo
            etiqueta="DNI o RUC"
            valor={documento}
            alCambiar={setDocumento}
            modo="numeric"
            pista="8 dígitos (DNI) u 11 (RUC)"
          />
          <Campo etiqueta="Celular" valor={celular} alCambiar={setCelular} modo="numeric" />
          <Campo
            etiqueta={modo === "agencia" ? "Local de la agencia" : "Dirección"}
            valor={detalle}
            alCambiar={setDetalle}
          />
          {modo === "domicilio" ? (
            <Campo etiqueta="Referencia (opcional)" valor={referencia} alCambiar={setReferencia} />
          ) : null}
        </div>

        {/* ---- La cuenta ---- */}
        <div className="mt-5 rounded-2xl border border-linea bg-tarjeta p-4">
          <Fila texto="Mercadería (tu precio socio)" valor={soles(carrito.aPagar)} />
          <Fila
            texto={modo === "agencia" ? `Envío por ${agencia}` : "Entrega a domicilio"}
            valor={envio === 0 ? "Lo paga el cliente" : soles(envio)}
          />
          <div className="mt-2 flex items-baseline justify-between border-t border-linea pt-2">
            <span className="font-titulo text-sm font-bold text-tinta">Depositarás</span>
            <span className="num font-titulo text-xl font-black text-tinta">
              {soles(aDepositar)}
            </span>
          </div>
          <div className="mt-2 rounded-lg bg-chicha-bg px-3 py-2 text-sm font-bold text-chicha">
            <span className="num">Le cobras a tu cliente {soles(carrito.aCobrar + envio)}</span> ·{" "}
            <span className="num">ganas {soles(carrito.ganancia)}</span>
          </div>
          <p className="mt-2 flex items-start gap-2 text-xs leading-relaxed text-tinta-suave">
            <Store className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden="true" />
            El monto exacto, con los céntimos que identifican tu pedido, te lo dice la base al
            registrarlo. Por eso primero se registra y después se deposita.
          </p>
        </div>

        {error ? (
          <p role="alert" className="mt-3 rounded-lg bg-alerta-bg px-3 py-2 text-sm font-semibold text-alerta">
            {error}
          </p>
        ) : null}

        <motion.button
          type="submit"
          whileHover={{ y: -2 }}
          whileTap={{ scale: 0.98 }}
          disabled={registrando || carrito.lineas.length === 0}
          className="mt-4 flex w-full items-center justify-center gap-2 rounded-xl bg-sol px-4 py-3.5 font-titulo font-bold text-tinta disabled:opacity-60"
        >
          {registrando ? (
            <span className="h-5 w-5 animate-spin rounded-full border-2 border-tinta/30 border-t-tinta" />
          ) : (
            "Registrar pedido y ver cuánto depositar"
          )}
        </motion.button>
      </form>
    </motion.div>
  );
}

function Campo({
  etiqueta,
  valor,
  alCambiar,
  modo,
  pista,
}: {
  etiqueta: string;
  valor: string;
  alCambiar: (v: string) => void;
  modo?: "numeric";
  pista?: string;
}) {
  return (
    <label className="block">
      <span className="text-xs font-bold text-tinta-suave">{etiqueta}</span>
      <input
        value={valor}
        onChange={(e) => alCambiar(e.target.value)}
        {...(modo ? { inputMode: modo } : {})}
        className="mt-1 w-full rounded-xl border border-linea bg-tarjeta px-3 py-2.5 text-sm text-tinta outline-sol focus:outline-2"
      />
      {pista ? <span className="mt-0.5 block text-xs text-tinta-suave">{pista}</span> : null}
    </label>
  );
}

function Fila({ texto, valor }: { texto: string; valor: string }) {
  return (
    <div className="flex items-baseline justify-between py-1 text-sm">
      <span className="text-tinta-suave">{texto}</span>
      <span className="num font-semibold text-tinta">{valor}</span>
    </div>
  );
}
