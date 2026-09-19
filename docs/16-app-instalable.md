# 16 · La app instalable en el celular

*El socio vende desde el teléfono, en la calle y muchas veces con mala señal.
Esto hace que SOCIO se instale como una app y abra aunque no haya datos.*

---

## Qué es lo que se instala

**Solo la app del socio** (`app/vendedor.html`). Los paneles de la marca y de
SOCIO se usan sentado frente a una pantalla; la del socio se usa caminando.

Una app instalada tiene una sola identidad: un nombre, un icono y una pantalla
de inicio. Si el mismo manifiesto sirviera para los tres paneles, Android e iOS
no sabrían cuál abrir. Si en algún momento la marca quiere el suyo, es un
segundo manifiesto — pero son dos apps distintas, no una con tres puertas.

---

## El manifiesto que venía y por qué no funcionaba

El primer intento traía tres rutas absolutas:

```
"start_url": "/vendedor.html"
"src": "/icons/icon-192.png"
```

El sitio no vive en la raíz del dominio, vive en `…github.io/SOCIO-APP/`. Una
ruta que empieza por `/` se cuenta desde la raíz del dominio, así que esas dos
apuntaban a `github.io/vendedor.html` y `github.io/icons/…` — fuera del
proyecto, 404 las dos. Y `vendedor.html` además está dentro de `app/`.

Con rutas relativas, el navegador las resuelve desde donde está el manifiesto y
el problema desaparece. **El manifiesto vive en la raíz del proyecto, no en
`app/`:** el alcance de una app instalada no puede subir por encima de su
manifiesto, y desde `app/` no alcanzaría a la portada.

También venían `#111827` y `#ffffff`, que no son colores de SOCIO. Ahora usa los
de la paleta: `#14261E` de fondo de marca y `#F2F4EF` de arranque.

---

## Lo que ya estaba a medias

`vendedor.html` traía desde antes las etiquetas de PWA y un registro de service
worker, todos apuntando a archivos que nunca se crearon: `manifest.json`,
`icono-192.png`, `app/sw.js`. Por eso no pasaba nada al intentar instalarla: no
era que faltara el manifiesto, es que el que se pedía no existía. Quedó limpio.

---

## Los iconos

Cuatro archivos, dos de cada clase, y la distinción importa:

- **`any`** — el icono tal cual. Lo usan iOS y el escritorio.
- **`maskable`** — Android recorta el icono a la forma del fabricante (círculo,
  cuadrado redondeado, gota) y solo garantiza el 80% central. La versión
  *maskable* lleva la S más pequeña y el fondo hasta el borde. **Sin ella,
  Android mete el icono dentro de una cápsula blanca** y la app se ve como un
  acceso directo a una web, no como una app.

La marca es la S del logotipo con el punto en el amarillo de SOCIO.

---

## Sin señal

Un *service worker* guarda el armazón de la app —las páginas y los scripts— para
que abra sin datos.

**Lo que nunca se guarda es nada de Supabase.** Ni catálogo, ni precios, ni
pedidos, ni sesión. Un precio guardado de ayer es un socio cotizando mal; un
pedido guardado de ayer es un socio creyendo que registró una venta que no
existe. Con dinero de por medio, más vale un error de red visible que un dato
viejo invisible.

Las páginas van **por red primero** y solo caen a lo guardado si no hay señal.
Así una versión nueva llega sola la próxima vez que el socio abra con datos, en
vez de quedarse pegado a una copia vieja para siempre — que es el fallo clásico
de los service workers mal hechos.

### Al publicar una versión nueva

Si cambian las páginas o los scripts, hay que **subir `VERSION` en `sw.js`**
(`socio-v1` → `socio-v2`). Eso borra la caché anterior entera y fuerza a que se
vuelva a guardar todo. Si no se sube, un socio que ya tenía la app instalada
puede seguir viendo piezas de la versión anterior.

---

## Lo que falta para que sea una app de verdad

- **Avisar cuando no hay conexión.** Hoy la app abre sin señal, pero si el socio
  intenta registrar un pedido, la llamada a la base falla sin más. Tiene que
  decirlo claro, y no dejar que parezca que la venta quedó registrada.
- **Guardar el pedido para enviarlo al recuperar señal.** Es lo que de verdad
  quiere un vendedor en la calle. Pero es delicado: hay que decidir qué pasa si
  entre medias se acaba el stock o cambia el precio. Es una decisión de negocio.
- **Que se pueda instalar desde la portada.** Hoy hay que entrar a la app del
  socio para que el navegador ofrezca instalarla.
