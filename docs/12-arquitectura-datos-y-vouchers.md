# SOCIO — Dónde vive la información y cómo se validan los pagos

*Arquitectura de datos y control de vouchers · Agosto 2026*

---

## Parte 1 · Dónde vive la información

### El problema de hoy

Los tres paneles guardan todo en el **navegador del propio dispositivo** (localStorage). Eso significa que si un socio registra un pedido en su celular, ese pedido **no existe** para el proveedor ni para ti. Cada quien tiene su propia realidad aislada. Funciona perfecto para probar la interfaz —que es para lo que sirvió— pero es imposible operar así con dinero real.

Necesitas una **base de datos central** donde todos escriban y lean lo mismo.

### Qué debe guardarse

| Tipo de dato | Ejemplos | Sensibilidad |
|---|---|---|
| Cuentas | Socios, marcas, administradores | Alta — datos personales |
| Catálogo | Productos, presentaciones, precios, stock | Media — precios mayoristas son confidenciales |
| Pedidos | Ítems, montos, destinatario, dirección, estado | Alta — datos del cliente final |
| Pagos | Voucher, número de operación, validación | Crítica |
| Dinero | Liberaciones, retiros, comisiones | Crítica |
| Trazabilidad | Quién hizo qué y cuándo | Crítica — es tu defensa ante un reclamo |

Un punto que suele pasarse por alto: **la bitácora es tan importante como los datos.** Cuando un socio reclame "yo sí pagué" o un proveedor diga "yo sí despaché", lo único que te salva es un registro con hora exacta de cada acción, que nadie pueda editar hacia atrás.

### Opciones reales

**Supabase** — Postgres administrado con autenticación, almacenamiento de archivos y permisos por fila incluidos. Plan gratuito suficiente para el piloto; alrededor de USD 25/mes cuando crezcas. Es SQL de verdad, así que las reglas de dinero se hacen cumplir en la base misma (por ejemplo, "no puede existir dos veces el mismo número de operación"). **Es lo que recomiendo.**

**Firebase** — más simple de arrancar, pero al no ser relacional obliga a programar a mano las validaciones que Postgres te da gratis. Para algo con dinero de por medio, esa diferencia importa.

**Servidor propio (VPS)** — más control y más barato a gran escala, pero tú te encargas de respaldos, seguridad y actualizaciones. No lo recomiendo mientras seas equipo chico.

### El control clave: cada quien ve solo lo suyo

Con Supabase se define a nivel de base de datos que **un socio solo puede leer sus propios pedidos** y **una marca solo los pedidos de sus productos**. Esto no es una preferencia de diseño: si esa regla vive solo en la interfaz, cualquiera con conocimientos básicos puede saltársela y ver los precios mayoristas de todas las marcas. Con permisos por fila, la base misma rechaza la consulta.

---

## Parte 2 · El problema de los vouchers

### La verdad incómoda

**Una imagen de voucher no prueba nada.** Se edita en dos minutos con el celular, se reenvía la de otra compra, o se manda la misma captura para tres pedidos distintos. Cualquier sistema que dependa de que un humano "mire si se ve legítimo" va a fallar — no por descuido, sino porque es imposible distinguir a ojo.

La solución no es revisar mejor la imagen. Es **dejar de usar la imagen como prueba** y cruzarla contra el movimiento real de tu cuenta.

### Tres capas de control

**Capa 1 — Número de operación único (esto resuelve el 90% del problema)**

Cada Yape, Plin o transferencia genera un número de operación. Al registrar el pago, el socio lo escribe obligatoriamente, y la base de datos lo guarda con una regla: **ese número no puede repetirse jamás**. Si alguien intenta usar el mismo voucher para un segundo pedido, la base lo rechaza sola, sin que nadie tenga que darse cuenta.

Es una línea de código en Postgres y es tu control más poderoso. Ningún voucher reutilizado pasa.

**Capa 2 — Monto único por pedido**

Este truco es simple y elegante: en lugar de pedir S/ 158.00 exactos, el sistema pide **S/ 158.37** — con céntimos generados a partir del código del pedido. Como es prácticamente imposible que dos pedidos del mismo día tengan el mismo monto, al mirar tu estado de cuenta cada depósito se identifica solo: ese S/ 158.37 corresponde inequívocamente a ese pedido.

Muchos negocios en Perú lo usan justamente porque Yape y Plin no ofrecen confirmación automática para comercios pequeños.

**Capa 3 — Cruce contra el movimiento real**

El voucher dice lo que el socio quiere que diga; tu estado de cuenta dice la verdad. Dos formas de cruzarlo:

- **Manual asistido (para el piloto):** exportas el movimiento del día desde la banca por internet y lo cargas en el panel de control. El sistema compara monto, fecha y número de operación, y marca en verde los que cuadran. Tú solo revisas las excepciones — normalmente dos o tres al día, no cincuenta.
- **Automático (cuando crezcas):** una pasarela de pagos peruana (Izipay, Culqi, Niubiz, Mercado Pago) confirma cada cobro al instante y **elimina el voucher por completo**. Cuesta entre 3.5% y 4.5% por transacción más IGV. Ese costo se compara contra el tiempo que hoy gastas validando y contra el riesgo de un fraude que se te cuele.

### Controles complementarios

- **Huella de la imagen:** guardar una firma digital del archivo detecta si alguien sube exactamente la misma foto dos veces, incluso con otro número escrito.
- **Lectura automática (OCR):** extraer monto, fecha y operación de la imagen para compararlos con lo declarado. Útil para detectar inconsistencias — pero nunca como prueba única, porque la imagen misma puede estar alterada.
- **Ventana de tiempo:** si el voucher tiene fecha de hace cinco días y el pedido se creó hoy, se marca para revisión.
- **Historial del socio:** un socio con tres intentos rechazados entra en revisión manual automática.

### Un principio que conviene grabar

**El pedido no avanza por lo que dice el voucher, sino por lo que dice tu cuenta.** El voucher sirve para que el socio te diga *dónde buscar* el pago; la confirmación viene siempre del movimiento real. Mientras mantengas esa regla, el fraude por imagen deja de ser un riesgo estructural.

---

## Parte 3 · Mi recomendación por etapas

**Piloto (ahora):** Supabase con permisos por fila + número de operación único + monto con céntimos únicos + carga manual del extracto bancario para el cruce. Con esto operas con seguridad real desde el primer día, a costo casi cero.

**Cuando pases de unos 100 pedidos al mes:** pasarela de pagos. El voucher desaparece, la validación es instantánea y el pedido llega a la marca sin que nadie intervenga. Ahí el 4% se paga solo.

**Siempre:** bitácora inmutable de cada cambio de estado y una copia de respaldo diaria. Cuando haya un reclamo —y va a haberlo— esa bitácora es la diferencia entre resolverlo en cinco minutos y perder al socio o a la marca.

---

Si quieres, el siguiente paso concreto es diseñar el **modelo de datos completo** (las tablas, sus relaciones y las reglas de permisos) para que sirva de plano al momento de construir el backend. También puedo dejarte el panel de control preparado para la carga del extracto y el cruce automático de pagos.
