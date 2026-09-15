# SOCIO — ¿Una app con dos roles o dos apps vinculadas?

*Documento de decisión · Agosto 2026*

---

## 1. La respuesta corta

**Un solo cerebro, dos caras.** La recomendación es: **una sola plataforma por dentro (mismo sistema, misma base de datos, mismos pedidos) con dos experiencias separadas por fuera** — la **app para el vendedor** y un **panel web para el proveedor**. No son dos apps que "se vinculan": son dos puertas de entrada al mismo sistema, cada una mostrando solo lo que su rol necesita.

Y un matiz importante para el arranque: el proveedor **no necesita una app de tienda de aplicaciones todavía**. Necesita un panel web que abre desde su computadora o celular. La app descargable — la que compite por atención en Google Play — es solo para el vendedor.

---

## 2. Por qué así (y no una app única con ambos roles adentro)

**Los dos usuarios son animales distintos.** El vendedor vive en su celular, entra muchas veces al día, en la calle, entre chats de WhatsApp: registra pedidos, revisa su ganancia, descarga material. El proveedor entra pocas veces al día, sentado, a gestionar: ver pedidos pagados por despachar, subir guías, revisar liquidaciones, editar su catálogo. Meter ambos mundos en una sola app obliga a un onboarding con la pregunta "¿eres tienda o vendedor?" — fricción en el peor momento posible, cuando alguien recién decide probarte.

**La ficha de la tienda de apps solo puede venderle a uno.** El nombre, las capturas, la descripción y las reseñas de SOCIO en Google Play deben gritar una sola cosa: *"gana dinero vendiendo, sin jefe y sin inversión"*. Si la misma ficha también intenta explicar "y si eres marca, gestiona tu catálogo...", el mensaje se diluye y la conversión de descargas cae. El vendedor es tu motor de crecimiento; la ficha es suya.

**Es lo que hacen los que ya resolvieron este problema.** Rappi tiene la app del cliente, *Rappi Aliados* para restaurantes y *Soy Rappi* para repartidores. Uber separa conductor y pasajero. Meesho tiene su app masiva para quien vende/compra y un panel de proveedor aparte. Elenas: app para las vendedoras, portal para las marcas. Nadie mezcla los roles en una sola experiencia — pero todos comparten el mismo sistema por detrás.

**Seguridad y datos.** El proveedor jamás debe ver los márgenes del vendedor ni sus clientes de otras marcas; el vendedor jamás debe ver el precio real del proveedor de otra marca ni sus liquidaciones. Separar las experiencias hace estas fronteras naturales; mezclarlas en una app las convierte en un campo minado de permisos.

**Costo y velocidad.** Dos apps nativas desde el día uno = doble desarrollo, doble mantenimiento, doble proceso de aprobación en las tiendas. Un panel web de proveedor cuesta una fracción, se actualiza al instante sin esperar aprobaciones, y los proveedores del arranque son pocos (Lab Péptidos + los primeros terceros) — no justifican una app propia todavía.

---

## 3. Cómo queda la arquitectura por fases

**Fase 1 (piloto).** Un solo sistema con tres vistas: la **PWA del vendedor** (el prototipo que ya tienes), el **panel web del proveedor** (pedidos pagados por despachar, carga de guía de envío, liquidaciones, catálogo) y un **panel interno de administración** para ti (validar identidades y pagos, aprobar marcas, resolver reclamos). Mismo backend, misma base de pedidos: cuando el vendedor registra un pedido pagado, aparece al instante en el panel del proveedor.

**Fase 2 (app en tiendas).** La app nativa que se publica en Google Play / App Store es **solo la del vendedor**, con la marca SOCIO y toda la ficha optimizada para captar gente que busca ingresos. El proveedor sigue en su panel web, que para entonces ya evolucionó con reportes y campos de calor.

**Fase 3 (si el volumen lo pide).** Cuando tengas decenas de proveedores activos despachando a diario, ahí sí nace la segunda app descargable — *"SOCIO Marcas"* o similar, el equivalente de Rappi Aliados — porque a ese volumen el proveedor sí necesita notificaciones push de pedidos en el bolsillo. Se construye sobre el mismo sistema: es otra cara, no otro cerebro.

---

## 4. Regla de oro para no perderse

Cada vez que aparezca la pregunta "¿esto va en la app del vendedor o en el panel del proveedor?", la respuesta sale sola con esta regla: **¿la acción la hace quien consigue clientes o quien despacha productos?** Conseguir clientes → app vendedor. Despachar y cobrar liquidaciones → panel proveedor. Validar, aprobar y arbitrar → panel administrador (tú). Nada vive en dos lugares a la vez, y los tres miran los mismos pedidos.

---

## 5. Próximo paso

El prototipo del vendedor ya existe. La pieza que cierra el circuito es el **panel del proveedor**: bandeja de pedidos pagados por despachar, botón de "despachado" con número de guía, y la tabla de liquidaciones (lo recaudado, la comisión SOCIO, lo que se le transfiere) — que además es el documento que sostiene el modelo tributario del comisionista.
