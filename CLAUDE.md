# SOCIO — Orientación del proyecto

*Léeme primero. Este archivo existe para que puedas arrancar sin que Jason tenga que reexplicar todo lo decidido hasta ahora.*

---

## ⚠️ Lo primero que hay que entender bien

**SOCIO es una plataforma multi-marca y multi-nicho.** La idea central es que cualquier empresa, de cualquier rubro — cosmética, ropa, alimentos, tecnología, lo que sea — pueda publicar su catálogo y que una red de vendedores independientes ("socios") lo venda por comisión. SOCIO es el enlace comercial entre ambos: valida pagos, coordina despacho, liquida el dinero.

**Lab Péptidos Perú NO es el producto. Es la marca piloto** que se usó para construir y probar el mecanismo — presentaciones con precio variable, niveles de socio, orígenes de despacho, reparto de margen. Se eligió porque es el negocio real de Jason y porque tenía datos reales disponibles para probar con algo concreto en vez de datos inventados. Cuando leas el catálogo cargado (47 productos de péptidos) o el lenguaje de cumplimiento sanitario en las fichas, es **contenido de esa marca específica**, no una característica de la plataforma. Una segunda marca de otro rubro tendría su propio catálogo, sus propias categorías, su propio lenguaje — nada de eso se hereda de Lab Péptidos.

Si en algún momento una instrucción o un documento suena como si SOCIO *fuera* una app de péptidos, es un error de énfasis que hay que corregir al leerlo, no una decisión de producto.

### Qué tan genérico está el código hoy — la verdad, sin adornar

Lo bueno: el **filtro de categorías, los niveles del socio, el cálculo de precios por nivel y los pagos por hitos ya son genéricos** — no asumen nada de péptidos, funcionan con cualquier dato que se les cargue.

Lo que SÍ quedó específico de Lab Péptidos y hay que generalizar antes de cargar una segunda marca de otro rubro:

- **`ORIGENES` en `vendedor.html` está fijo y global** (`cusco` / `lima`, con esos nombres y esas reglas de despacho hardcodeadas). Asume que TODA la plataforma tiene exactamente esos dos orígenes. Debe volverse un dato por marca — cada marca define sus propios orígenes de despacho, no un objeto único compartido por toda la app.
- **El catálogo de datos** (`productos`, `FICHAS`, `SKUS` dentro de `vendedor.html`) es 100% de Lab Péptidos — sus 47 productos, sus descripciones, su lenguaje de "uso en investigación, sin aprobación sanitaria para consumo humano". Esto es normal y esperado (son los datos reales de la marca piloto), pero cuando se construya el backend (ver `docs/13`), cada marca va a tener su propia fila en la base de datos — no hay que generalizar el contenido, solo asegurarse de que la estructura permita que cada marca cargue el suyo sin tocar código.

---

## Estructura de este proyecto

```
app/
  vendedor.html       — App del socio/vendedor (donde vende)
  proveedor.html      — Panel de la marca (carga catálogo, despacha, cobra)
  administrador.html  — Panel de SOCIO (valida pagos, monitorea red)
  imagenes/           — Fotos reales de producto de Lab Péptidos (marca piloto)
docs/                 — Toda decisión de negocio y arquitectura, numerada
                        en el orden en que conviene leerla
diseno/               — Paletas de color exploradas (referencia)
```

**Léelos en orden** si quieres el panorama completo; si solo necesitas resolver algo puntual, ve directo al documento que le corresponde (los nombres son descriptivos).

---

## Estado técnico actual

**Las tres apps son HTML/CSS/JS autocontenido, sin backend.** Cada una guarda todo en el `localStorage` del navegador donde se abre. Esto significa:

- Un pedido registrado en `vendedor.html` **no le aparece solo** a `proveedor.html` ni a `administrador.html` — cada archivo vive aislado en su propio dispositivo.
- No hay autenticación real (las claves se guardan tal cual en el storage local, sin hash).
- No hay validación de pagos real — el flujo de vouchers está diseñado (`docs/12`) pero no conectado a ningún banco ni pasarela.

**Esto es lo primero que hay que resolver.** El modelo de datos completo para Supabase/Postgres ya está diseñado en `docs/13-modelo-de-datos.md`, con las tablas, sus relaciones, y las reglas de permisos por fila (RLS) que hacen que un socio no pueda ver el catálogo de otra marca, ni una marca ver pedidos que no son suyos. Ese modelo **ya está pensado para multi-marca desde el diseño** (una tabla `marcas`, cada producto referencia su `marca_id`) — es el camino natural para resolver también el problema de `ORIGENES` fijo: los orígenes de despacho deberían vivir como una tabla propia, referenciada por marca, igual que los productos.

---

## Reglas de negocio que YA están decididas (no las repienses, aplícalas)

Estas reglas son de la plataforma, no de Lab Péptidos — aplican a cualquier marca que se sume:

1. **El socio nunca ve el precio mayorista ni el costo del proveedor** — solo ve "precio socio" (ya con su descuento aplicado) y "precio de página" (público). Detalle completo: `docs/05`.

2. **Productos propios de una marca dueña de SOCIO** (como Lab Péptidos, si SOCIO fuera también su dueño): el descuento del socio es un porcentaje plano sobre el precio de página, según su nivel (Bronce 10% → Diamante 20%). Detalle: `docs/06`.

3. **Productos de marcas terceras (el caso general, la mayoría de marcas futuras):** el descuento se calcula repartiendo el MARGEN disponible (precio página − precio mayorista) entre el socio y SOCIO, nunca descontando a ciegas del precio público — así nunca puede dar negativo. Detalle: `docs/07`.

4. **Ningún producto puede publicarse sin precio.** No existe "a cotizar" en SOCIO — el socio nunca debe negociar precio directo con la marca. Detalle: `docs/10`.

5. **Niveles del socio** (Bronce/Plata/Oro/Diamante) suben solos según **ventas entregadas**, no pedidos registrados — se revisan cada trimestre y bajan un solo escalón si el ritmo cae. Ya implementado en `vendedor.html`, es genérico.

6. **El proveedor cobra por hitos, no por calendario:** 70% al registrar la guía de envío, 30% al confirmarse la entrega (100% de inmediato si la entrega es local, el mismo día). El porcentaje mejora según su nivel de fiabilidad (Nueva → Aliada). Detalle: `docs/08`.

7. **El vendedor puede pausarse** (activo/en pausa) y marcar días de ausencia, para no comprometerse a pedidos que no podrá atender. Ya implementado, es genérico.

---

## Pendientes conocidos (no son bugs, son trabajo por hacer)

- **`ORIGENES` hardcodeado a Cusco/Lima** — ver arriba. Es lo más urgente de generalizar si se planea cargar una segunda marca pronto.
- **`administrador.html` está desactualizado** — se construyó antes de definir el reparto de margen y los pagos por hitos.
- **Datos reales que solo Jason tiene** (de Lab Péptidos): precios mayoristas reales, stock real por almacén, costo real del delivery a domicilio en Lima.
- **12 presentaciones del catálogo de Lab Péptidos quedaron excluidas** por no tener precio (ver `docs/10`).
- **Wolverine 20mg tiene un dato de composición inconsistente** en el archivo fuente — no se muestra hasta que Jason lo confirme.
- **Legal:** el contrato de comisión mercantil y los T&C no han sido revisados por un abogado todavía.

---

## Cómo trabajar con Jason

No tiene background de desarrollo web — explica en términos de negocio y de lo que el usuario final ve, no de implementación técnica, salvo que él pregunte por el código directamente. Le gusta iterar rápido y tomar decisiones de producto él mismo; preséntale opciones con una recomendación clara, no solo una lista neutral. Y sobre todo: **no asumas que "el producto" es péptidos** — pregunta o revisa este archivo antes de tomar decisiones que solo tendrían sentido para esa marca piloto.
