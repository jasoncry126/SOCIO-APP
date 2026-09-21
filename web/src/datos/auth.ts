import { base, hayConexion } from "./supabase";
import { esNivelId } from "../precios";
import type { NivelId, Socio } from "../tipos";

/* ===========================================================================
   Entrar con la cuenta del socio.

   El panel pide celular y clave, pero Supabase Auth trabaja con correo. Se
   arma uno interno a partir del celular, que el socio nunca ve ni escribe. Y
   como Supabase exige claves de seis caracteres y el panel acepta cuatro
   dígitos, se le añade un sufijo fijo: no cambia la fuerza de la clave, solo
   cumple el mínimo. Es la misma convención que usa la app de hoy — si no
   coincidiera, las cuentas creadas allí no podrían entrar aquí.
   =========================================================================== */

const DOMINIO_SOCIOS = "socios.socio.local";
const SUFIJO_CLAVE = "-socioapp";

function correoDe(celular: string): string {
  return celular.replace(/\D/g, "") + "@" + DOMINIO_SOCIOS;
}

function claveDe(clave: string): string {
  return clave + SUFIJO_CLAVE;
}

/* Lo que devuelve la tabla usuarios_socios. El nivel es lo importante: lo
   pone la base con su trigger cuando un pedido pasa a entregado (regla 5),
   y de él cuelga el descuento del socio. Nunca se calcula en la pantalla. */
interface FilaSocio {
  id: string;
  nombre: string;
  dni: string;
  celular: string;
  ciudad: string;
  validado: boolean | null;
  nivel: string | null;
  ventas_entregadas: number | string | null;
}

function comoSocio(f: FilaSocio): Socio {
  const nivel: NivelId = f.nivel && esNivelId(f.nivel) ? f.nivel : "bronce";
  return {
    id: f.id,
    nombre: f.nombre,
    dni: f.dni,
    celular: f.celular,
    ciudad: f.ciudad,
    validado: Boolean(f.validado),
    nivel,
    ventasEntregadas: Number(f.ventas_entregadas ?? 0),
  };
}

/** La ficha del socio que tiene la sesión abierta, o null si no hay ninguna. */
export async function socioActual(): Promise<Socio | null> {
  if (!hayConexion) return null;
  const sb = base();
  const sesion = await sb.auth.getSession();
  const usuario = sesion.data.session?.user;
  if (!usuario) return null;

  const res = await sb.from("usuarios_socios").select("*").eq("id", usuario.id).maybeSingle();
  if (res.error) throw new Error("No se pudo leer tu ficha: " + res.error.message);
  return res.data ? comoSocio(res.data as FilaSocio) : null;
}

export async function ingresar(celular: string, clave: string): Promise<Socio> {
  const sb = base();
  const r = await sb.auth.signInWithPassword({
    email: correoDe(celular),
    password: claveDe(clave),
  });
  if (r.error) {
    /* Se separa "no te reconozco" de "no pude preguntar". La base contesta
       400 cuando el celular o la clave no cuadran, y ahí se dice lo mismo
       para los dos casos a propósito: decir cuál de los dos falló le diría a
       un curioso qué celulares tienen cuenta. Cualquier otra cosa —sin
       internet, base caída— es un problema de conexión, y decirle al socio
       que su clave está mal cuando no lo está le hace cambiarla sin motivo. */
    if (r.error.status === 400) throw new Error("Celular o clave incorrectos.");
    throw new Error(
      "No se pudo conectar con SOCIO para revisar tus datos. Revisa tu internet e inténtalo de nuevo.",
    );
  }
  const socio = await socioActual();
  if (!socio) {
    throw new Error(
      "Entraste, pero tu cuenta no tiene ficha de socio. Escríbele a SOCIO para que la revise.",
    );
  }
  return socio;
}

export async function salir(): Promise<void> {
  if (!hayConexion) return;
  await base().auth.signOut();
}
