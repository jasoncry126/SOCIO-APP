# SOCIO · pantallas en React

Esta carpeta es la versión en React con TypeScript de tres pantallas de la app
del socio: el **catálogo**, el **detalle de producto** y el **seguimiento de
pedidos**. Convive con la app de hoy (`app/vendedor.html`), que sigue
funcionando igual: nada se apaga hasta decidir cuál se queda.

## Cómo arrancarla

```bash
cd web
npm install
cp .env.example .env.local     # y pega tu Project URL y tu clave anon
npm run dev                    # abre http://localhost:5173
```

Sin `.env.local` la app arranca igual, con datos de ejemplo, y lo dice en un
aviso arriba. Nunca mezcla datos inventados con los reales sin avisar.

| Comando             | Qué hace                                              |
| ------------------- | ----------------------------------------------------- |
| `npm run dev`       | Levanta el servidor de desarrollo con recarga en vivo |
| `npm run comprobar` | Revisa los tipos sin generar nada (`tsc --noEmit`)    |
| `npm run build`     | Revisa los tipos y empaqueta para publicar            |

## Qué hay dentro

```
src/
  tipos.ts                     Los tipos del dominio, sacados de la base
  precios.ts                   Niveles del socio y precio socio referencial
  datos/supabase.ts            La conexión, leída de .env.local
  datos/catalogo.ts            Lee la vista catalogo_publico
  datos/pedidos.ts             Lee la vista pedidos_socio
  datos/demostracion.ts        Datos de ejemplo para arrancar sin base
  componentes/
    CatalogoProductos.tsx      La cuadrícula, con entrada escalonada
    DetalleProducto.tsx        La ficha, con selector de presentación
    SeguimientoPedido.tsx      Los cuatro hitos y la barra de avance
    Esqueleto.tsx              Siluetas con brillo mientras carga
```

## Dos reglas del negocio que están escritas en el código

**El precio mayorista no existe de este lado.** El tipo `Variante` no tiene ese
campo, y no es un olvido: la vista `catalogo_publico` tampoco tiene esa columna.
El socio ve su precio de socio y el precio de página; lo que la marca cobra por
debajo no sale de la base (regla 1 de `CLAUDE.md`). Escrito en los tipos, nadie
puede pintar en pantalla un número que no puede tener.

**No hay custodia de pagos.** El seguimiento no dice "en custodia" ni "fondos
liberados" en ningún hito. En SOCIO el socio le cobra a su cliente por fuera y
le adelanta a la plataforma el precio de socio: la plataforma no retiene el
dinero de nadie en garantía. Los hitos van atados a los estados que la base sí
tiene, y el mapa está escrito como `Record<EstadoPedido, …>` para que añadir un
estado y olvidarse de este archivo no compile.

## Lo que todavía no está

- **No hay sesión iniciada.** Estas tres pantallas no incluyen el registro ni el
  ingreso, así que el nivel del socio se muestra como Bronce. Con sesión, el
  nivel lo trae la base según ventas entregadas (regla 5).
- **No hay fotos de producto.** La vista `catalogo_publico` no devuelve la URL
  de la imagen, así que las tarjetas usan el emoji de cada producto. Las fotos
  reales viven hoy en `app/imagenes/`.
- **Falta el resto del recorrido de venta**: carrito, datos de envío, pago y
  subida del comprobante siguen solo en `app/vendedor.html`.
