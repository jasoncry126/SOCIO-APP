import { useEffect, useMemo, useRef, useState, type ChangeEvent } from "react";
import { AnimatePresence, motion } from "framer-motion";
import {
  ArrowLeft,
  Banknote,
  Check,
  Copy,
  Paperclip,
  QrCode,
  ShieldAlert,
  Trash2,
} from "lucide-react";
import { declararPago, subirCaptura, cancelarPedidoSinPagar, type MetodoPago } from "../datos/pedidos";
import { CUENTA_SOCIO } from "../datos/cuenta-socio";
import { soles } from "../precios";
import type { Pedido } from "../tipos";

/* ===========================================================================
   Confirmar el depósito.

   Cuando se llega aquí el pedido YA ESTÁ REGISTRADO y esperando el depósito.
   Esta pantalla no crea nada: enseña el monto exacto que calculó la base y
   recoge la evidencia.

   Por qué en ese orden: el monto lleva céntimos derivados del código del
   pedido (S/ 158.37, no S/ 158.00) y ese código no existe hasta que el
   pedido está en la base. Cobrando antes, el socio depositaría una cifra
   redonda y su abono no se distinguiría de los demás del día.
   =========================================================================== */

interface Props {
  pedido: Pedido;
  /** Cuando el depósito quedó declarado: lleva a la lista de pedidos. El
      aviso llega vacío si todo cuadró, y con texto si hay que decir algo. */
  alDeclarar: (aviso: string) => void;
  alVolver: () => void;
  /** El pedido apartó stock; cancelarlo lo devuelve. */
  alCancelar: () => void;
}

type Zona = "billetera" | "banco";

export function PagoDeposito({ pedido, alDeclarar, alVolver, alCancelar }: Props) {
  const [zona, setZona] = useState<Zona>("billetera");
  const [archivo, setArchivo] = useState<File | null>(null);
  const [vista, setVista] = useState("");
  const [operacion, setOperacion] = useState("");
  const [monto, setMonto] = useState(pedido.montoADepositar.toFixed(2));
  const [error, setError] = useState("");
  const [paso, setPaso] = useState("");
  const [enviando, setEnviando] = useState(false);
  const [cancelando, setCancelando] = useState(false);
  const [copiado, setCopiado] = useState(false);
  const entrada = useRef<HTMLInputElement>(null);

  /* La miniatura vive como URL de objeto, no como base64: pesa menos y se
     suelta al cambiar de archivo o al salir de la pantalla. */
  useEffect(() => {
    if (!archivo) {
      setVista("");
      return;
    }
    const url = URL.createObjectURL(archivo);
    setVista(url);
    return () => URL.revokeObjectURL(url);
  }, [archivo]);

  const [soles_, centimos] = useMemo(() => {
    const partes = pedido.montoADepositar.toFixed(2).split(".");
    return [partes[0] ?? "0", partes[1] ?? "00"] as const;
  }, [pedido.montoADepositar]);

  function elegir(e: ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0] ?? null;
    setError("");
    setArchivo(f);
  }

  async function copiarCuenta() {
    const texto =
      zona === "banco"
        ? `${CUENTA_SOCIO.banco} · ${CUENTA_SOCIO.numero} · CCI ${CUENTA_SOCIO.cci} · ${CUENTA_SOCIO.titular}`
        : CUENTA_SOCIO.billetera;
    try {
      await navigator.clipboard.writeText(texto);
      setCopiado(true);
      setTimeout(() => setCopiado(false), 1800);
    } catch {
      /* Sin permiso del navegador no se copia; los datos están a la vista. */
    }
  }

  async function confirmar() {
    setError("");

    if (!archivo) return setError("Falta la captura de tu depósito.");
    if (operacion.trim().length < 4) {
      return setError("Escribe el número de operación que te dio Yape, Plin o tu banco.");
    }
    const declarado = Number(monto.replace(",", "."));
    if (!Number.isFinite(declarado) || declarado <= 0) {
      return setError("El monto que depositaste no es un número.");
    }

    setEnviando(true);
    try {
      setPaso("Subiendo tu captura…");
      const captura = await subirCaptura(archivo, pedido.codigo);

      setPaso("Registrando tu depósito…");
      const pago = await declararPago({
        pedidoId: pedido.id,
        numeroOperacion: operacion.trim(),
        montoReportado: declarado,
        metodo: (zona === "billetera" ? "yape" : "transferencia") satisfies MetodoPago,
        capturaRuta: captura.ruta,
        huella: captura.huella,
      });

      /* `cuadra` lo decide la base comparando lo declarado contra lo que el
         pedido pedía. Cuando no cuadra el pedido entra igual: lo revisa una
         persona. Decirlo evita que el socio crea que su depósito se perdió. */
      alDeclarar(
        pago.cuadra
          ? ""
          : "Declaraste " +
              soles(declarado) +
              " y el pedido pedía " +
              soles(pago.esperado) +
              ". El pedido entra igual, pero SOCIO lo revisa a mano antes de validarlo.",
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "No se pudo confirmar tu depósito.");
      setEnviando(false);
      setPaso("");
    }
  }

  async function cancelar() {
    if (!window.confirm("¿Cancelamos este pedido? Se libera el stock que apartó.")) return;
    setCancelando(true);
    setError("");
    try {
      await cancelarPedidoSinPagar(pedido.id);
      alCancelar();
    } catch (e) {
      setError(e instanceof Error ? e.message : "No se pudo cancelar el pedido.");
      setCancelando(false);
    }
  }

  const rechazado = pedido.pagoEstado === "rechazado";

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
        <ArrowLeft className="h-4 w-4" aria-hidden="true" /> Mis pedidos
      </button>

      {/* ---- El monto exacto ---- */}
      <div className="rounded-2xl bg-tinta p-5 text-center text-fondo">
        <span className="text-xs font-bold tracking-wider text-linea uppercase">
          Deposita exactamente
        </span>
        <p className="num mt-1 font-titulo text-4xl font-black">
          S/ {soles_}
          <span className="text-sol">.{centimos}</span>
        </p>
        <p className="mx-auto mt-2 max-w-sm text-xs leading-relaxed text-linea">
          Los céntimos no son un error: son lo que identifica tu depósito entre todos los del día
          en la cuenta de SOCIO. Deposita el monto exacto.
        </p>
        <p className="num mt-3 inline-block rounded-lg bg-tinta-suave px-3 py-1 font-titulo text-sm font-bold tracking-widest">
          {pedido.codigo}
        </p>
      </div>

      {rechazado && pedido.pagoMotivo ? (
        <p
          role="alert"
          className="mt-3 flex items-start gap-2 rounded-xl border border-alerta/40 bg-alerta-bg px-3 py-2.5 text-sm leading-relaxed text-alerta"
        >
          <ShieldAlert className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
          <span>
            <b>SOCIO no pudo validar tu depósito anterior.</b> {pedido.pagoMotivo} Sube una captura
            nueva y vuelve a confirmar.
          </span>
        </p>
      ) : null}

      {/* ---- Por dónde depositar ---- */}
      <div className="mt-4 grid grid-cols-2 gap-3">
        <Modo
          activo={zona === "billetera"}
          alTocar={() => setZona("billetera")}
          icono={<QrCode className="mx-auto h-5 w-5 text-tinta" aria-hidden="true" />}
          titulo="Yape o Plin"
          nota="Desde tu celular"
        />
        <Modo
          activo={zona === "banco"}
          alTocar={() => setZona("banco")}
          icono={<Banknote className="mx-auto h-5 w-5 text-tinta" aria-hidden="true" />}
          titulo="Transferencia"
          nota="Desde tu banca"
        />
      </div>

      <AnimatePresence mode="wait">
        <motion.div
          key={zona}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -8 }}
          transition={{ duration: 0.2, ease: "easeOut" }}
          className="mt-3 rounded-2xl border border-linea bg-tarjeta p-4"
        >
          {zona === "banco" ? (
            <p className="text-sm leading-relaxed text-tinta">
              <b>Cuenta SOCIO — {CUENTA_SOCIO.banco}</b>
              <br />
              <span className="num">{CUENTA_SOCIO.numero}</span>
              <br />
              <span className="num">CCI {CUENTA_SOCIO.cci}</span>
              <br />
              Titular: {CUENTA_SOCIO.titular}
            </p>
          ) : (
            <p className="text-sm leading-relaxed text-tinta">
              <b>Yape o Plin a nombre de {CUENTA_SOCIO.titular}</b>
              <br />
              <span className="num">{CUENTA_SOCIO.billetera}</span>
              <br />
              <span className="text-tinta-suave">
                Corrige el monto al exacto de arriba antes de enviar.
              </span>
            </p>
          )}

          <button
            type="button"
            onClick={() => void copiarCuenta()}
            className="mt-3 flex items-center gap-2 rounded-lg border border-linea px-3 py-2 text-xs font-bold text-tinta transition-colors hover:border-sol-osc"
          >
            {copiado ? (
              <Check className="h-3.5 w-3.5 text-ok" aria-hidden="true" />
            ) : (
              <Copy className="h-3.5 w-3.5" aria-hidden="true" />
            )}
            {copiado ? "Copiado" : "Copiar datos"}
          </button>

          {!CUENTA_SOCIO.esReal ? (
            <p className="mt-3 rounded-lg bg-alerta-bg px-3 py-2 text-xs leading-relaxed text-alerta">
              Estos datos son de relleno. Antes de vender hay que poner la cuenta real de SOCIO.
            </p>
          ) : null}
        </motion.div>
      </AnimatePresence>

      {/* ---- La captura ---- */}
      <input
        ref={entrada}
        type="file"
        accept="image/*"
        onChange={elegir}
        className="hidden"
        aria-label="Captura de tu depósito"
      />

      {archivo ? (
        <div className="mt-3 flex items-center gap-3 rounded-2xl border-2 border-ok bg-ok-bg p-3">
          {vista ? (
            <motion.img
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.25, ease: "easeOut" }}
              src={vista}
              alt="La captura que vas a enviar"
              className="h-16 w-16 rounded-lg object-cover"
            />
          ) : null}
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-bold text-ok">Captura lista ✓</p>
            <p className="truncate text-xs text-tinta-suave">{archivo.name}</p>
          </div>
          <button
            type="button"
            onClick={() => {
              setArchivo(null);
              if (entrada.current) entrada.current.value = "";
            }}
            aria-label="Quitar la captura"
            className="rounded-lg p-2 text-tinta-suave transition-colors hover:bg-alerta-bg hover:text-alerta"
          >
            <Trash2 className="h-4 w-4" aria-hidden="true" />
          </button>
        </div>
      ) : (
        <motion.button
          type="button"
          whileHover={{ y: -2 }}
          whileTap={{ scale: 0.99 }}
          onClick={() => entrada.current?.click()}
          className="mt-3 flex w-full items-start gap-3 rounded-2xl border-2 border-dashed border-linea bg-tarjeta p-4 text-left transition-colors hover:border-sol"
        >
          <Paperclip className="mt-0.5 h-5 w-5 shrink-0 text-tinta-suave" aria-hidden="true" />
          <span className="text-sm leading-relaxed text-tinta-suave">
            <b className="text-tinta">Sube la captura de tu depósito</b>
            <br />
            La foto o captura donde se vea el monto y la fecha. SOCIO la cruza contra el movimiento
            real de la cuenta.
          </span>
        </motion.button>
      )}

      {/* ---- Número de operación y monto ---- */}
      <label className="mt-4 block">
        <span className="text-xs font-bold text-tinta-suave">N° de operación de tu depósito</span>
        <input
          value={operacion}
          onChange={(e) => setOperacion(e.target.value)}
          placeholder="El código que te dio Yape, Plin o tu banco"
          className="mt-1 w-full rounded-xl border border-linea bg-tarjeta px-3 py-2.5 text-sm text-tinta outline-sol focus:outline-2"
        />
        <span className="mt-1 block text-xs leading-relaxed text-tinta-suave">
          Sin ese número tu depósito no se puede cruzar con el estado de cuenta, y una misma
          captura podría usarse dos veces.
        </span>
      </label>

      <label className="mt-3 block">
        <span className="text-xs font-bold text-tinta-suave">Monto que depositaste</span>
        <input
          value={monto}
          onChange={(e) => setMonto(e.target.value)}
          inputMode="decimal"
          className="num mt-1 w-full rounded-xl border border-linea bg-tarjeta px-3 py-2.5 text-sm text-tinta outline-sol focus:outline-2"
        />
        <span className="mt-1 block text-xs leading-relaxed text-tinta-suave">
          Viene con el monto pedido. Si depositaste otra cifra, corrígela: el pedido entra igual y
          SOCIO lo revisa a mano.
        </span>
      </label>

      <ol className="mt-4 flex flex-col gap-2">
        <Paso n="1" texto="Deposita el monto exacto. Es la primera huella que identifica tu pago." />
        <Paso
          n="2"
          texto="Sube la captura y el número de operación. Depósito declarado no es depósito validado: el pedido queda en validación."
        />
        <Paso n="3" texto="SOCIO lo cruza contra la cuenta. Confirmado el abono, la marca despacha." />
      </ol>

      {error ? (
        <p
          role="alert"
          className="mt-3 rounded-lg bg-alerta-bg px-3 py-2 text-sm font-semibold text-alerta"
        >
          {error}
        </p>
      ) : null}

      <motion.button
        type="button"
        whileHover={{ y: -2 }}
        whileTap={{ scale: 0.98 }}
        onClick={() => void confirmar()}
        disabled={enviando || cancelando}
        className="mt-4 flex w-full items-center justify-center gap-2 rounded-xl bg-sol px-4 py-3.5 font-titulo font-bold text-tinta disabled:opacity-60"
      >
        {enviando ? (
          <>
            <span className="h-5 w-5 animate-spin rounded-full border-2 border-tinta/30 border-t-tinta" />
            {paso}
          </>
        ) : (
          "Ya deposité — confirmar"
        )}
      </motion.button>

      <button
        type="button"
        onClick={() => void cancelar()}
        disabled={enviando || cancelando}
        className="mt-2 w-full rounded-xl px-4 py-3 text-sm font-bold text-tinta-suave transition-colors hover:text-alerta disabled:opacity-60"
      >
        {cancelando ? "Cancelando…" : "Todavía no deposité — cancelar el pedido"}
      </button>
    </motion.div>
  );
}

function Modo({
  activo,
  alTocar,
  icono,
  titulo,
  nota,
}: {
  activo: boolean;
  alTocar: () => void;
  icono: React.ReactNode;
  titulo: string;
  nota: string;
}) {
  return (
    <motion.button
      type="button"
      whileHover={{ y: -2 }}
      whileTap={{ scale: 0.97 }}
      onClick={alTocar}
      aria-pressed={activo}
      className={
        "rounded-xl border-2 p-3 text-center transition-colors " +
        (activo ? "border-sol bg-sol-bg" : "border-linea bg-tarjeta")
      }
    >
      {icono}
      <span className="mt-1 block text-sm font-bold text-tinta">{titulo}</span>
      <span className="block text-xs text-tinta-suave">{nota}</span>
    </motion.button>
  );
}

function Paso({ n, texto }: { n: string; texto: string }) {
  return (
    <li className="flex items-start gap-3 rounded-xl border border-linea bg-tarjeta px-3 py-2.5">
      <span className="num flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-sol-bg font-titulo text-xs font-black text-sol-osc">
        {n}
      </span>
      <span className="text-xs leading-relaxed text-tinta-suave">{texto}</span>
    </li>
  );
}
