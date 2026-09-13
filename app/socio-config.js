/* ===========================================================================
   SOCIO · Conexión con Supabase
   ---------------------------------------------------------------------------
   Los dos datos de abajo salen de tu proyecto en supabase.com:

       Settings  →  API

       URL       →  Project URL        (https://xxxxxxxx.supabase.co)
       ANON      →  anon public        (la clave larga que dice "anon")

   Las dos son públicas por diseño: viajan dentro de esta página y cualquiera
   que la abra puede verlas. Lo que impide que sirvan para leerlo todo son los
   permisos por fila de la base (supabase/migrations).

   NUNCA pongas aquí la clave "service_role" ni la contraseña de la base de
   datos. Esas sí dan acceso total y esta página es pública.
   =========================================================================== */

window.SOCIO_CONFIG = {
  URL:  "https://oxlqiiumtsyzrhygsrzt.supabase.co",
  ANON: ""    // ← pega aquí tu clave anon public (Settings → API → "anon public")
};
