# SOCIO · pantallas en React

Esta carpeta es la versión en React con TypeScript de la app del socio, con el
recorrido de venta entero: **ingreso**, **catálogo**, **ficha de producto**,
**carrito**, **datos de envío**, **depósito con su captura** y **seguimiento de
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

Y la prueba de navegador, que recorre la venta entera en Chromium con los datos
de ejemplo (no toca ningún Supabase):

```bash
node web/pruebas/probar-recorrido-en-navegador.cjs
```

## Qué hay dentro

```
src/
  tipos.ts                     Los tipos del dominio, sacados de la base
  precios.ts                   Niveles del socio y precio socio referencial
  datos/supabase.ts            La conexión, leída de .env.local
  datos/catalogo.ts            Lee la vista catalogo_publico
  datos/pedidos.ts             Lee, crea y paga pedidos
  datos/auth.ts                Entrar con celular y clave (Supabase Auth)
  datos/cuenta-socio.ts        A dónde deposita el socio  ← EDITAR ANTES DE VENDER
  datos/demostracion.ts        Datos de ejemplo para arrancar sin base
  carrito.ts                   El carrito: una marca, un origen, su stock
  envios.ts                    Orígenes de la marca, agencias y tarifas
  componentes/
    Ingreso.tsx                Celular y clave
    CatalogoProductos.tsx      La cuadrícula, con entrada escalonada
    Foto.tsx                   La foto del producto, con el emoji de respaldo
    DetalleProducto.tsx        La ficha, el precio socio y agregar al pedido
    Checkout.tsx               Quién recibe, cómo se entrega y la cuenta
    PagoDeposito.tsx           El monto exacto y la captura del depósito
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

**Primero se registra el pedido, después se cobra.** El monto a depositar lleva
unos céntimos que identifican ese pedido y ningún otro en el extracto del día, y
esos céntimos se derivan del código del pedido, que no existe hasta que el
pedido está en la base. Por eso el botón del checkout dice "Registrar pedido y
ver cuánto depositar" y la pantalla del depósito viene después, nunca antes.

**El nivel del socio no se calcula aquí.** Se lee de su ficha en la base, que lo
mueve según ventas entregadas (regla 5). La app lo usa solo para enseñar precios
referenciales; el precio que se cobra lo calcula `crear_pedido()` leyendo el
catálogo y el nivel. Del carrito a la base viajan presentaciones y cantidades,
ningún precio.

## Las fotos de producto

Las trae la base: cada presentación guarda la ruta de su foto dentro del cubo
público `catalogo` (`<marca_id>/archivo.webp`), y la pantalla arma la URL al
pintar. Una presentación sin foto enseña el emoji del producto — que es lo que
ve una marca recién dada de alta, y no un hueco gris.

Para poner en la base las 63 fotos que ya están en `app/imagenes/`:

```bash
cd web
node ../supabase/datos/subir-fotos.mjs --celular 9XXXXXXXX --clave XXXX --seco
node ../supabase/datos/subir-fotos.mjs --celular 9XXXXXXXX --clave XXXX
```

Son el celular y la clave de la MARCA, los mismos de `app/proveedor.html`. Con
`--seco` no sube nada: solo dice qué haría. De ahí en adelante cada marca sube
las suyas desde su panel, en la columna «Foto» de su catálogo.

## Lo que hace falta de la base

El recorrido se apoya en lo que ya está en `main` —`crear_pedido()`,
`declarar_pago()` y la vista `catalogo_publico`— salvo tres cosas que llegan con
la migración del depósito y su captura (`20260921140000`):

- el **cubo `vouchers`** de Supabase Storage, sin el cual la captura no se puede
  subir;
- las columnas `monto_a_pagar` y `pago_*` de la vista `pedidos_socio` (mientras
  falten, el monto del pedido recién registrado se toma de lo que devolvió
  `crear_pedido()`, que es el mismo número);
- `cancelar_pedido_sin_pagar()`, que libera el stock de un pedido que no se pagó.

Y de la migración de las fotos (`20260921160000`), que va en este mismo cambio:
la columna `presentaciones.imagen` y el cubo `catalogo`.

## Lo que todavía no está

- **No hay registro de socios nuevos**, solo ingreso. Quien no tenga cuenta la
  crea hoy en `app/vendedor.html`.
- **La cuenta de SOCIO es de relleno.** Está en `src/datos/cuenta-socio.ts` y la
  pantalla del depósito lo advierte mientras siga marcada como tal.
