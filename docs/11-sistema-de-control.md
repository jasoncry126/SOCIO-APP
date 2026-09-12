# Sistema de Control SOCIO — Cómo controlamos todo el movimiento

*Documento de arquitectura operativa · Agosto 2026*

---

## 1. El principio que lo ordena todo: un solo registro maestro

La clave para no perder el control cuando la app del vendedor y el panel del proveedor se mueven a la vez es esta: **ninguno de los dos apartados tiene datos propios**. Todo movimiento — un carrito registrado, una constancia subida, un despacho con guía, una liquidación — es solo un **cambio de estado de un mismo registro: el pedido**, identificado por su código (`SOC-0818-K4T9`). El vendedor escribe el inicio de la historia, el proveedor escribe el final, y tú, desde el **panel administrador**, ves la historia completa de todos los pedidos a la vez.

Por eso el código de pedido que definimos no es un detalle estético: es la llave que amarra las tres vistas. Con un código en la mano puedes responder cualquier pregunta: ¿pagó?, ¿cuánto?, ¿quién vendió?, ¿qué marca despacha?, ¿dónde está el paquete?, ¿ya se liquidó?

## 2. El ciclo de vida del pedido (la máquina de estados)

Todo pedido atraviesa esta cadena, y **cada flecha queda registrada con fecha, hora y quién la movió** — esa bitácora es tu auditoría permanente:

```
REGISTRADO ──► PAGO DECLARADO ──► PAGO VALIDADO ──► EN DESPACHO ──► DESPACHADO ──► ENTREGADO ──► LIQUIDADO
 (vendedor      (QR detectado o     (tu sistema        (visible al     (proveedor      (courier         (jueves:
  arma el        constancia          de control          proveedor)      registra        confirma)        pago al
  carrito)       subida)             aprueba)                            la guía)                         proveedor)
```

Y los estados de excepción, que son donde el control demuestra su valor: **Rechazado** (el voucher no coincide con el monto o no existe el abono), **Vencido** (pedido registrado que nunca pagó — se libera el stock reservado), **En reclamo** (el cliente reportó un problema; congela la liquidación de ese pedido hasta resolverse) y **Reembolsado**.

La regla estructural que ya definimos vive aquí: el proveedor **solo ve pedidos desde "Pago validado"** — nunca antes. Todo lo anterior es territorio tuyo.

## 3. Los cinco tableros del panel administrador

**Tablero 1 — Cola de validación de pagos.** El corazón operativo del día a día. Lista de pedidos en "Pago declarado" esperando verificación: código, monto esperado, método (QR o depósito), la constancia subida, y dos botones — aprobar o rechazar con motivo. La verificación es un cruce de tres datos: **el monto exacto del pedido, el código, y el abono real en tu cuenta bancaria**. Con QR el cruce puede automatizarse (el QR lleva monto y código embebidos); con depósito lo haces tú mirando el extracto — estilo Binance, como lo planteaste: pago declarado no es pago validado.

**Tablero 2 — Monitoreo de pedidos.** Todos los pedidos de todas las marcas, filtrables por estado, con semáforo de plazos: si un pedido validado lleva más del tiempo de preparación declarado por el proveedor sin guía registrada, se pinta en alerta y sabes exactamente a qué marca reclamar antes de que reclame el cliente. Es tu radar de "nada se queda dormido".

**Tablero 3 — Dinero y conciliación.** Cuánto entró hoy/semana/mes, cuánto corresponde a cada proveedor en la liquidación del jueves, cuánto es comisión SOCIO, y la **conciliación**: cada sol del extracto bancario debe corresponder a un código de pedido, y cada pedido validado a un abono. Cuando esos dos totales cuadran, tu contabilidad está sana y las liquidaciones (con su detalle tipo boleta) salen solas — que además son el sustento del modelo tributario del comisionista.

**Tablero 4 — La red (personas y marcas).** El control de quiénes participan: vendedores con validación de identidad pendiente, su nivel y límite de pedidos, sus strikes; marcas por aprobar, productos "En revisión" esperando tu visto bueno, stock declarado vs pedidos. Aquí vives tu rol de árbitro: aprobar, suspender, subir de nivel.

**Tablero 5 — Alertas y anomalías.** Lo que no debe esperar a que lo busques: vendedor con varias constancias rechazadas (posible intento de fraude), montos que no cuadran, producto agotado que sigue recibiendo pedidos, reclamo abierto por más de 48 h, proveedor con despachos vencidos acumulados. Cada alerta enlaza al pedido o persona con un clic.

## 4. Los controles que trabajan solos (sin que tú mires)

El sistema se defiende automáticamente con reglas que ya definimos y aquí se conectan: el **monto exacto** como primera huella de validación; el **stock que se descuenta al validar el pago** y bloquea el contador en cero (ya está en el prototipo v3); el **límite de pedidos por nivel** del vendedor (un Bronce nuevo no puede meter 40 pedidos el primer día); el **plazo de despacho** que dispara alerta al vencerse; y la **bitácora inmutable**: nadie —ni tú— puede cambiar un estado sin que quede registrado quién y cuándo. Esa trazabilidad es la que te protege ante un reclamo, ante un proveedor que dice "nunca me avisaron", y ante SUNAT.

## 5. Lo que el control te regala de vuelta: los números del negocio

El mismo registro maestro que controla, mide. Sin trabajo extra obtienes: ventas por producto, marca y zona (**esta es la fuente de los campos de calor** que quieres mostrar a futuros vendedores y marcas), tiempo medio de validación y de despacho, tasa de pedidos rechazados/vencidos, socios activos por semana, ticket promedio y recompra. El día que le muestres a una marca tercera "así se mueve la red", los datos salen de aquí.

## 6. Cómo se implementa, por fases

**Piloto (semana 1):** el sistema de control puede ser una **hoja de cálculo bien diseñada** — una fila por pedido con su código y columnas por estado y fecha — más tu banca móvil para conciliar y WhatsApp para avisar al proveedor. Suena artesanal, pero si respeta la máquina de estados de la sección 2, *es* el sistema de control funcionando, y te enseña qué automatizar primero.

**Fase 1 (producto real):** el panel administrador web sobre la **misma base de datos** que la app del vendedor y el panel del proveedor — los cinco tableros de la sección 3. Como los estados ya están definidos desde el piloto, migrar es trasladar, no rediseñar.

**Fase 2:** automatizaciones — validación automática de QR contra el banco, alertas por WhatsApp/notificación, liquidaciones con transferencia programada.

---

**Siguiente pieza sugerida:** el prototipo del panel administrador con los tableros 1 y 2 (cola de validación con aprobar/rechazar constancias, y monitoreo de pedidos con semáforo de plazos) — es la vista que cierra el triángulo vendedor–proveedor–administración y con la que puedes ensayar tu operación diaria antes de construir nada.
