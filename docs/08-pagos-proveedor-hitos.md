# SOCIO — Cuándo cobra el proveedor

*Esquema de liberación de pagos por hitos · Agosto 2026*

---

## El problema real

Tienes razón en el diagnóstico: un mayorista está acostumbrado a cobrar **antes** de despachar. Pedirle que espere hasta el jueves siguiente es pedirle que financie tu operación con su capital de trabajo — y es la primera razón por la que una marca dice "mejor no". Para muchos proveedores, siete días de espera son más caros que la comisión que cobras.

Pero hay un límite que no se puede cruzar: **el dinero no puede salir antes de que el paquete salga.** Si SOCIO paga contra pedido registrado, cualquier proveedor podría cobrar sin despachar, y quien queda expuesto es el vendedor —que ya le cobró a su cliente— y tu marca, que es la que da la cara. El cliente no le compró al distribuidor: le compró a la app.

La solución no es esperar menos por calendario, sino **dejar de pagar por calendario y empezar a pagar por hitos**.

---

## El esquema: pago por hito, no por semana

En lugar de un corte semanal, cada pedido libera su dinero cuando cruza un hito verificable:

| Momento | Qué se libera | Cuándo llega al proveedor |
|---|---|---|
| Pago validado por SOCIO | — | El pedido entra a su bandeja |
| **Guía registrada** (paquete en camino) | **70%** | En el día, hasta 4 horas |
| **Entrega confirmada** | **30% restante** | Mismo día de la confirmación |

**Entrega local en la misma ciudad:** como se entrega el mismo día, el proveedor cobra el **100% el mismo día**. Solo tiene que registrar la entrega y esa es la única espera.

**Envío nacional:** cobra el 70% apenas registra la guía —es decir, el mismo día que despacha— y el 30% cuando la agencia confirma la entrega, entre 2 y 5 días después. En la práctica, **cobra el grueso el mismo día**, que es exactamente lo que un mayorista espera.

Ese 30% retenido no es un castigo: es lo que permite responder si el paquete se pierde, llega roto o nunca se despachó realmente. Es también el argumento con el que el vendedor confía en la plataforma.

---

## El mensaje al proveedor (así se lo explicas)

> **Tu dinero se libera cuando el pedido llega.**
> Cobras el 70% apenas registras la guía —el mismo día que despachas— y el resto cuando se confirma la entrega. En entregas locales cobras el 100% el mismo día.
>
> Retenemos esa parte porque el cliente no te compró a ti: le compró a SOCIO, y el vendedor ya le cobró. La confirmación de entrega es la única prueba que tenemos —tú, el vendedor y nosotros— de que el pedido llegó bien. Es lo que hace que la red confíe en tu marca y siga vendiéndola.

Ese último párrafo importa: no lo presentes como una condición que le impones, sino como la razón por la que su producto se vende sin que él tenga que perseguir a nadie.

---

## Niveles de fiabilidad del proveedor

Igual que los socios suben de nivel vendiendo, las marcas deberían subir **cumpliendo**. Esto premia al que despacha bien y protege a la plataforma del que recién entra:

| Nivel | Se alcanza con | Cómo cobra |
|---|---|---|
| 🌱 **Nueva** | Al registrarse | 100% contra entrega confirmada |
| ✅ **Confiable** | 20 entregas sin incidencias | 70% al registrar guía · 30% a la entrega |
| ⭐ **Preferente** | 60 entregas, menos de 2% de incidencias | 90% al registrar guía · 10% a la entrega |
| 🏅 **Aliada** | 150 entregas, historial limpio, 6 meses | 100% al registrar la guía |

Una marca Aliada cobra prácticamente como vende hoy: despacha y cobra. Pero se lo ganó con historial, no con promesas — y tú sabes exactamente cuánto riesgo estás asumiendo con cada una.

**Qué cuenta como incidencia:** paquete no despachado tras registrar guía, producto distinto al publicado, llegada en mal estado por embalaje deficiente. No cuentan los retrasos de la agencia ni los rechazos del cliente por arrepentimiento.

---

## Retiro exprés (opcional, con costo)

Para quien necesita el dinero *ya*, incluso antes del hito: SOCIO adelanta el saldo pendiente cobrando una comisión de **1.5% del monto adelantado**.

Esto tiene una consecuencia que hay que tener clara: **SOCIO estaría poniendo su propio capital** y asumiendo el riesgo si el pedido falla. Por eso debería habilitarse solo para marcas Confiables en adelante, y con un tope por marca (por ejemplo, S/ 3,000 en tránsito simultáneo) hasta que tengas historial suficiente para subirlo.

Mi recomendación honesta: **no lances esto en el piloto.** Primero necesitas datos reales de cuántos pedidos fallan; sin ese número, el 1.5% es un precio inventado y podrías estar cobrando la mitad de lo que cuesta el riesgo. Actívalo cuando tengas tres o cuatro meses de historial.

---

## Lo que esto exige de tu operación

Tres cosas, y conviene que las tengas claras antes de prometerlo:

1. **Liquidez.** Pagar por hito significa transferencias casi diarias en lugar de una semanal. Es más trabajo operativo —resolvible con transferencias programadas o una pasarela— pero también más movimiento de caja que administrar.

2. **Confirmación de entrega confiable.** Todo el esquema descansa en saber cuándo llegó el paquete. Hoy eso depende de que alguien lo marque a mano. Mientras no tengas integración con las agencias, define una regla de respaldo: por ejemplo, si la agencia no reporta en X días desde el despacho, se libera igual salvo que el vendedor abra un reclamo.

3. **Un fondo de contingencia.** Aunque retengas el 30%, habrá casos donde tengas que responderle al cliente antes de recuperar del proveedor. Un colchón equivalente a una semana de ventas evita que un solo incidente te descuadre el mes.

---

## Mi recomendación para el piloto

Arranca con **el esquema 70/30 por hitos y los cuatro niveles de fiabilidad**, sin retiro exprés. Con eso ya le das al proveedor lo que más le importa —cobrar el mismo día que despacha— sin poner tu capital en juego ni dejar desprotegido al vendedor.

Si quieres, implemento en el panel del proveedor la vista de "Mi dinero": saldo liberado, saldo en tránsito con su hito pendiente, el nivel de fiabilidad con su progreso, y el detalle pedido por pedido de cuándo se libera cada monto.
