import { useState, type FormEvent } from "react";
import { motion } from "framer-motion";
import { LogIn, ShieldCheck } from "lucide-react";
import { ingresar } from "../datos/auth";
import type { Socio } from "../tipos";

interface Props {
  alEntrar: (socio: Socio) => void;
  /** Sin conexión configurada no se puede entrar: se dice y no se intenta. */
  hayConexion: boolean;
}

export function Ingreso({ alEntrar, hayConexion }: Props) {
  const [celular, setCelular] = useState("");
  const [clave, setClave] = useState("");
  const [error, setError] = useState("");
  const [entrando, setEntrando] = useState(false);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    setError("");

    if (!/^9\d{8}$/.test(celular)) {
      setError("El celular son nueve dígitos y empieza por 9.");
      return;
    }
    if (clave.length < 4) {
      setError("Tu clave tiene al menos cuatro dígitos.");
      return;
    }

    setEntrando(true);
    try {
      alEntrar(await ingresar(celular, clave));
    } catch (err) {
      setError(err instanceof Error ? err.message : "No se pudo entrar.");
    } finally {
      setEntrando(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-tinta p-4">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, ease: "easeOut" }}
        className="w-full max-w-sm"
      >
        <div className="mb-8 text-center">
          <span className="font-titulo text-4xl font-black tracking-wide text-fondo">
            S<span className="text-sol">O</span>CIO
          </span>
          <p className="mt-2 text-sm text-linea">Entra con el celular que registraste.</p>
        </div>

        <form
          onSubmit={enviar}
          className="rounded-2xl bg-fondo p-6 shadow-lg"
          aria-describedby={error ? "error-ingreso" : undefined}
        >
          <label className="block">
            <span className="text-xs font-bold text-tinta-suave">Celular</span>
            <input
              value={celular}
              onChange={(e) => setCelular(e.target.value)}
              inputMode="numeric"
              autoComplete="tel"
              placeholder="987654321"
              className="mt-1 w-full rounded-xl border border-linea bg-tarjeta px-3 py-2.5 text-tinta outline-sol focus:outline-2"
            />
          </label>

          <label className="mt-4 block">
            <span className="text-xs font-bold text-tinta-suave">Clave</span>
            <input
              value={clave}
              onChange={(e) => setClave(e.target.value)}
              type="password"
              inputMode="numeric"
              autoComplete="current-password"
              placeholder="••••"
              className="mt-1 w-full rounded-xl border border-linea bg-tarjeta px-3 py-2.5 text-tinta outline-sol focus:outline-2"
            />
          </label>

          {error ? (
            <p
              id="error-ingreso"
              role="alert"
              className="mt-3 rounded-lg bg-alerta-bg px-3 py-2 text-xs font-semibold text-alerta"
            >
              {error}
            </p>
          ) : null}

          <motion.button
            type="submit"
            whileHover={{ y: -2 }}
            whileTap={{ scale: 0.98 }}
            disabled={entrando || !hayConexion}
            className="mt-5 flex w-full items-center justify-center gap-2 rounded-xl bg-sol px-4 py-3 font-titulo font-bold text-tinta disabled:opacity-60"
          >
            {entrando ? (
              <span className="h-5 w-5 animate-spin rounded-full border-2 border-tinta/30 border-t-tinta" />
            ) : (
              <>
                <LogIn className="h-4 w-4" aria-hidden="true" /> Entrar
              </>
            )}
          </motion.button>

          {!hayConexion ? (
            <p className="mt-3 text-center text-xs text-tinta-suave">
              Falta configurar la conexión con la base. Copia <code>.env.example</code> como{" "}
              <code>.env.local</code> y pega tus datos de Supabase.
            </p>
          ) : null}

          <p className="mt-4 flex items-start gap-2 text-xs leading-relaxed text-tinta-suave">
            <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-ok" aria-hidden="true" />
            Tu nivel y tu descuento los decide la base según tus ventas entregadas. Esta pantalla no
            los calcula.
          </p>
        </form>
      </motion.div>
    </div>
  );
}
