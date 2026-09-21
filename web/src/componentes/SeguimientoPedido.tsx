import { motion } from "framer-motion";
import { CircleCheckBig, Receipt, ShieldCheck, Truck, XCircle } from "lucide-react";
import type { EstadoPedido, Pedido } from "../tipos";
import { soles } from "../precios";

/* ===========================================================================
   Seguimiento del pedido.

   IMPORTANTE, porque es fácil equivocarse aquí: en SOCIO **no hay custodia de
   pagos**. El socio le cobra a su cliente por fuera y le adelanta a la
   plataforma el precio de socio; su ganancia es lo que retuvo, no algo que la
   plataforma le pague después. La plataforma no retiene el dinero de nadie en
   garantía (es la Fase 1 de docs/02).

   Por eso ningún hito de abajo dice "en custodia" ni "fondos liberados":
   serían promesas que la plataforma no cumple, y el socio las leería como una
   garantía que no tiene. Los estados de custodia tampoco existen en la base.
   Si algún día se decide ese modelo, habrá que añadir estados nuevos en la
   base y hitos nuevos aquí — no basta con cambiar las etiquetas.
   =========================================================================== */

interface Hito {
  titulo: string;
  Icono: typeof Receipt;
}

const HITOS: readonly Hito[] = [
  { titulo: "Registrado", Icono: Receipt },
  { titulo: "Pago validado", Icono: ShieldCheck },
  { titulo: "Despachado", Icono: Truck },
  { titulo: "Entregado", Icono: CircleCheckBig },
] as const;

interface Avance {
  /** Cuántos hitos están cumplidos. */
  hechos: number;
  /** Índice del hito en curso; -1 cuando ya no queda ninguno. */
  enCurso: number;
}

/* El mapa está escrito como Record<EstadoPedido, …>: si mañana se añade un
   estado al tipo y alguien olvida ponerlo aquí, TypeScript no deja compilar.
   Esa es la mitad del valor de tener tipos en esta pantalla. */
const AVANCE: Record<EstadoPedido, Avance> = {
  pendiente_pago: { hechos: 1, enCurso: 1 },
  pagado: { hechos: 1, enCurso: 1 },
  validado: { hechos: 2, enCurso: 2 },
  en_camino: { hechos: 3, enCurso: 3 },
  entregado: { hechos: 4, enCurso: -1 },
  cancelado: { hechos: 0, enCurso: -1 },
};

const ETIQUETA: Record<EstadoPedido, { texto: string; clase: string }> = {
  pendiente_pago: { texto: "Pendiente de pago", clase: "bg-alerta-bg text-alerta" },
  pagado: { texto: "Pago en validación", clase: "bg-alerta-bg text-alerta" },
  validado: { texto: "Validado · la marca despacha", clase: "bg-info-bg text-info" },
  en_camino: { texto: "En camino", clase: "bg-info-bg text-info" },
  entregado: { texto: "Entregado", clase: "bg-ok-bg text-ok" },
  cancelado: { texto: "Cancelado", clase: "bg-alerta-bg text-alerta" },
};

const DETALLE: Record<EstadoPedido, string> = {
  pendiente_pago: "Falta que el pago entre. Hasta entonces la marca no prepara nada.",
  pagado: "Declaraste el pago y SOCIO lo está cruzando con el estado de cuenta.",
  validado: "El abono cuadró. La marca ya está preparando el paquete.",
  en_camino: "La marca registró la guía de envío y el paquete salió.",
  entregado: "Entrega confirmada. Esta venta ya cuenta para tu nivel.",
  cancelado: "Este pedido se anuló. No cuenta para tu nivel ni para tus ganancias.",
};

export function SeguimientoPedido({ pedido }: { pedido: Pedido }) {
  const avance = AVANCE[pedido.estado];
  const etiqueta = ETIQUETA[pedido.estado];
  const cancelado = pedido.estado === "cancelado";

  /* La misma cuenta del diseño: el primer hito es el 0 % y el último el 100 %. */
  const porcentaje = cancelado
    ? 0
    : ((avance.hechos - 1) / (HITOS.length - 1)) * 100;

  return (
    <div className="mx-auto w-full max-w-2xl rounded-2xl border border-linea bg-tarjeta p-6 shadow-sm">
      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h2 className="font-titulo text-lg font-bold text-tinta">
            Estado del pedido {pedido.codigo}
          </h2>
          <p className="text-xs text-tinta-suave">
            {pedido.destinatario} · {pedido.fecha}
            {pedido.numeroGuia ? ` · Guía ${pedido.numeroGuia}` : ""}
          </p>
        </div>
        <span
          className={"shrink-0 rounded-full px-3 py-1 text-xs font-bold " + etiqueta.clase}
        >
          {etiqueta.texto}
        </span>
      </div>

      {cancelado ? null : (
        <div className="relative my-8">
          {/* La pista va del centro del primer icono al del último: por eso se
              mete un octavo del ancho por cada lado (son cuatro columnas). */}
          <div className="absolute top-5 right-[12.5%] left-[12.5%] z-0 h-1 -translate-y-1/2 rounded bg-fondo" />
          <motion.div
            className="absolute top-5 left-[12.5%] z-0 h-1 origin-left -translate-y-1/2 rounded bg-ok"
            initial={{ width: "0%" }}
            animate={{ width: `${porcentaje * 0.75}%` }}
            transition={{ duration: 0.8, ease: "easeInOut" }}
          />

          <div className="relative z-10 flex justify-between">
            {HITOS.map((hito, i) => {
              const cumplido = i < avance.hechos;
              const enCurso = i === avance.enCurso;
              const Icono = hito.Icono;
              return (
                <div key={hito.titulo} className="flex flex-1 flex-col items-center">
                  <motion.div
                    initial={false}
                    animate={{
                      scale: enCurso ? 1.15 : 1,
                      backgroundColor: cumplido ? "#1e8a5a" : "#ffffff",
                      borderColor: cumplido ? "#1e8a5a" : enCurso ? "#efa51f" : "#dfe4dc",
                    }}
                    transition={{ duration: 0.3 }}
                    className="flex h-10 w-10 items-center justify-center rounded-full border-2 shadow-sm"
                  >
                    <Icono
                      className={
                        "h-5 w-5 " +
                        (cumplido ? "text-white" : enCurso ? "text-sol-osc" : "text-tinta-suave")
                      }
                      aria-hidden="true"
                    />
                  </motion.div>
                  <p
                    className={
                      "mt-3 max-w-[85px] text-center text-xs font-bold " +
                      (cumplido || enCurso ? "text-tinta" : "text-tinta-suave")
                    }
                  >
                    {hito.titulo}
                  </p>
                </div>
              );
            })}
          </div>
        </div>
      )}

      <motion.div
        key={pedido.estado}
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="mt-6 flex items-start gap-3 rounded-xl border border-linea bg-fondo p-4 text-sm text-tinta-suave"
      >
        {cancelado ? (
          <XCircle className="mt-0.5 h-5 w-5 shrink-0 text-alerta" aria-hidden="true" />
        ) : (
          <ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-ok" aria-hidden="true" />
        )}
        <p className="leading-relaxed">
          <strong className="text-tinta">{etiqueta.texto}:</strong> {DETALLE[pedido.estado]}
        </p>
      </motion.div>

      <div className="mt-4 flex items-baseline justify-between border-t border-linea pt-4">
        <span className="text-xs text-tinta-suave">
          Verificable en el sistema de control con tu código
        </span>
        <div className="text-right">
          <span className="num block font-titulo text-lg font-bold text-tinta">
            {soles(pedido.total)}
          </span>
          <span className="num text-xs font-bold text-chicha">
            Ganas {soles(pedido.ganancia)}
          </span>
        </div>
      </div>
    </div>
  );
}
