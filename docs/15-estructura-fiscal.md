# 15 · Estructura fiscal: quién emite qué, y qué obliga el sistema

*Fuentes: el «Informe Técnico y Tributario» del contador colegiado
(septiembre 2026) y su «Manual de Flujo Operativo y Tributario», que lo
concreta paso por paso. Este documento resume lo que decidió y lo que eso
significa para el código.*

*Actualizado con el manual: la sección 6 recoge lo que el manual precisa o
cambia, y los dos puntos que hay que devolverle al contador.*

---

## Lo primero: esto corrige una recomendación anterior mía

Cuando surgió el problema de la boleta —el cliente recibe el producto con un
comprobante que dice un precio distinto al que él pagó— yo recomendé el
**Modelo A**: que la **marca** emitiera la boleta al cliente final por el precio
completo, apoyándome en que docs/01 describe el modelo como comisión mercantil.

**El contador dice lo contrario, y su criterio es el que manda.** La boleta al
cliente final la emite **el vendedor independiente, bajo su propio RUC**. La
marca no le factura al cliente: le factura a SOCIO o al vendedor, por el precio
mayorista.

Esto no es un matiz. Cambia quién puede vender en la plataforma (ver más abajo).

---

## 1 · Los tres comprobantes

Cada venta genera tres documentos independientes, y ninguno de los tres es el
mismo papel visto dos veces:

| Eslabón | Quién emite | A quién | Por cuánto (ejemplo) |
|---|---|---|---|
| Venta final | **El vendedor** | El cliente final | Boleta o factura por el precio completo — S/ 175.00 |
| Servicio tecnológico | **SOCIO** | El vendedor (o la marca) | Factura electrónica por la comisión de plataforma |
| Costo del bien | **La marca** | **El vendedor** | Factura por el precio mayorista — S/ 129.67 |

Dos reglas que se derivan de ahí:

- **Entre RUC nunca va boleta, va factura electrónica.** La comisión de la
  plataforma se factura, no se "boletea".
- **SOCIO no es recaudador.** Solo emite comprobante por su comisión. El dinero
  del cliente que pasa por la plataforma no es ingreso bruto de SOCIO — para
  eso hace falta el contrato de comisión mercantil del punto 5.

El régimen es **MYPE Tributario**, y el objeto social de la empresa debe incluir
intermediación comercial, desarrollo de plataformas tecnológicas y gestión de
servicios digitales.

---

## 2 · Custodia operativa controlada (el flujo, sin pasarela de pagos)

Mientras el piloto cobre por Yape, Plin y transferencia, el orden es este y no
otro:

1. **El cliente le paga al vendedor** el monto total, directamente.
2. **El vendedor registra la venta** en la app: adjunta el comprobante de pago
   del cliente y los datos de envío.
3. **SOCIO valida** el pago contra el estado de cuenta y notifica a la marca que
   el pedido tiene respaldo financiero.
4. **La marca despacha y sube la evidencia**: guía de remisión y voucher o
   tracking del courier. *Sin esa evidencia el flujo se bloquea.*
5. **Liquidación**: el vendedor transfiere la porción mayorista, la app libera el
   proceso logístico y emite la factura por su comisión.

---

## 3 · Lo que el contador le exige al software (y dónde está en el código)

El informe trae una sección dirigida al desarrollador. Está implementada en
`supabase/migrations/20260913180000_estructura_fiscal.sql`, y todo lo de abajo
está probado en `supabase/verificacion/08-estructura-fiscal.sql`.

### A · Privacidad y catálogo oculto

> «Campos internos (ocultos al cliente final): `precio_mayorista_marca`,
> `comision_vendedor` y `comision_aplicativo_socio`.»

Antes esto lo cuidaba la pantalla, y solo a medias: un socio podía pedirle a la
API el `precio_mayorista` de sus propios pedidos y calcular exactamente cuánto
gana la plataforma; una marca podía leer la comisión de SOCIO y hacer lo mismo
al revés. Ahora cada rol lee por una vista distinta:

| Vista | La usa | Ve | No ve |
|---|---|---|---|
| `pedidos_socio` | el vendedor | lo que paga y lo que gana | mayorista, comisión de SOCIO |
| `pedidos_marca` | la marca | su mayorista íntegro | lo que paga el socio, su ganancia, la comisión de SOCIO |
| `pedidos_admin` | SOCIO | todo | — |
| `catalogo_publico` | cualquiera | precio de página | mayorista |

Sobre la tabla `pedidos` el permiso de lectura de esas columnas está retirado,
así que la vista no es una cortesía de la pantalla: es lo único por donde se
puede llegar al dato.

De paso se cerró un agujero que la revisión dejó a la vista: **la marca tenía
permiso para reescribir los importes de un pedido ya cerrado** — podía subirse
el mayorista y cobrar de más. Ahora solo puede tocar estado, guía, courier y
tracking.

### B · Autogestión de comprobantes del vendedor

`usuarios_socios` gana `ruc`, `razon_social`, `direccion_fiscal` y
`emite_comprobante`; `pedidos` gana `comprobante_tipo`, `comprobante_serie`,
`comprobante_numero` y `comprobante_url`.

El vendedor registra su boleta con `registrar_comprobante()`, que comprueba que
el pedido sea suyo, que el tipo sea boleta o factura, y deja constancia en la
bitácora.

Los campos son **opcionales en la base**. Quién puede vender sin RUC es una
decisión de negocio, no técnica — ver la sección 5 de este documento.

### C · Máquina de estados con despacho bloqueado

```
[1 pendiente_pago]  el pedido existe, el cliente aún no paga
       ↓
[2 pagado]          el vendedor registró el pago y adjuntó el voucher
       ↓
[3 validado]        SOCIO lo cruzó contra el estado de cuenta
       ↓
[4 en_camino]       despachado — EXIGE guía + courier + tracking
       ↓
[5 entregado]       entregado y liquidado
```

Cancelar se puede desde cualquier estado anterior a la entrega. De `entregado`
no se sale.

Lo que cambió respecto de antes: existía un solo estado `pagado` que mezclaba
«el vendedor dice que le pagaron» con «SOCIO lo comprobó». Esa confusión es
justo la que deja despachar contra un voucher falso. Ahora son dos estados.

El bloqueo lo hace la base de datos (`trg_pedido_transicion`), no la pantalla:
un intento de saltar de `pendiente_pago` a `entregado`, o de marcar despachado
sin tracking, falla con un mensaje explicando qué falta.

### D · Reporte contable

La vista `reporte_contable` — visible **solo para SOCIO** — trae por pedido:
fecha, marca, vendedor, RUC del vendedor, precio de venta, costo mayorista,
comisión del vendedor, comisión de la plataforma, y esa comisión desglosada en
neto e IGV. Es el único sitio de todo el sistema donde los tres importes
aparecen juntos, y es lo que se exporta para emitir las facturas globales del
periodo.

---

## 4 · Recomendaciones legales (pendientes, no son código)

- **Objeto social amplio** en la minuta de constitución: intermediación
  comercial, plataformas tecnológicas, servicios digitales.
- **T&C blindados**: contrato de adhesión donde el vendedor acepta que actúa
  como distribuidor independiente y es el único responsable de declarar sus
  comprobantes ante SUNAT.
- **Contrato de comisión mercantil** con cada marca —incluida Lab Péptidos—
  para respaldar que los fondos operan bajo mandato de cobranza y no son
  ingresos brutos gravables de la plataforma.

Los tres siguen sin revisión de abogado (ver CLAUDE.md, pendientes conocidos).

---

## 5 · Lo que esto le rompe a docs/04, y que hay que decidir

`docs/04` asume que el socio puede ser cualquier persona con un celular: un
universitario, alguien que vende por WhatsApp, una tienda de barrio. Ese es el
motor de crecimiento del modelo.

El contador dice que **la boleta al cliente la emite el vendedor bajo su propio
RUC** (RUC 10 con negocio, o RUC 20). Un socio sin RUC no puede cumplir esa
obligación, y la ley peruana sanciona no enviar el comprobante con el producto.

Las salidas posibles, y qué cuesta cada una:

1. **Exigir RUC para vender.** Cumple al pie de la letra. Coste: mata la
   captación informal, que es de donde saldría el volumen del primer año.
2. **Exigir RUC solo por encima de un umbral** (monto acumulado o número de
   ventas). El socio arranca sin RUC y saca el suyo cuando le empieza a
   convenir; la app se lo pide en el momento. Coste: hay un tramo inicial sin
   comprobante que alguien tiene que cubrir.
3. **Que SOCIO emita por cuenta del vendedor**, como agente. Es cómodo para el
   socio, pero convierte a SOCIO en algo parecido a un recaudador — exactamente
   lo que el informe dice que hay que evitar. Habría que consultarlo con el
   contador antes de siquiera diseñarlo.

**Recomendación: la 2.** Es la única que no obliga a elegir entre cumplir y
crecer, y la base ya está lista para ella — los campos de RUC son opcionales, y
la app puede pedirlos cuando el socio cruce el umbral. El umbral concreto sí hay
que preguntárselo al contador.

Esta decisión está **abierta**: nada en el código la da por tomada.

---

## 6 · Lo que añade el manual operativo (set-2026)

El manual traduce el informe a pasos concretos. Casi todo confirma lo que ya
estaba; esto es lo que cambia o precisa.

### 6.1 · El reparto, con números cerrados

El manual fija el ejemplo base: PVP S/ 175.00, mayorista S/ 129.67, y la
diferencia de S/ 45.33 repartida entre vendedor (S/ 17.50 en Bronce) y SOCIO
(S/ 27.83, con IGV dentro).

Esos números salen exactos del motor de precios que ya estaba escrito, sin tocar
nada. Vale la pena notar por qué: **S/ 129.67 es justo el mayorista máximo que
admite un PVP de 175** — el margen que deja, 25.9%, es exactamente el mínimo que
SOCIO exige para poder pagar comisiones. El contador eligió (o dio con) el caso
límite. Un sol más de mayorista y el producto no se habría podido publicar.

Con ese mismo mayorista y un socio Diamante, el reparto queda S/ 35.00 para el
vendedor y S/ 10.33 para SOCIO — que sigue cubriendo el 5% neto exigido, pero
por dos céntimos. Es correcto, y conviene saber que ahí no hay holgura.

### 6.2 · Entrega local: el candado logístico estaba mal puesto

El manual repite la regla: sin guía de remisión y sin tracking del courier, el
pedido no avanza. Escrita así de literal, como la dejó la migración anterior,
**ningún pedido de entrega a domicilio podía despacharse nunca**: una entrega
local en la misma ciudad no tiene courier ni número de seguimiento que poner.

Corregido: la guía de remisión se exige **siempre** (transportar mercadería sin
ella es sancionable igual, sea local o nacional); el courier y el tracking se
exigen solo cuando el envío va por agencia. El manual solo contempla el envío
nacional, así que esto es una interpretación — si el contador prefiere otra cosa
para la entrega local, se cambia en una línea.

### 6.3 · La liquidación dejó de ser un concepto

El PASO 4 del manual describe la liquidación. La tabla para registrarla existía
desde `docs/13` y nunca se llenaba. Ahora cada hito escribe su fila sola, con el
reparto que definió `docs/08` según el nivel de fiabilidad de la marca:

| Nivel de la marca | Al registrar la guía | A la entrega confirmada |
|---|---|---|
| 🌱 Nueva | 0% | 100% |
| ✅ Confiable | 70% | 30% |
| ⭐ Preferente | 90% | 10% |
| 🏅 Aliada | 100% | 0% |

El segundo hito paga siempre *el resto*, no un porcentaje recalculado: así la
marca cobra su mayorista exacto aunque el redondeo no sea limpio. Probado con
los cuatro niveles.

Las entregas cumplidas se cuentan solas (`marcas.entregas_ok`), pero **ninguna
marca sube de nivel sola**: los niveles de `docs/08` piden además historial
limpio y antigüedad, y eso no lo sabe un contador de entregas. Promover es
decisión de SOCIO, igual que validar la identidad de un socio.

### 6.4 · El nombre que va en la boleta

El PASO 1 pide que la boleta al cliente lleve una descripción comercial genérica
("Kit de Optimización Biológica") en vez del nombre de catálogo. Ahora cada
producto tiene ese campo: la marca lo llena al cargar el producto o en la
plantilla de Excel, y el vendedor lo ve al emitir su boleta. Si se deja vacío, se
usa el nombre del producto.

### 6.5 · El botón de exportación

El panel de administración tiene una pestaña **Contabilidad** con el consolidado
del periodo y el botón que pide la sección 4.3, en CSV que el Excel en español
abre directamente en columnas. Es lo único de ese panel que está conectado a la
base; el resto sigue con datos de demostración.

---

## 7 · Dos cosas que hay que devolverle al contador

### 7.1 · El PASO 5 no cuadra con el PASO 4

El manual dice dos cosas que, juntas, no cierran:

- **PASO 3:** la marca le factura al vendedor **S/ 129.67**.
- **PASO 4:** de los S/ 157.50 que transfiere el vendedor, **S/ 129.67 van a la
  marca** y S/ 27.83 van a SOCIO.
- **PASO 5:** SOCIO le emite su factura de comisión **a la marca**, por S/ 27.83.

Si la marca facturó 129.67 y *recibió* 129.67 en efectivo, pero además recibe una
factura de SOCIO por 27.83 que nunca pagó, sus libros quedan con un ingreso de
129.67, un gasto de 27.83 y una deuda con SOCIO de 27.83 que no existe. No cuadra.

Las dos formas de cerrarlo:

1. **SOCIO le factura al vendedor** (que es lo que decía el informe original, y
   lo que coincide con el flujo del dinero del PASO 4). El vendedor sustenta
   S/ 129.67 de costo + S/ 27.83 de servicio = S/ 157.50, e ingresó S/ 175.00.
   Cierra solo.
2. **La marca le factura al vendedor S/ 157.50** y SOCIO le factura a la marca
   S/ 27.83. La marca queda neta en 129.67. También cierra, pero infla la
   facturación de la marca con dinero que no es suyo.

**Recomendación: la 1.** Es la que coincide con por dónde se mueve el dinero, y
es la que menos papeles mueve. Pero es decisión del contador, no mía.

Mientras tanto, el reporte contable trae **el RUC de las dos partes**, así que
sirve para emitir en cualquiera de las dos direcciones sin tocar nada.

### 7.2 · Facturarle a la marca rompe la confidencialidad que pediste

Esto es aparte de si cuadra o no. Si SOCIO le emite la factura de comisión a la
marca, **la marca se entera de cuánto gana la plataforma**: está escrito en el
documento que recibe. Y como la marca ya conoce su mayorista y el precio de
página, con ese tercer número deduce al céntimo cuánto gana el vendedor.

Eso es exactamente lo que pediste evitar cuando quitamos el cuadro del reparto
del panel del proveedor. El panel sigue sin mostrarlo —eso no cambia— pero la
factura lo diría igual.

Si la comisión se le factura al **vendedor** (opción 1 de arriba), el problema
desaparece: el vendedor ya conoce su propia comisión, y la marca nunca ve el
número. Es una razón más para preferir esa vía.

---

## 8 · ¿Facturarle al vendedor nos hace dueños del producto?

*Jason planteó esta objeción a la recomendación de la sección 7.1, y merece
respuesta precisa porque de ella depende la protección ante Indecopi.*

**No.** Pero la objeción apunta a un riesgo que sí existe, solo que el disparador
es otro. Vale la pena separar las dos cosas.

### Lo que NO determina la propiedad

**A quién va dirigida la factura.** Emitirle un comprobante a alguien no implica
haberle vendido un bien. Lo que define qué se transfirió es **el concepto del
comprobante**, no su destinatario. Una factura por "servicio de intermediación
tecnológica" no transfiere nada, vaya dirigida al vendedor, a la marca o a quien
sea. Es exactamente lo que `docs/01` describe como Modelo A:

> «Nosotros **nunca compramos ni vendemos el producto**: solo intermediamos.
> Nuestro único ingreso es la comisión, y **solo por la comisión emitimos
> factura** y pagamos IGV y Renta.»

Facturarle la comisión al vendedor *es* ese modelo, no una desviación de él.

### Lo que SÍ determina la propiedad

Son tres cosas, y conviene revisarlas una por una:

| Qué lo determina | Cómo está hoy | ¿Riesgo? |
|---|---|---|
| **La guía de remisión** — es el documento que prueba quién movió el bien | La emite la marca como remitente; el destinatario es el cliente final. SOCIO no figura | ✅ Ninguno |
| **A quién le factura la marca su costo** | Al **vendedor** (manual, PASO 3). Si le facturara a SOCIO, SOCIO habría comprado | ✅ Ninguno |
| **El concepto de la factura de SOCIO** | Debe decir *servicio*. Si dijera "venta" o nombrara el producto, SOCIO aparecería vendiendo un bien | ⚠️ **Aquí sí** |

De las tres, dos están resueltas en la base de datos y no dependen de que nadie
se acuerde: el destinatario de la guía es el cliente final y solo la marca puede
subirla. La tercera es operativa —depende de cómo se redacte cada factura— y era
el único cabo suelto real.

**Esto es lo que había que cuidar, no la dirección de la factura.**

### Y el riesgo de verdad: cómo se ve el dinero

Hay un cuarto punto que ninguna de las dos opciones de la sección 7.1 resuelve
por sí sola, y que es el que de verdad puede costar caro.

Si SOCIO recibe S/ 157.50 y transfiere S/ 129.67 a la marca, **desde fuera eso se
parece a comprar a 129.67 y vender a 157.50**. `docs/01` lo advierte sin rodeos:

> «Sin los contratos y liquidaciones en regla, SUNAT puede presumir que todos los
> depósitos recibidos son ingresos gravados nuestros — ahí sí pagaríamos como si
> hubiéramos vendido todo.»

Lo que desarma esa presunción son dos papeles, y **ninguno de los dos es la
factura de comisión**:

1. **El contrato de comisión mercantil** con cada marca, que declara que SOCIO
   cobra por mandato y no por cuenta propia. Pendiente de abogado.
2. **Las liquidaciones periódicas documentadas** de cuánto se recaudó por cuenta
   de cada marca y cuánto se le transfirió.

El segundo ya existe: pestaña **Contabilidad → Liquidación por marca** en el
panel de administración, exportable por periodo. Cada fila dice, por marca,
cuánto se recaudó *por su cuenta*, cuánto se le transfirió, cuánto queda
pendiente y cuánto retuvo SOCIO de comisión — con el concepto de la factura
escrito en la propia fila, para que nadie lo improvise.

### Conclusión, y qué preguntarle al contador

La recomendación de la sección 7.1 **no cambia**: facturarle la comisión al
vendedor sigue siendo lo que cuadra con el flujo del dinero y lo que protege la
confidencialidad. No nos hace dueños del producto, porque la propiedad la fija la
guía de remisión y el concepto del comprobante, y las dos cosas nos dejan fuera.

Lo que sí hay que confirmar con el contador, y conviene preguntarlo junto con lo
de la sección 7:

1. **El texto exacto del concepto** de la factura de SOCIO. Hoy el sistema propone
   *"Servicio de intermediación tecnológica y gestión de plataforma"*. Si él
   prefiere otra redacción, se cambia en un sitio.
2. **Si conviene que el vendedor haga dos transferencias** —una a la marca y otra
   a SOCIO— en vez de una sola a SOCIO. Con dos transferencias, el dinero de la
   marca nunca toca las cuentas de SOCIO y la presunción de compra-reventa
   desaparece de raíz. **El costo es real:** se pierde la custodia, que es la
   palanca que hoy obliga a la marca a despachar antes de cobrar. Es un cambio de
   modelo, no un detalle contable, y por eso no lo decido yo.
3. **Si la comisión mercantil de SOCIO cae en detracciones (SPOT)**, ya anotado
   como pendiente en `docs/01`.

---

## 9 · La especificación técnica (set-2026)

*Tercer documento del contador, este dirigido al equipo de desarrollo. Casi todo
confirmaba lo ya construido; esto es lo que faltaba y lo que quedó pendiente.*

### 9.1 · Lo que faltaba, y ya está

**El PVP como dato propio (§1).** La especificación pide manejar los cuatro
montos «de forma separada por cada pedido». El precio de venta al público se
venía calculando al vuelo sumando lo que paga el socio más lo que gana. Ahora es
una columna, y una **columna calculada**: Postgres la mantiene sola, no se puede
escribir a mano y no puede quedar desfasada de sus sumandos. Se tiene el monto
separado sin el riesgo de que alguien actualice uno y no el otro.

**La foto de la guía (FASE 3).** Aquí había un hueco real. La especificación
exige *dos* datos obligatorios para despachar —«Foto de la Guía de Remisión» y
«Número de Seguimiento»— y el sistema solo pedía el **número** de la guía. Un
número se inventa en dos segundos; una foto, no. Ahora se exigen los dos, y la
foto vive en un cubo privado de Supabase Storage donde cada marca solo puede
escribir en su propia carpeta y nadie puede borrar ni reemplazar lo ya subido.

La pantalla de despacho del panel de la marca también pedía un solo dato. Ahora
pide los cuatro (guía, foto, courier y tracking), y en entrega local solo los dos
que existen.

**El reporte, en el orden pedido (§4).** Las ocho columnas obligatorias van
primero y con los nombres de la especificación. Detrás se conserva lo demás:
hace falta para liquidar y para responder un reclamo, y quitarlo no ahorra nada.

**Agrupación por periodo.** El reporte agrupa por mes o por semana, con subtotal
de comisión por grupo, y trae un filtro de **transacciones cerradas** (entregadas)
activado por defecto, que es lo que se factura.

### 9.2 · Lo que ya cumplía sin tocar nada

| Requisito | Estado |
|---|---|
| §1 · Los cuatro montos separados por pedido | ya estaban los otros tres |
| §2 · Cliente final ve solo el PVP | el texto que el vendedor copia para WhatsApp muestra únicamente el precio; no hay desgloses |
| §2 · Vendedor ve su precio, nivel y saldo a gestionar | sí |
| §2 · Marca ve su mayorista | sí — y no ve el PVP ni las comisiones |
| FASE 2 · Máquina de estados y validación | migración 4 |
| FASE 4 · Liquidación automática | migración 5 |

### 9.3 · Lo que queda pendiente, y por qué

Tres cosas de la especificación no están hechas, y ninguna es un detalle:

1. **La notificación automática a la marca** cuando SOCIO valida un pago
   (FASE 2). Hoy la marca ve el pedido cuando entra a mirar. Falta el aviso que
   lo empuja. Necesita decidir el canal —correo, WhatsApp, aviso dentro del
   panel— y eso es una decisión de producto, no técnica.

2. **El recordatorio al vendedor de emitir su boleta** (FASE 1.3). La base ya
   tiene dónde guardar su RUC y el comprobante que emitió, y la función para
   registrarlo. Falta la pantalla, porque **`vendedor.html` todavía no está
   conectado a la base**: sigue funcionando con el almacenamiento del navegador.

3. **La pantalla de despacho del proveedor no está conectada.** Se corrigió para
   pedir los cuatro datos, pero guarda en el navegador, no en Supabase. Hasta que
   se conecte, la foto no se sube a ningún sitio.

Las tres dependen de lo mismo: conectar `vendedor.html` y la parte de pedidos de
`proveedor.html` a la base. Es el siguiente bloque de trabajo, y es grande.
