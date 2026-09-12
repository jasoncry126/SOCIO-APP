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

## Tres cosas que conviene decidir antes de poner dinero real

No las cambié porque el pedido era implementar el diseño tal cual, y son decisiones
de producto, no erratas. Pero las tres son verificables hoy con
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

## Nota sobre `auth.uid()`

Las políticas comparan `auth.uid()` con el `id` de la fila, es decir: el identificador
de la cuenta en Supabase Auth debe ser **el mismo** que el `id` en `usuarios_socios` o
en `marcas`. Al crear cada socio y cada marca hay que insertar la fila con el `id` que
Supabase Auth le asignó a esa cuenta, no con uno nuevo. Si se deja que
`gen_random_uuid()` genere el `id`, las políticas no encontrarán coincidencia y el
usuario no verá ni su propio perfil.
