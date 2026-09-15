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
