# Backend de SOCIO en Supabase

Este directorio contiene el modelo de datos de `docs/13-modelo-de-datos.md` convertido
en una migración ejecutable, más las pruebas que confirman que funciona.

**La migración es una copia literal del documento.** No se cambió ningún nombre de
tabla, columna, tipo, valor por defecto, restricción ni política de permisos. Lo
único que se añadió son comentarios, el orden de creación (una tabla no puede
referenciar otra que aún no existe) y el `begin/commit` que hace que se aplique todo
o nada.

```
supabase/
  migrations/
    20260912000000_modelo_de_datos_inicial.sql   ← las 10 tablas + RLS + trigger
  reiniciar-desde-cero.sql   ← ⚠️ borra las 10 tablas, para volver a empezar limpio
  verificacion/
    comprobar-en-supabase.sql ← pégalo en el SQL Editor: dice si quedó bien aplicada
    ejecutar-local.sh        ← levanta un Postgres temporal y prueba todo
    00-stub-supabase.sql     ← imita lo que Supabase ya trae (auth.uid, roles)
    01-inspeccionar-esquema.sql
    02-probar-reglas-negocio.sql
    03-probar-aislamiento-rls.sql
    04-cobertura-rls-faltante.sql
    05-circuito-de-venta.sql   ← el circuito completo, con la máquina de estados
    06-ataques.sql             ← 13 intentos de saltarse las reglas
    07-administrador.sql
    08-estructura-fiscal.sql   ← privacidad de importes, comprobantes, estados
    09-manual-operativo.sql    ← liquidación por hitos, candado logístico
    10-especificacion-tecnica.sql ← PVP, foto de la guía, orden del reporte
    12-quien-mueve-el-pedido.sql  ← los dos huecos de permisos que tocaban dinero
```

---

## Cómo aplicarlo a tu proyecto Supabase

Todavía **no está aplicado a ningún Supabase real** — esta sesión no tiene acceso a
un proyecto (ni URL, ni clave, ni contraseña de base de datos), así que no había
dónde crear las tablas. Cuando tengas el proyecto, cualquiera de estas tres vías lo
aplica:

**Opción A — pegar y listo (la más rápida, no necesita instalar nada).**
Entra a tu proyecto en supabase.com → **SQL Editor** → **New query**, pega todo el
contenido de `migrations/20260912000000_modelo_de_datos_inicial.sql`, y pulsa **Run**.
Si algo falla, no se crea nada a medias: la migración es una sola transacción.

> **Si al pulsar Run sale `relation "usuarios_socios" already exists`:** la migración ya
> se aplicó antes y estás ejecutándola por segunda vez. Postgres se detiene en la primera
> tabla y no toca nada — la base queda intacta. Comprueba el estado con
> `verificacion/comprobar-en-supabase.sql` (esperado: 10 tablas · 7 políticas · 1 función ·
> 1 trigger). Solo si algo falta, y solo mientras la base esté vacía, usa
> `reiniciar-desde-cero.sql` y vuelve a aplicar la migración.

**Opción B — con el CLI de Supabase** (deja registro de la migración):
```bash
supabase link --project-ref <tu-project-ref>
supabase db push
```

**Opción C — con `psql`** (la cadena de conexión está en Project Settings → Database):
```bash
psql "postgresql://postgres:<clave>@db.<ref>.supabase.co:5432/postgres" \
  -v ON_ERROR_STOP=1 -f supabase/migrations/20260912000000_modelo_de_datos_inicial.sql
```

---

## Qué se verificó, y cómo

La migración se ejecutó contra un PostgreSQL 16 real (un cluster temporal y
desechable, no un Supabase) y se comprobó una por una las "reglas de oro" que el
documento dice que el modelo hace cumplir solo. Para reproducirlo:

```bash
./supabase/verificacion/ejecutar-local.sh
```

Resultado: **se crean las 10 tablas, las 7 políticas RLS, las 13 restricciones
`check`, las 11 claves foráneas, las 7 restricciones `unique`, la función y el
trigger.** Y de las cinco reglas de oro del documento:

| Regla de oro (docs/13) | Estado |
|---|---|
| 2 · Un número de operación no puede pagar dos pedidos | ✅ el segundo intento falla en la base |
| 3 · Un pedido nunca cambia de precio después de creado | ✅ los montos quedan congelados en `pedido_items` |
| 5 · El nivel del socio se recalcula solo | ✅ al pasar a `entregado`: 9 ventas/bronce → 10 ventas/plata, y no vuelve a contar si ya estaba entregado |
| 1 · Una marca no ve pedidos que no son suyos | ✅ una segunda marca consulta `pedidos` y recibe 0 filas |
| 1 · Un socio no ve el catálogo en construcción de otra marca | ✅ solo ve los productos `aprobado` + `activo` |

También se confirmó que `presentaciones` rechaza un precio público menor al
mayorista (sin margen no hay nada que repartir) y que sólo puede existir un pago
por pedido.

---

## La segunda migración: permisos para operar

`20260912100000_permisos_para_operar.sql` es obligatoria para que la app
funcione, no opcional. `docs/13` define quién puede LEER cada tabla, pero no
quién puede ESCRIBIR, y con RLS activo lo que no está permitido queda
prohibido. Sin ella, comprobado contra PostgreSQL 16:

| Acción | Sin la 2ª migración |
|---|---|
| Una marca se registra | bloqueado |
| Un socio se registra | bloqueado |
| El socio registra un pedido | bloqueado |
| La marca despacha | 0 filas, **sin error** |
| El nivel del socio sube al entregar | no sube, **sin error** |

Además cierra las tres brechas de la sección siguiente, así que no cuesta
trabajo extra. Añade sobre lo de `docs/13`:

- permisos de escritura acotados a lo propio (cada quien crea y edita lo suyo);
- RLS en las 6 tablas que no lo tenían;
- la vista `catalogo_publico`, por la que el socio ve el catálogo **sin** la
  columna `precio_mayorista` (CLAUDE.md regla nº 1, ahora en la base);
- permisos por columna: un socio no puede ponerse `nivel = 'diamante'` ni una
  marca `nivel_fiabilidad = 'aliada'`. Ambas cosas funcionaban y se probaron;
- `security definer` en `actualizar_nivel_socio()`: el trigger corría con los
  permisos de la marca, que no puede tocar la ficha del socio, así que el nivel
  nunca subía.

Se verifica con `./supabase/verificacion/ejecutar-local.sh`, que ahora corre el
circuito de venta completo (`05-circuito-de-venta.sql`) y una batería de 13
ataques (`06-ataques.sql`): leer el mayorista, ver pedidos ajenos, validarse el
propio pago, regalarse dinero, borrar la bitácora, ascenderse de nivel.

---

## Tres cosas que conviene decidir antes de poner dinero real

> **Ya resueltas por la 2ª migración.** Esta sección se queda como registro de
> qué estaba abierto y por qué; las tres brechas que describe están cerradas.

No las cambié en su momento porque el pedido era implementar el diseño tal cual,
y son decisiones de producto, no erratas. Pero las tres son verificables hoy con
`04-cobertura-rls-faltante.sql`, y las tres importan:

**1. Seis de las diez tablas quedan sin reglas de permisos.** El documento define RLS
sólo para `usuarios_socios`, `marcas`, `productos` y `pedidos`. Para
`presentaciones`, `pedido_items`, `pagos`, `liberaciones_dinero`, `retiros` y
`bitacora` no define ninguna. En Supabase, una tabla sin RLS queda **legible y
escribible por cualquier usuario con sesión**, porque la API web expone
automáticamente todo lo que hay en la base. En la prueba, un socio sin ningún pedido
propio pudo leer los pagos de otro socio y los montos de sus vouchers.

**2. Esto choca de frente con la regla nº 1 de `CLAUDE.md`:** "el socio nunca ve el
precio mayorista". Hoy no lo ve *en la pantalla*, pero `presentaciones` guarda
`precio_mayorista` sin RLS, así que cualquier socio puede pedírselo a la API
directamente. El documento confía esa regla a la interfaz; para que la base la haga
cumplir sola —que es el objetivo declarado de `docs/13`— haría falta una política en
`presentaciones`, o mover `precio_mayorista` a una vista que el socio no pueda leer.

**3. La bitácora sí se puede borrar.** La regla nº 4 dice "nadie puede editar la
bitácora", pero la línea que lo impediría (`revoke update, delete on bitacora`) está
comentada en el documento, así que la dejé comentada. En la prueba, un socio cualquiera
insertó una fila falsa en `bitacora` y después la borró. Mientras siga así, la bitácora
no sirve como defensa ante un reclamo, que es justamente para lo que existe.

Las tres se arreglan con una segunda migración corta. Dime si quieres que la prepare
y te explico cada política en términos de quién puede ver qué.

---

## La cuarta migración: estructura fiscal

`20260913180000_estructura_fiscal.sql` implementa la sección 4 del informe del
contador (resumida en `docs/15-estructura-fiscal.md`), que es de cumplimiento
obligatorio, no una mejora opcional:

| Lo que pide el contador | Cómo queda en la base |
|---|---|
| **A** · Segmentar los campos financieros por rol | se retira el permiso de leer `precio_mayorista`, `comision_socio_app`, `precio_socio`, `ganancia_socio` y `precio_unit_mayorista` sobre las tablas, y cada rol lee por su vista: `pedidos_socio`, `pedidos_marca`, `pedidos_admin`, `pedido_items_socio`, `pedido_items_marca` |
| **B** · Que el vendedor gestione sus comprobantes | `usuarios_socios` gana `ruc`, `razon_social`, `direccion_fiscal`, `emite_comprobante`; `pedidos` gana los cuatro campos del comprobante; se registra con `registrar_comprobante()` |
| **C** · Máquina de estados con despacho bloqueado | nuevo estado `validado`; el trigger `trg_pedido_transicion` prohíbe cualquier salto y exige guía + courier + tracking para pasar a `en_camino`; `trg_pago_registrado` mueve el pedido solo cuando el vendedor declara el pago |
| **D** · Reporte contable exportable | la vista `reporte_contable`, visible solo para SOCIO, con la comisión desglosada en neto e IGV |

Además cierra dos agujeros que la revisión dejó a la vista y que venían de las
migraciones anteriores:

- **la marca podía reescribir los importes de un pedido cerrado** — tenía
  `update` sobre todas las columnas, no solo sobre estado y guía. Podía subirse
  el `precio_mayorista` después de la venta y cobrar de más;
- **la marca podía marcar un pedido como entregado sin haberlo despachado**, y
  con eso subirle el nivel al socio sin que hubiera salido nada del almacén.

Un cambio de comportamiento que hay que tener presente: **`validar_pago()` ahora
deja el pedido en `validado`, no en `pagado`.** «Pagado» pasó a significar «el
vendedor declaró el pago»; el permiso para despachar es `validado`. Cualquier
código que compare contra `'pagado'` para decidir si se puede despachar hay que
cambiarlo.

Se verifica igual que las demás:

```bash
./supabase/verificacion/ejecutar-local.sh
```

que ahora corre también `08-estructura-fiscal.sql`: 30 comprobaciones de las
cuatro secciones, incluidos los intentos de leer el importe ajeno, de reescribir
los precios de un pedido cerrado y de saltarse la máquina de estados por los
cinco atajos posibles.

---

## La quinta migración: manual operativo

`20260915100000_manual_operativo.sql` aplica el «Manual de Flujo Operativo y
Tributario» del contador, que concreta el informe anterior paso por paso
(resumido en `docs/15-estructura-fiscal.md`, sección 6):

| Lo que pide el manual | Cómo queda en la base |
|---|---|
| **PASO 1** · La boleta lleva una descripción comercial genérica | `productos.nombre_comprobante`, visible en `catalogo_publico` y en la plantilla de carga |
| **PASO 3** · Despacho con evidencia obligatoria | la guía de remisión se exige siempre; courier y tracking, solo en envío por agencia |
| **PASO 4** · Liquidación | `trg_liquidar_hito` escribe en `liberaciones_dinero` en cada hito, con el reparto de `docs/08` según el nivel de fiabilidad de la marca |
| **4.3** · Botón de exportación | pestaña **Contabilidad** en `app/administrador.html`, con CSV para Excel en español |

**Corrige un fallo de la migración anterior.** La regla "sin guía, courier y
tracking no se despacha" se escribió pensando solo en el envío nacional. Una
entrega local en la misma ciudad no tiene courier ni tracking, así que tal como
estaba **ningún pedido de entrega a domicilio podía despacharse nunca**.

La liquidación paga siempre *el resto* en el segundo hito, no un porcentaje
recalculado: así la marca cobra su mayorista exacto en los cuatro niveles de
fiabilidad, sin que el redondeo le quite ni le regale céntimos. Comprobado nivel
por nivel en `09-manual-operativo.sql`.

Las entregas cumplidas se cuentan solas, pero ninguna marca sube de nivel sola:
los niveles de `docs/08` piden historial limpio y antigüedad, que un contador de
entregas no sabe. Promover es decisión de SOCIO.

---

## La sexta migración: especificación técnica

`20260915180000_especificacion_tecnica.sql` cierra los dos huecos del tercer
documento del contador (detalle en `docs/15-estructura-fiscal.md`, sección 9):

- **El PVP pasa a ser una columna propia** de `pedidos`, calculada y almacenada.
  La especificación pide los cuatro montos por separado; el precio de venta se
  venía sumando al vuelo. Al ser calculada, no se puede escribir a mano ni quedar
  desfasada de sus sumandos.

- **La foto de la guía de remisión es obligatoria para despachar.** Antes solo se
  exigía el número. Un número se inventa; una foto, no. Se crea además el cubo
  privado `guias` en Supabase Storage, donde cada marca solo escribe en su propia
  carpeta y nadie puede borrar ni reemplazar lo ya subido.

- **El reporte contable reordena sus ocho primeras columnas** al orden y los
  nombres que fija la especificación, conservando el resto detrás.

El bloque de Storage va condicionado a que exista el esquema `storage`, para que
la migración se pueda probar también en un Postgres normal.

---

## La octava migración: quién mueve el pedido

`20260920120000_quien_mueve_el_pedido.sql` cierra los dos huecos de permisos
que tocaban dinero, de los seis que encontró la revisión de las reglas RLS.

**1 · Una marca podía darse por pagada sola y cobrar.** La marca tiene permiso
de escribir `estado` en sus propios pedidos, y el candado de estados comprobaba
el *orden* de la transición pero no *quién* la hacía. Con eso recorría ella sola
el camino entero —pendiente de pago → pagado → validado → en camino → entregado—
y al final se liquidaba su precio mayorista íntegro, sin que existiera ningún
pago ni ningún administrador de SOCIO de por medio. Probado contra PostgreSQL 16:
pedido de S/ 180, cero filas en `pagos`, S/ 100 liberados a la marca.

El candado ahora comprueba también la autoría, con dos reglas de negocio:

| Paso | Quién |
|---|---|
| → `pagado` | tiene que existir un pago declarado para ese pedido (y declararlo solo se puede por `declarar_pago()`, que exige que el pedido sea del socio que llama) |
| → `validado` | solo un administrador de SOCIO (`es_admin()`), que es lo que el estado `validado` significaba desde que se creó |

La función pasa a `security definer` para que la comprobación del pago sea
fiable venga de quien venga.

**2 · El socio podía deducir el precio mayorista y la comisión de SOCIO.** Se le
había dejado leer las liquidaciones de sus pedidos para que supiera si estaban
cerrados, pero esas filas llevan el monto, y la suma de los dos hitos es el
mayorista exacto de la marca. Probado: mayorista real S/ 100.00, el socio leyó
S/ 100.00. Es la regla nº 1 de `CLAUDE.md`, la misma que `pedidos_socio` y
`pedido_items_socio` sostienen columna por columna.

Se retira esa política y en su lugar queda la vista `liquidaciones_socio`, con
el hito y la fecha pero sin el importe — el mismo remedio que ya se usó con
`catalogo_publico` para el precio mayorista del catálogo.

**Qué NO cambia:** ni el panel de la marca ni el de SOCIO escriben estados desde
el navegador, y nadie lee `liberaciones_dinero` desde la app, así que las tres
pantallas siguen funcionando igual.

Se verifica con `12-quien-mueve-el-pedido.sql`, que recorre los dos atajos
cerrados y después el camino legítimo completo, hasta ver a la marca cobrar sus
dos hitos con un pago validado detrás.

**Los otros cuatro huecos siguen abiertos**, a la espera de una segunda
migración: la marca puede deducir lo que paga el socio leyendo
`pagos.monto_esperado`; una marca puede aprobar y publicar su propio catálogo
sin revisión de SOCIO; cualquiera puede pedir un retiro de cualquier monto y
colgárselo a otra marca; y la bitácora se puede firmar a nombre ajeno.

---

## Nota sobre `auth.uid()`

Las políticas comparan `auth.uid()` con el `id` de la fila, es decir: el identificador
de la cuenta en Supabase Auth debe ser **el mismo** que el `id` en `usuarios_socios` o
en `marcas`. Al crear cada socio y cada marca hay que insertar la fila con el `id` que
Supabase Auth le asignó a esa cuenta, no con uno nuevo. Si se deja que
`gen_random_uuid()` genere el `id`, las políticas no encontrarán coincidencia y el
usuario no verá ni su propio perfil.

---

## Conectar los paneles a la base

1. Abre `app/socio-config.js` y pega el **Project URL** y la clave **anon public**
   de tu proyecto (Settings → API). Las dos son públicas por diseño: viajan
   dentro de la página. La clave `service_role` y la contraseña de la base
   **nunca** van ahí.
2. En Supabase, **Authentication → Sign In / Providers**, desactiva
   **«Confirm email»**. El panel registra a marcas y socios con celular y clave;
   si Supabase exige confirmar un correo, la cuenta queda sin sesión y la base
   rechaza el alta de su ficha.

Mientras `socio-config.js` esté vacío, los paneles siguen funcionando como antes
— cada uno guardando en su propio navegador — y muestran un aviso de que están
en modo de prueba. Así se pueden abrir sin configurar nada.

### Carga masiva del catálogo

El panel de la marca (`app/proveedor.html` → **Mi catálogo**) acepta un CSV con
una fila por presentación. Hay un botón para descargar la plantilla.

Se valida todo antes de guardar nada, con las mismas reglas del asistente de
carga uno-por-uno: sin precio no se publica (docs/10), el precio de página tiene
que superar al mayorista (docs/07 y el `check` de la base), y no puede haber
presentaciones repetidas. Si algo falla, dice qué fila y por qué, y no sube nada.

Lo que entra queda **en revisión**, igual que en el asistente: subir 60 productos
de golpe no es una puerta trasera para autopublicarse. Volver a subir el mismo
archivo actualiza los productos que ya existan en vez de duplicarlos, y nunca
borra una presentación (podría estar referenciada por un pedido).

La lógica de lectura y validación vive en `app/socio-catalogo.js`, aparte del
panel y sin dependencias, y tiene pruebas:

```bash
node app/pruebas/probar-catalogo.js
```

## La app del socio, probada en un navegador

Las pruebas de arriba comprueban la base y los cálculos por separado. Falta lo
que solo se ve juntando las dos partes: que `vendedor.html` arranque sin errores,
que enseñe el catálogo de la base y no el de demostración, y que al registrar una
venta **no mande ningún precio** —los importes los calcula `crear_pedido()`, y si
viajaran desde el teléfono cualquiera podría editarlos antes de que salgan.

```bash
npm install playwright-core && npx playwright install chromium   # solo la 1ª vez
node app/pruebas/probar-vendedor-en-navegador.js
```

Abre la app en Chromium contra un Supabase de mentira, en los tres estados en que
puede encontrarse: **conectada**, **sin configurar** (sigue con los 47 productos
de demostración, como siempre) y **configurada pero caída**, donde lo que se
comprueba es que se niegue a enseñar un catálogo que no es el real.

La marca de prueba despacha desde Arequipa y Trujillo a propósito, y no desde
Cusco y Lima: así, si algo vuelve a leer la lista fija de `ORIGENES` en vez de las
ciudades de la marca, la prueba lo canta.

Si Chromium no está instalado la prueba se salta y lo dice, en vez de fallar.
