# App de Revendedores — Aprendizajes, FODA y Estructura Tributaria

*Documento de trabajo · Lab Péptidos Perú · Agosto 2026*

---

## 1. Qué extraemos de Elenas y Meesho para construir nuestra versión

De cada empresa tomamos lo que resuelve un problema nuestro, no todo su modelo. Esta es la síntesis aplicable:

**De Elenas tomamos el "kit del vendedor sin fricción".** Su fórmula es que la vendedora solo vende: no toca inventario, no gestiona envíos, no cobra, no tramita garantías. Nosotros replicamos eso dándole al vendedor un catálogo listo, material aprobado para publicar, precio base + envío visible, y la libertad de fijar su precio final (su comisión es la diferencia). También tomamos su sistema de pagos a billetera digital en fecha fija semanal (en Perú: Yape/Plin) y sus campañas de incentivos y retos, que son lo que retiene a la red cuando la motivación inicial baja.

**De Meesho tomamos la propuesta a proveedores y la estructura de ingresos.** Su gancho para atraer fabricantes pequeños fue "0% de comisión, sin penalidades, pagos garantizados" — igual que nuestra suscripción gratuita para marcas. Y su lección más valiosa es cómo monetiza sin cobrar comisión visible: publicidad de listados destacados, margen sobre la logística negociada en volumen, una comisión marginal en ciertas categorías, y el rendimiento del dinero que retiene entre el cobro y la liquidación (float). Nuestra comisión sobre el valor agregado es compatible con todo eso: son fuentes que se van sumando por fases.

**De ambas tomamos el cobro centralizado.** Es el punto donde las dos coinciden y nosotros no: en Elenas y Meesho, el dinero del cliente final entra a la plataforma (pago digital o contraentrega) y de ahí se reparte. Eso elimina el fraude del vendedor, genera los datos para nuestros campos de calor, permite ofrecer garantía al cliente final y habilita el float como ingreso. Nuestro modelo actual (el vendedor cobra y deposita el precio de distribuidor) sirve para arrancar rápido con poca infraestructura, pero el destino debe ser el cobro centralizado.

**La advertencia de Meesho que también extraemos:** con el tiempo redujo el peso de los revendedores porque los clientes finales aprendieron a comprar directo. Diseñamos para que el vendedor aporte valor real (asesoría, cierre por WhatsApp, confianza local) y para que la plataforma también pueda vender directo en el futuro sin canibalizar a su red de golpe.

---

## 2. FODA aplicado a nosotros

Cada punto incorpora la experiencia de Elenas y Meesho donde corresponde.

### Fortalezas

- **Marca propia como primer proveedor.** Lab Péptidos Perú entra con márgenes mayoristas ya conocidos, catálogo armado y dos webs operativas (ventas y protocolos). No dependemos de convencer a terceros para lanzar: somos nuestro propio caso de éxito, igual que Meesho arrancó enfocado en un solo vertical (moda) antes de abrir categorías.
- **Dominio del canal social.** Ya vendemos por Instagram, WhatsApp, Facebook y TikTok — exactamente el terreno donde operan los vendedores del modelo. Sabemos qué material funciona y podemos producir el contenido aprobado que ellos necesitan.
- **Estructura de costos mínima.** Sin planilla de vendedores, sin almacén propio para terceros, sin flota. El modelo es asset-light por diseño, que es lo que permitió a Meesho escalar.
- **Modelo de ingresos ya definido en dos capas:** margen mayorista en productos propios y comisión sobre el valor agregado en productos de terceros.

### Oportunidades

- **Perú no tiene un jugador dominante en social selling digital.** Elenas anunció expansión a Perú pero concentró sus fuerzas en México; el espacio local sigue abierto para un actor que entienda el mercado peruano.
- **Demanda enorme de ingresos extra y trabajo remoto.** El mismo perfil que hizo crecer a Elenas (personas que venden a su círculo por redes, sin inversión ni horario) existe masivamente en Perú.
- **Yape y Plin ya resolvieron la infraestructura de cobro.** La penetración de billeteras digitales en Perú hace viable tanto el pago del cliente final como la liquidación semanal a vendedores, sin necesidad de pasarelas caras al inicio.
- **Marcas pequeñas sin canal digital.** Miles de proveedores locales (el equivalente peruano de los fabricantes que Meesho captó con "0% comisión") no tienen cómo vender online; la propuesta "vendedores gratis + tú solo despachas" es directa y entendible.

### Debilidades

- **Sin datos históricos para los campos de calor.** La función estrella de mostrar movimiento y demanda por marca requiere meses de pedidos reales. En la v1 solo podremos mostrar márgenes y categorías; los mapas de calor se activan después.
- **Sin infraestructura de cobro centralizado ni logística.** Elenas y Meesho procesan pagos y coordinan couriers; nosotros arrancamos delegando el cobro al vendedor y el envío al proveedor, lo que nos deja menos control de la experiencia y menos datos.
- **Postventa sin dueño.** Elenas gestiona garantías con el proveedor para que ni la vendedora ni el cliente queden colgados. En nuestro flujo actual nadie tiene asignado ese rol, y es lo primero que un cliente insatisfecho va a reclamar.
- **Equipo pequeño y sin experiencia previa en desarrollo de apps.** Construir, mantener y dar soporte a una plataforma de dos lados (vendedores y marcas) con recursos limitados exige empezar con un MVP muy acotado (PWA antes que app nativa).
- **Marca de plataforma desconocida.** Para atraer proveedores terceros necesitamos primero demostrar tracción con nuestros propios productos.

### Amenazas

- **Fraude del vendedor hacia su cliente.** Mientras el cobro sea descentralizado, un vendedor puede cobrar y desaparecer. Aunque legalmente el número de WhatsApp sea suyo, el reclamo llega a la marca y a la plataforma (Indecopi incluido). Mitigación: validación de identidad, límites de pedidos a vendedores nuevos, reputación visible, y migración al cobro centralizado como solución de fondo.
- **Regulación sanitaria sobre los productos propios.** Los péptidos son sensibles para DIGEMID y para las políticas de Google Play / App Store. Mitigación: la app es una plataforma multi-categoría de gestión de vendedores y pedidos, no una "tienda de péptidos"; el material de venta es solo el aprobado por cada marca.
- **El salto del cliente al proveedor (lección Meesho).** Si el cliente descubre el precio de proveedor, el vendedor pierde sentido. Mitigación: precios de distribuidor visibles solo dentro de la app para vendedores registrados, y valor agregado real del vendedor en el cierre.
- **Interpretación de SUNAT sobre los depósitos.** Si por nuestras cuentas pasa todo el dinero de las ventas sin la estructura contractual correcta, SUNAT puede presumir que todo es ingreso nuestro (ver sección 3). Es la amenaza más silenciosa y la más cara si se ignora.
- **Entrada de un competidor con capital.** Si el modelo demuestra funcionar, replicarlo con más inversión es posible. Nuestra defensa es la red: vendedores activos y marcas contentas cambian de plataforma con dificultad.

---

## 3. El tema tributario: por qué el "doble impuesto" tiene solución

La preocupación es válida y es la correcta a esta altura, pero la buena noticia es que **el sistema tributario peruano está diseñado precisamente para que no se pague impuesto dos veces por el mismo valor**. El resultado depende de cómo estructuremos el rol de la plataforma. Hay dos caminos:

### Modelo A — Plataforma comisionista (intermediario formal)

La figura legal existe y se llama **comisión mercantil** (un mandato para realizar operaciones de comercio, regulado por el Código de Comercio y reconocido por SUNAT). Funciona así:

1. La venta del producto es **del proveedor al cliente final** (o al vendedor, según se pacte). El proveedor emite su comprobante por el precio real del producto.
2. Nosotros **nunca compramos ni vendemos el producto**: solo intermediamos. Nuestro único ingreso es la comisión, y **solo por la comisión emitimos factura y pagamos IGV y Renta**.
3. El dinero de las ventas que pasa por nuestras cuentas **no es ingreso nuestro** — es recaudación por cuenta del proveedor (fondos de terceros). Para que SUNAT lo vea así, necesitamos: contrato de mandato/comisión con cada proveedor, liquidaciones periódicas documentadas de cuánto se recaudó y cuánto se transfirió, y cuentas ordenadas que permitan rastrear cada flujo.

**Ventaja:** tributamos solo sobre lo que realmente ganamos. Es el modelo natural para los productos de terceros.
**Cuidado:** sin los contratos y liquidaciones en regla, SUNAT puede presumir que todos los depósitos recibidos son ingresos gravados nuestros — ahí sí pagaríamos como si hubiéramos vendido todo. El papeleo no es opcional: es la diferencia entre tributar sobre la comisión o sobre el total. Adicionalmente, la comisión mercantil está sujeta al sistema de detracciones (SPOT) cuando supera los montos establecidos, un detalle operativo que el contador debe configurar.

### Modelo B — Plataforma que compra y revende (crédito fiscal)

Si preferimos que la venta al cliente salga a nuestro nombre (más control de la experiencia, útil sobre todo para nuestros propios productos):

1. Compramos al proveedor a precio de distribuidor **con factura**. Esa factura trae IGV, que se convierte en nuestro **crédito fiscal**.
2. Vendemos al precio final **con nuestro comprobante**, cobrando IGV al cliente (**débito fiscal**).
3. A SUNAT solo le pagamos **la diferencia**: débito menos crédito. Es decir, el IGV se paga únicamente sobre nuestro margen, no dos veces sobre el producto completo. Así funciona el IGV para toda la cadena comercial del país — por eso se llama impuesto al *valor agregado*.
4. Con el Impuesto a la Renta pasa lo mismo: se tributa sobre la **utilidad** (venta menos costo de compra menos gastos), no sobre el ingreso bruto.

**Ventaja:** control total de la venta, del comprobante al cliente y de la experiencia.
**Cuidado:** exige facturas de todos los proveedores (proveedores informales rompen la cadena del crédito fiscal y ahí sí pagaríamos de más), más capital de trabajo y más contabilidad.

### Recomendación de estructura (para validar con un contador)

Lo más eficiente es un **modelo mixto**: comisionistas (Modelo A) para los productos de terceros, y compra-reventa (Modelo B) para los productos propios de Lab Péptidos, donde el margen mayorista ya es nuestro negocio. Sobre los vendedores: mientras ellos cobren directo a su cliente y retengan su ganancia, cada vendedor es responsable de sus propios impuestos como negocio independiente (algo que debe quedar explícito en los términos y condiciones de la app); si migramos al cobro centralizado y les pagamos comisiones nosotros, ellos emitirían recibos por honorarios y aplicarían las retenciones correspondientes.

**Importante:** esto es un mapa de opciones, no asesoría tributaria. Antes de constituir la estructura, una sesión con un contador colegiado (idealmente con experiencia en e-commerce o marketplaces) para elegir régimen (MYPE Tributario suele ser el punto de partida), redactar los contratos de comisión y configurar la facturación electrónica. Ese gasto se paga solo con el primer error que evita.

---

## 4. Lo que esto define para el diseño de la app

La estructura tributaria no es solo un tema contable: dicta funciones concretas de la plataforma. El módulo de pedidos debe generar automáticamente la **liquidación por proveedor** (cuánto se recaudó, cuánto le corresponde, cuánto es nuestra comisión), porque ese documento es a la vez la transparencia que el proveedor necesita y el sustento que SUNAT exigirá. El registro del vendedor debe incluir la **aceptación de términos donde asume su condición de negocio independiente** mientras cobre directo. Y el flujo de pedido debe distinguir desde el inicio si el producto es **propio (compra-reventa) o de tercero (comisión)**, porque el comprobante que se emite es distinto en cada caso.

---

## 5. Próximos pasos sugeridos

1. **Sesión con contador** para validar el modelo mixto, elegir régimen y redactar el contrato marco de comisión mercantil con proveedores.
2. **Definir el flujo de postventa** (quién responde garantías: propuesta — la plataforma gestiona con el proveedor, como Elenas).
3. **Diseñar el MVP como PWA**: registro y validación de vendedores, catálogo con precio distribuidor, carga de pedidos, liquidaciones automáticas, panel de comisiones. Lab Péptidos como única marca del piloto.
4. **Piloto con 10–20 vendedores reales** durante 4–8 semanas antes de abrir a marcas terceras.
5. **Con los datos del piloto**, activar campos de calor, sumar la segunda y tercera marca, y evaluar la migración al cobro centralizado con Yape/Plin.
