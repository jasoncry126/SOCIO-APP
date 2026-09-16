# Flujo de Dinero y Despacho — Cómo cerramos el hueco de confianza del proveedor

*Documento de trabajo · App de Revendedores · Agosto 2026*

---

## 1. El principio que resuelve todo: pedido pagado = pedido despachado

Diste en el clavo con la referencia de las apps de comida (Rappi, PedidosYa). Fíjate qué hacen exactamente: **el restaurante nunca entrega un plato sin que el dinero ya esté garantizado**. El cliente paga a la app *antes* de que se cocine nada, y la app le garantiza al restaurante su pago. El restaurante no confía en el repartidor ni en el cliente — confía en la app, porque la app ya tiene el dinero.

Ese es el diseño que adoptamos, convertido en una regla inquebrantable de la plataforma:

> **Ningún pedido llega al proveedor sin el pago ya confirmado en la plataforma. El proveedor despacha únicamente pedidos que ya están pagados.**

Con esa sola regla, el proveedor no arriesga ni su dinero ni su producto: cuando le llega la notificación de pedido, el dinero ya existe. Su única tarea es empaquetar y despachar con guía de envío. Y como él mismo despacha desde su almacén, **el producto nunca sale de sus manos hacia nadie que no sea el courier con destino al cliente final** — la seguridad del producto está resuelta por diseño: ni la plataforma ni el vendedor lo tocan jamás.

---

## 2. El precio "todo incluido", como las apps de comida

En el aplicativo de comida, el precio que ve el cliente ya trae adentro la ganancia de la app. Nosotros hacemos lo mismo, pero con una capa más (el vendedor). Todo precio final visible se compone así:

```
PRECIO FINAL AL CLIENTE
= Precio proveedor (lo que el proveedor definió recibir)
+ Comisión de la plataforma (nuestro valor agregado, % pequeño)
+ Margen del vendedor (él lo fija, dentro de un rango sugerido)
+ Costo de envío (tarifa por zona, visible por separado)
```

Cada actor conoce su número y nadie ve el de los demás donde no corresponde:

- **El proveedor** define su precio y recibe exactamente eso. No le importa (ni ve) cuánto ganó el vendedor.
- **El vendedor** ve el precio distribuidor (proveedor + comisión plataforma) dentro de la app, y decide su precio final. Su margen es la diferencia.
- **El cliente final** ve un solo precio total en la landing/comprobante. Nunca ve el precio distribuidor — así protegemos el sentido del vendedor (la lección de Meesho).
- **La plataforma** cobra su comisión ya incluida en el precio, automática en cada transacción, sin cobrarle "cuotas" a nadie.

---

## 3. Los tres flujos de cobro, por fases

No necesitamos construir todo el primer día. El principio "pagado antes de despachado" se cumple en tres versiones, de la más simple a la más completa:

### Fase 1 — El vendedor paga al subir el pedido (arranque, sin pasarela)

1. El vendedor cierra la venta por WhatsApp y **cobra a su cliente** (Yape/Plin/efectivo — como ya lo hace hoy).
2. Para registrar el pedido en la app, el vendedor **paga el precio distribuidor a la cuenta de la plataforma** (Yape/Plin/transferencia). Su ganancia ya quedó en su bolsillo: es la diferencia que retuvo.
3. La plataforma confirma el pago, **liquida al proveedor su precio** (reteniendo la comisión) y le envía el pedido con datos de despacho.
4. El proveedor despacha con guía; el tracking se registra en la app.

*El proveedor cobra antes de despachar. El riesgo restante vive entre vendedor y su cliente (el vendedor podría cobrar y no registrar el pedido) — se mitiga con validación de identidad, límites a vendedores nuevos y reputación. Es el flujo de lanzamiento porque no requiere pasarela ni licencias: solo cuentas bancarias ordenadas y las liquidaciones documentadas del modelo tributario.*

### Fase 2 — Link de pago al cliente (cobro centralizado, el modelo Rappi completo)

1. El vendedor arma el pedido en la app y esta genera un **link de pago a nombre de la plataforma** (pasarela tipo Culqi, Izipay, Mercado Pago — varias ofrecen "split payments" que reparten automáticamente entre las partes).
2. El **cliente paga directo a la plataforma** por el link. El vendedor nunca toca el dinero.
3. Pago confirmado → el proveedor recibe el pedido y despacha → la plataforma **liquida al proveedor al confirmar el despacho** (contra guía/tracking) y **acumula la comisión del vendedor para su pago semanal** a Yape/Plin.

*Aquí desaparece el fraude del vendedor, nacen los datos reales para los campos de calor, y aparece el "float" como ingreso (el dinero rinde mientras está en nuestras cuentas, como Meesho). Es la meta del primer año.*

### Fase 3 — Contraentrega (para el cliente que no paga sin ver)

La contraentrega es la más pedida en Perú y la más delicada, porque rompe la regla: el proveedor despacharía sin pago previo. Se ofrece solo bajo condiciones que le devuelvan la garantía:

- **Courier con recaudo:** operadores logísticos (Olva, Urbano y similares) ofrecen "pago contra entrega" donde **el courier cobra al cliente y remesa a la plataforma**. El proveedor sigue cobrando de la plataforma; el riesgo del rechazo se acota.
- **Quién asume el pedido rechazado:** si el cliente no recibe, el flete de ida y vuelta lo cubre un pequeño **fondo de contingencia** alimentado por un recargo a los pedidos contraentrega (S/ fijo por pedido). Regla clara en el contrato con cada proveedor desde el día uno — este punto es el mayor dolor de Meesho y no lo vamos a heredar.
- **Entrega local del propio proveedor:** si el cliente está en la misma ciudad del proveedor, este puede entregar directo y cobrar en mano; la app solo registra la venta y la comisión. Es la versión de menor riesgo de la contraentrega.
- **Filtros:** contraentrega disponible solo para clientes con historial o con un adelanto parcial (ej. paga el envío por adelantado, el resto al recibir) — el truco que usan las tiendas de Instagram serias en Perú.

---

## 4. Qué garantiza la plataforma a cada actor (resumen del contrato de confianza)

**Al proveedor:** dinero confirmado antes de despachar, liquidación contra evidencia de despacho, su producto nunca pasa por manos de terceros, contrato de comisión mercantil que documenta cada liquidación (esto además es lo que sostiene el modelo tributario del comisionista).

**Al vendedor:** precio distribuidor protegido (solo visible dentro de la app), comisión automática — retenida en Fase 1, depositada semanal en Fase 2 —, panel con sus números en tiempo real, y material de venta aprobado.

**Al cliente final:** comprobante de la compra, tracking del envío, y un canal de garantía gestionado por la plataforma con el proveedor (modelo Elenas) — el cliente reclama a un solo lugar y alguien responde siempre.

**A la plataforma:** comisión incluida en cada precio (nadie "decide" pagarnos: el flujo la retiene solo), datos de cada transacción, y flujos de dinero documentados que ante SUNAT demuestran qué es recaudación de terceros y qué es ingreso propio.

---

## 5. Casos de falla y su respuesta (diseñar para cuando algo sale mal)

| Falla | Respuesta del sistema |
|---|---|
| Cliente no paga | No existe pedido. Nada se despacha, nadie pierde. |
| Vendedor cobra y no registra el pedido (solo Fase 1) | Reclamo del cliente → vendedor suspendido, reputación pública, datos de identidad disponibles para denuncia. Incentivo estructural: migrar a Fase 2. |
| Proveedor no despacha en plazo | La plataforma retiene su liquidación, reembolsa al cliente/vendedor y el proveedor acumula strikes visibles en su reputación. |
| Cliente rechaza contraentrega | Fondo de contingencia cubre el flete; cliente pierde acceso a contraentrega futura. |
| Producto llega dañado / reclamo de garantía | La plataforma gestiona con el proveedor (cambio o reembolso); el vendedor no se involucra. |

---

## 6. Próximo paso

Con el circuito de dinero definido, lo que sigue es aterrizarlo en pantallas: el flujo de registro del vendedor, el catálogo con precio distribuidor, el armado del pedido con el desglose de precio, y los paneles de liquidaciones (proveedor) y comisiones (vendedor). Ese es el diseño del MVP en PWA — Fase 1 operativa, con la arquitectura lista para enchufar la pasarela de la Fase 2 sin rehacer nada.
