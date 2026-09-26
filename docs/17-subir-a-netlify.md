# Subir SOCIO a Netlify y dejarlo listo para hacer ventas de prueba

*Septiembre de 2026 · hoja de ruta, en orden. Cada paso supone el anterior hecho.*

---

## Los dos archivos que te llegan

| Archivo | Qué es | Dónde va |
|---|---|---|
| `socio-netlify.zip` | El sitio entero: portada, las tres pantallas, fotos e íconos. | Se arrastra a Netlify, sin descomprimir. |
| `socio-sql-para-supabase.zip` | Las quince migraciones numeradas, el comprobador, el reinstalador de un solo archivo y el catálogo de prueba. | Se descomprime y se pega en el SQL Editor de Supabase. |

---

## Lo que vas a tener al final

Una dirección tipo `socio-piloto.netlify.app` que abre la portada con los tres
paneles. Desde el celular, con «Agregar a pantalla de inicio», queda como una app.
Y detrás, tu Supabase con un catálogo de prueba cargado, para que puedas registrar
ventas de mentira de punta a punta: el socio compra, tú validas el depósito, la
marca despacha, el socio confirma la entrega y el dinero se libera.

**Una advertencia que hay que decir una vez:** la clave pública de Supabase viaja
dentro de la página, así que cualquiera que abra el sitio puede leerla. Está
diseñado así — es lo que hace que los permisos por fila de la base sean la
defensa de verdad y no el secreto de la clave. Mientras el piloto sea privado,
usa un nombre de sitio poco obvio.

---

## Paso 1 · Deja la base lista (antes de subir nada)

El sitio va a arrancar hablando con tu Supabase. Si la base no está al día, las
pantallas abren pero no puedes hacer nada. Tres cosas, en este orden:

### 1.1 · Aplicar las cinco migraciones que faltan

Descomprime `socio-sql-para-supabase.zip`. Dentro están las quince migraciones
numeradas `01-` a `15-`: el número es el orden en que se pegan, y ese orden
importa porque cada una se apoya en la anterior.

**Empieza por `00-EMPIEZA-AQUI-que-falta.sql`.** En tu proyecto de supabase.com →
**SQL Editor** → **New query**, lo pegas entero y **Run**. No cambia nada, solo
mira. Lo primero que sale es la lista de las quince, diciendo cuáles ya están
aplicadas y cuáles no:

```
 1 | 20260912000000_modelo_de_datos_inicial | ✅ aplicada
 …
 7 | 20260917100000_circuito_de_venta       | ❌ falta
```

Ahí ves exactamente por dónde seguir. Aplicas las que salgan ❌, **en orden**,
una por una: abres el archivo, copias todo, pegas, **Run**. Y cuando termines,
vuelves a correr el `00-` para confirmar que quedaron las quince en ✅.

Cada archivo es una sola transacción: si algo falla, no queda nada a medias y la
base se queda como estaba. Si sale un error que dice que algo «already exists»,
esa migración ya estaba aplicada: pasa a la siguiente.

> **Si al pegar el `00-` sale «syntax error», no es el archivo: es que se ejecutó
> solo un trozo.** Son 600 líneas, y el SQL Editor corre únicamente lo que esté
> seleccionado. Vacía el editor, pega otra vez y pulsa Run sin nada seleccionado.
> O usa `00-LISTA-CORTA-de-migraciones.sql`, que es la misma lista de las quince
> en una sola consulta que cabe de un vistazo.

> **Saltarse una migración anterior no da error al aplicar las siguientes**, pero
> deja la base a medias de una forma que solo se nota cuando falla una venta.
> Por eso el `00-` va primero: es la única manera de ver el hueco antes de
> tropezarse con él.

### El atajo: reinstalar todo de cero

Si la base quedó desordenada —migraciones aplicadas salteadas o fuera de orden—
y todavía no hay nada dentro que duela perder, esto es más corto y más seguro
que ir tapando agujeros: pega `REINSTALAR-TODO-DE-CERO.sql` entero y pulsa Run.
Borra las once tablas y vuelve a aplicar las quince migraciones seguidas, en
orden, en una sola pasada. Tarda un poco.

**Lo que se pierde:** todo lo registrado —socios, marcas, catálogo, pedidos,
pagos—. Si alguien ya usó las páginas de verdad, eso desaparece y no se puede
deshacer.

**Lo que no se pierde:** las cuentas de Authentication, y los archivos ya
subidos a los cubos. Lo único que hay que rehacer a mano después es la fila de
la tabla `administradores` con tu User UID.

Al terminar, corre el `00-` y tienen que salir las quince en ✅.

### Si el `00-` te dice que hay un HUECO

Es el caso de una migración sin aplicar con otras posteriores ya puestas. Tiene
una trampa al repararlo, y conviene entenderla porque no es evidente: **varias
migraciones reescriben enteras las mismas funciones.** Si aplicas ahora la que
faltaba, su versión —más antigua— pisa la que dejó una posterior, y pierdes lo
que aquella arreglaba sin que nada te avise.

La regla, entonces: aplicas la que falta y **vuelves a aplicar, en orden, todas
las de detrás hasta la 15ª**. Reaplicar una que ya tenías no rompe nada. El
propio `00-` te lo dice con el número exacto cuando detecta el hueco, y al
terminar lo corres otra vez para confirmar que quedó todo en ✅.

### 1.2 · Crear tu cuenta de administrador

El panel de SOCIO es el que valida los depósitos. Nadie se nombra administrador
solo: se hace desde el tablero de Supabase.

1. **Authentication → Users → Add user**. Pon un correo y una clave tuyos. Anótalos.
2. Copia el **User UID** que queda en la lista.
3. En el SQL Editor:

```sql
insert into administradores (id, nombre)
values ('PEGA-AQUI-EL-USER-UID', 'Jason');
```

Con ese correo y esa clave entras a `app/administrador.html`.

### 1.3 · Poner tus datos de cobro

Hoy la app enseña una cuenta de relleno. Mientras sean pruebas da igual, pero en
cuanto entre un socio de verdad va a depositar a donde diga ahí. Está en
`app/vendedor.html`, cerca de la línea 921:

```
Cuenta SOCIO — BCP Soles
193-XXXXXXX-0-XX · CCI 002-193-XXXXXXXXXX
Titular: SOCIO SAC
```

Y el QR de Yape de la pantalla de al lado también es de mentira: es un dibujo, no
un código que escanee. Para pruebas no molesta; para vender, hay que reemplazarlo
por el tuyo.

---

## Paso 2 · Sube el sitio a Netlify

1. Entra a [app.netlify.com](https://app.netlify.com) con tu cuenta (la misma de
   `labpeptprotocolos.netlify.app` sirve).
2. **Add new site → Deploy manually**.
3. Arrastra el zip **`socio-netlify.zip`** al recuadro. No lo descomprimas: suéltalo tal cual.
4. En segundos tienes una dirección tipo `random-nombre-123.netlify.app`.
5. **Site configuration → Change site name** para ponerle el nombre que quieras.

Abre la dirección: tiene que salir la portada de SOCIO con los tres paneles.

### Cómo sabes en qué modo arrancó

Esto es lo importante. El sitio funciona de dos maneras según encuentre o no la
conexión a la base:

- **Conectado.** Entras a la app del socio y te pide **celular y clave** para
  ingresar o registrarte. El catálogo sale de tu Supabase.
- **Demostración.** La pantalla avisa que está en modo de prueba, el catálogo son
  los 47 productos de Lab Péptidos escritos dentro de la página, y todo lo que
  hagas se guarda solo en ese navegador. Nadie más lo ve.

El zip ya viene con tu proyecto configurado, así que debería arrancar conectado.
Si arranca en demostración, es que `app/socio-config.js` quedó vacío. Se arregla
abriendo ese archivo y pegando los dos datos que salen de tu proyecto en
**Settings → API**:

```js
window.SOCIO_CONFIG = {
  URL:  "https://xxxxxxxx.supabase.co",
  ANON: "la clave larga que dice anon / publishable"
};
```

Nunca pongas ahí la clave `service_role` ni la contraseña de la base: esa página
es pública y esas dos sí dan acceso total.

### Actualizar el sitio más adelante

Mismo sitio → **Deploys** → arrastra el zip nuevo. La dirección no cambia.

---

## Paso 3 · Carga datos de prueba para poder vender

Una base recién puesta está vacía: no hay marcas, no hay catálogo, y un socio que
entre no ve nada que comprar. Se llena así.

### 3.1 · Registra una marca de prueba

Abre `tu-sitio.netlify.app/app/proveedor.html` y regístrala. Pide RUC, giro,
ciudad de almacén, celular y clave. **Anota el celular**, hace falta en el
siguiente paso. Usa un celular que no sea el real, para distinguirla después.

### 3.2 · Cuélgale un catálogo de prueba

En el SQL Editor de Supabase pega el archivo `99-datos-de-prueba.sql`, cambia el
celular de la línea marcada por el que acabas de registrar, y **Run**.

Te deja seis productos en tres categorías, con doce presentaciones, ya aprobados
y con stock en almacén y en punto de venta. Son de rubros cualquiera a propósito
—cuidado personal, accesorios, hogar— porque lo que se está probando es el
mecanismo de SOCIO, no el catálogo de una marca. Todos llevan «(prueba)» en el
nombre y el mismo archivo trae, al final, las dos líneas para borrarlos.

Correrlo dos veces no duplica nada: limpia lo suyo antes de volver a insertar.

> **Si prefieres cargar tu catálogo de verdad:** el panel de la marca tiene carga
> masiva desde Excel. Pero ojo con lo que ya sabíamos: los productos entran «en
> revisión» y no se ven hasta que los apruebes desde el panel de SOCIO, y los que
> no tengan precio mayorista no se pueden publicar.

### 3.3 · Registra un socio de prueba

Abre `tu-sitio.netlify.app/app/vendedor.html` y regístrate como socio. DNI,
celular y clave. Ese socio entra en Bronce (10% de descuento sobre el precio de
página) y sube solo con las entregas confirmadas.

---

## Paso 4 · Haz una venta de prueba entera

Con lo anterior hecho, el recorrido completo son cinco momentos. Conviene hacerlo
una vez con tres pestañas abiertas para verlo pasar:

| # | Quién | Dónde | Qué hace |
|---|---|---|---|
| 1 | El socio | `app/vendedor.html` | Arma el pedido, pone los datos de quien recibe, elige agencia o domicilio y registra. El stock queda apartado. |
| 2 | El socio | la misma pantalla | Ve el monto exacto (con céntimos únicos, para que se pueda cruzar), y sube la captura del depósito con su número de operación. |
| 3 | **Tú** | `app/administrador.html` | En la cola de validación ves el depósito y su captura. Lo validas. El pedido pasa a «validado» y recién ahí le aparece a la marca. |
| 4 | La marca | `app/proveedor.html` | Ve el pedido, registra la guía de envío con su foto. Eso le libera el 70% de su dinero. |
| 5 | El socio | `app/vendedor.html` | Pulsa «ya le llegó a mi cliente». Eso cierra la venta, suma su venta entregada y libera el 30% que faltaba. |

Para pruebas no necesitas depositar nada de verdad: en el paso 2 sube cualquier
imagen e inventa el número de operación. La base solo exige que ese número no se
haya usado antes, así que usa uno distinto en cada prueba.

Si quieres ver subir de nivel al socio sin hacer diez ventas, lo honesto es
hacerlas: el nivel se calcula con entregas confirmadas y es la base quien lo
manda, no la app. No hay atajo por pantalla y así debe seguir siendo.

---

## Lo que NO va a funcionar todavía, y no es un error

- **El panel de SOCIO tiene tableros de demostración.** La validación de pagos y
  la contabilidad leen de la base; el resto de sus tableros todavía enseña datos
  de ejemplo.
- **No hay pasarela de pago.** El cobro es confirmación de depósito con captura,
  como quedó decidido. No hay contra entrega.
- **El selector de ciudades sigue fijo en Cusco y Lima** en la app de hoy. Ya está
  resuelto en la versión nueva en React, pero esa no es la que va en este zip.
- **La app de React (`web/`) no va en este paquete.** Es una segunda app del
  socio, más nueva, que convive con esta. Necesita compilarse antes de subir, así
  que si quieres probarla también en Netlify hay que armar un paquete aparte.

---

## Qué lleva el zip, y qué no

Lleva: la portada, las tres pantallas, sus scripts, las 64 fotos del catálogo de
la marca piloto, los íconos, el manifiesto que la hace instalable y el service
worker que la abre sin señal.

No lleva: la documentación, las migraciones de la base, las pruebas ni el
historial de git. Nada de eso tiene por qué estar publicado.

Para rearmar los dos paquetes cuando cambie algo, desde el repositorio:

```bash
bash herramientas/armar-zip-netlify.sh       # deja los dos zip en dist/
node app/pruebas/probar-paquete-netlify.js   # abre el paquete en Chromium y lo comprueba
```
