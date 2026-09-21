/* Siluetas con brillo, para mientras la base contesta. Es mejor que una
   pantalla en blanco y mucho mejor que un "no hay nada", que afirmaría que la
   lista está vacía cuando todavía no se sabe.

   El brillo es una animación de CSS y no de framer-motion a propósito: son
   muchos elementos repetidos a la vez y no hay nada que interpolar por
   estado, así que dejarlo en el compositor del navegador sale más barato. */

function Barra({ ancho, alto = "h-3" }: { ancho: string; alto?: string }) {
  return (
    <div
      className={`relative overflow-hidden rounded bg-linea/70 ${alto} ${ancho} after:absolute after:inset-0 after:-translate-x-full after:animate-[brillo_1.4s_ease-in-out_infinite] after:bg-gradient-to-r after:from-transparent after:via-white/75 after:to-transparent`}
    />
  );
}

export function EsqueletoCatalogo({ cuantas = 6 }: { cuantas?: number }) {
  return (
    <div
      aria-busy="true"
      aria-label="Cargando el catálogo"
      className="mx-auto grid max-w-6xl grid-cols-1 gap-6 p-4 sm:grid-cols-2 lg:grid-cols-3"
    >
      {Array.from({ length: cuantas }, (_, i) => (
        <div key={i} className="rounded-2xl border border-linea bg-tarjeta p-4">
          <div className="mb-4 aspect-square">
            <Barra ancho="w-full" alto="h-full" />
          </div>
          <div className="flex flex-col gap-3">
            <Barra ancho="w-1/3" alto="h-2.5" />
            <Barra ancho="w-3/4" alto="h-4" />
            <Barra ancho="w-1/2" />
          </div>
        </div>
      ))}
    </div>
  );
}

export function EsqueletoSeguimiento() {
  return (
    <div
      aria-busy="true"
      aria-label="Cargando tus pedidos"
      className="mx-auto w-full max-w-2xl rounded-2xl border border-linea bg-tarjeta p-6"
    >
      <div className="flex flex-col gap-3">
        <Barra ancho="w-2/5" alto="h-4" />
        <Barra ancho="w-3/5" alto="h-2.5" />
      </div>
      <div className="my-8 flex justify-between">
        {Array.from({ length: 4 }, (_, i) => (
          <div key={i} className="flex flex-1 flex-col items-center gap-3">
            <Barra ancho="w-10" alto="h-10" />
            <Barra ancho="w-14" alto="h-2.5" />
          </div>
        ))}
      </div>
      <Barra ancho="w-full" alto="h-14" />
    </div>
  );
}
