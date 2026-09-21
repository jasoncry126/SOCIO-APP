import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/* La conexión sale de las variables de entorno de Vite (.env.local), que son
   los dos mismos valores que hoy viven en app/socio-config.js.

   La clave anon es pública por diseño: lo que impide que un socio lea el
   catálogo de otra marca, o los pedidos de otro socio, son las reglas por fila
   (RLS) de la base, no el secreto de esta clave. */
const URL_BASE: string = import.meta.env["VITE_SUPABASE_URL"] ?? "";
const CLAVE_ANON: string = import.meta.env["VITE_SUPABASE_ANON_KEY"] ?? "";

export const hayConexion: boolean = Boolean(URL_BASE && CLAVE_ANON);

let cliente: SupabaseClient | null = null;

/** Devuelve el cliente, o lanza un error legible si falta configurar. */
export function base(): SupabaseClient {
  if (!hayConexion) {
    throw new Error(
      "Falta configurar la conexión. Copia .env.example como .env.local y pega " +
        "el Project URL y la clave anon de tu proyecto Supabase.",
    );
  }
  if (!cliente) cliente = createClient(URL_BASE, CLAVE_ANON);
  return cliente;
}
