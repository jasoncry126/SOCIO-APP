# 15 · Estructura fiscal: quién emite qué, y qué obliga el sistema

*Fuente: informe del contador colegiado, septiembre 2026, «Informe Técnico y
Tributario: Modelo Operativo y Fiscal de la Plataforma SOCIO». Este documento
resume lo que decidió y lo que eso significa para el código.*

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
| Costo del bien | **La marca** | SOCIO o el vendedor | Factura por el precio mayorista — S/ 129.67 |

Dos reglas que se derivan de ahí:

- **Entre RUC nunca va boleta, va factura electrónica.** La comisión que SOCIO
  le cobra al vendedor se factura, no se "boletea".
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
