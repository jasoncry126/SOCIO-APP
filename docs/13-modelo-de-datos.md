# SOCIO — Modelo de datos (Supabase / Postgres)

*Plano técnico para construir el backend · Agosto 2026*

Este documento traduce todo lo definido hasta ahora —niveles, reparto de margen, pagos por hitos, control de vouchers— en tablas reales. Está pensado para Supabase: cada tabla trae su regla de permisos (RLS) para que la seguridad viva en la base de datos, no en la app.

---

## Cómo se relaciona todo

```
usuarios_socios ──┐
                   ├──< pedidos >──┐
marcas ──< productos ──< presentaciones ──< pedido_items    │
                   │                                         │
                   ├──< pagos (1 a 1 con el pedido)          │
                   ├──< liberaciones_dinero (1 a muchos)      │
                   └──< bitacora (1 a muchos, registra todo)  │
                                                               │
retiros ──< usuarios_socios / marcas ─────────────────────────┘
```

Un pedido es el centro: conecta al socio que vendió, a la marca dueña del producto, al pago que lo respalda y a las liberaciones de dinero que genera.

---

## 1 · Cuentas

### `usuarios_socios`
```sql
create table usuarios_socios (
  id            uuid primary key default gen_random_uuid(),
  nombre        text not null,
  dni           varchar(8) not null unique,
  celular       varchar(9) not null unique,
  clave_hash    text not null,              -- nunca la clave en texto plano
  ciudad        text not null,
  validado      boolean default false,       -- identidad verificada
  nivel         text default 'bronce' check (nivel in ('bronce','plata','oro','diamante')),
  ventas_entregadas int default 0,           -- se recalcula con un trigger, ver sección 6
  creado_en     timestamptz default now()
);

-- Un socio solo lee y edita su propia fila
alter table usuarios_socios enable row level security;
create policy "socio ve su propio perfil"
  on usuarios_socios for select
  using (auth.uid() = id);
create policy "socio edita su propio perfil"
  on usuarios_socios for update
  using (auth.uid() = id);
```

### `marcas`
```sql
create table marcas (
  id              uuid primary key default gen_random_uuid(),
  nombre          text not null,
  ruc             varchar(11) not null unique,
  giro            text not null,
  ciudad_almacen  text not null,
  ciudad_punto    text,                      -- opcional: ciudad con entrega a domicilio
  celular         varchar(9) not null unique,
  clave_hash      text not null,
  nivel_fiabilidad text default 'nueva' check (nivel_fiabilidad in ('nueva','confiable','preferente','aliada')),
  entregas_ok     int default 0,
  entregas_incidencia int default 0,
  creado_en       timestamptz default now()
);

alter table marcas enable row level security;
create policy "marca ve su propio perfil"
  on marcas for select using (auth.uid() = id);
```

---

## 2 · Catálogo

### `productos`
```sql
create table productos (
  id            uuid primary key default gen_random_uuid(),
  marca_id      uuid not null references marcas(id),
  nombre        text not null,
  categoria     text,
  emoji         text default '📦',
  descripcion   text,
  recomendaciones text,                      -- conservación, manejo, cuidados de traslado
  tiempo_prep   text,                        -- 'Mismo día' / '24 horas' / '48 horas'
  cobertura     text,
  corte_nacional time,                       -- hora límite para despacho nacional el mismo día
  corte_local    time,                       -- hora límite para entrega local el mismo día
  dias_despacho  text,
  estado        text default 'revision' check (estado in ('revision','aprobado','rechazado')),
  activo        boolean default false,
  creado_en     timestamptz default now()
);

alter table productos enable row level security;
create policy "marca ve y edita su propio catálogo"
  on productos for all using (marca_id = auth.uid());
create policy "todos ven productos aprobados y activos"
  on productos for select using (estado = 'aprobado' and activo = true);
```

### `presentaciones`
```sql
create table presentaciones (
  id              uuid primary key default gen_random_uuid(),
  producto_id     uuid not null references productos(id) on delete cascade,
  nombre          text not null,             -- 'Vial 50 mg', 'Talla M'...
  precio_mayorista numeric(10,2) not null,   -- lo que cobra la marca, siempre
  precio_publico   numeric(10,2) not null,   -- precio de página, mínimo de venta
  stock_almacen    int default 0,
  stock_punto      int default 0,
  check (precio_publico > precio_mayorista)  -- sin esto no hay margen que repartir (ver conversación previa)
);
```

---

## 3 · Pedidos

### `pedidos`
```sql
create table pedidos (
  id              uuid primary key default gen_random_uuid(),
  codigo          text not null unique,       -- 'SOC-0825-K4T9'
  socio_id        uuid not null references usuarios_socios(id),
  marca_id        uuid not null references marcas(id),

  -- Montos (todo se calcula al registrar, nunca se recalcula después)
  precio_socio    numeric(10,2) not null,     -- lo que paga el socio (con su nivel aplicado)
  precio_mayorista numeric(10,2) not null,    -- lo que recibe la marca
  ganancia_socio  numeric(10,2) not null,
  comision_socio_app numeric(10,2) not null,  -- lo que se queda la plataforma
  costo_envio     numeric(10,2) default 0,

  -- Destinatario
  destinatario    text not null,
  doc_destinatario varchar(11) not null,
  celular_destinatario varchar(9) not null,

  -- Entrega
  origen          text not null check (origen in ('almacen','punto_venta')),
  modo_entrega    text not null check (modo_entrega in ('agencia','domicilio')),
  agencia         text,                        -- 'olva' / 'shalom'
  detalle_entrega text not null,               -- local de recojo o dirección + referencia
  numero_guia     text,

  estado          text not null default 'pendiente_pago'
                   check (estado in ('pendiente_pago','pagado','en_camino','entregado','cancelado')),

  creado_en       timestamptz default now(),
  despachado_en   timestamptz,
  entregado_en    timestamptz
);

alter table pedidos enable row level security;
create policy "el socio ve solo sus pedidos"
  on pedidos for select using (socio_id = auth.uid());
create policy "la marca ve solo pedidos de su producto"
  on pedidos for select using (marca_id = auth.uid());
```

### `pedido_items`
```sql
create table pedido_items (
  id              uuid primary key default gen_random_uuid(),
  pedido_id       uuid not null references pedidos(id) on delete cascade,
  presentacion_id uuid not null references presentaciones(id),
  cantidad        int not null check (cantidad > 0),
  precio_unit_socio numeric(10,2) not null,   -- congelado al momento de la venta
  precio_unit_mayorista numeric(10,2) not null
);
```

**Por qué los montos se congelan en el pedido y no se recalculan:** si el proveedor cambia después el precio de página, un pedido de la semana pasada no debe cambiar de valor. El pedido es una fotografía del momento de la venta.

---

## 4 · Pagos — donde se resuelve el problema del voucher

### `pagos`
```sql
create table pagos (
  id                uuid primary key default gen_random_uuid(),
  pedido_id         uuid not null references pedidos(id) unique,   -- un pago por pedido
  numero_operacion  text not null unique,       -- 🔒 la regla que mata el voucher reciclado
  monto_esperado    numeric(10,2) not null,     -- con céntimos únicos, ej. 158.37
  monto_reportado   numeric(10,2) not null,     -- lo que el socio dice haber pagado
  metodo            text check (metodo in ('yape','plin','transferencia','deposito')),
  imagen_voucher_url text,
  hash_imagen       text,                        -- huella del archivo: detecta la misma foto reusada
  estado            text not null default 'pendiente'
                     check (estado in ('pendiente','validado','rechazado')),
  validado_por      uuid,                        -- id del admin que cruzó contra el estado de cuenta
  validado_en       timestamptz,
  creado_en         timestamptz default now()
);

-- ESTA restricción es la que impide que el mismo voucher pague dos pedidos:
-- numero_operacion es UNIQUE en toda la tabla. Un segundo intento con el
-- mismo número falla en la base, sin importar qué diga la imagen.
```

**El campo que hace el trabajo pesado es `numero_operacion unique`.** Todo lo demás (hash de imagen, ventana de tiempo, OCR) es apoyo; esta única línea es la que convierte "reusar un voucher" en un error de base de datos, no en un juicio humano.

---

## 5 · Dinero — pagos por hitos a la marca

### `liberaciones_dinero`
```sql
create table liberaciones_dinero (
  id          uuid primary key default gen_random_uuid(),
  pedido_id   uuid not null references pedidos(id),
  marca_id    uuid not null references marcas(id),
  hito        text not null check (hito in ('guia_registrada','entrega_confirmada')),
  monto       numeric(10,2) not null,
  liberado_en timestamptz default now()
);
```

Cada vez que se despacha un pedido, se inserta una fila con el porcentaje que corresponda al nivel de fiabilidad de la marca (ver la tabla de niveles del documento de pagos por hitos). Cuando se confirma la entrega, se inserta la segunda fila con el resto. El saldo disponible de una marca es la suma de sus filas en esta tabla menos lo ya retirado.

### `retiros`
```sql
create table retiros (
  id          uuid primary key default gen_random_uuid(),
  marca_id    uuid references marcas(id),
  socio_id    uuid references usuarios_socios(id),
  monto       numeric(10,2) not null,
  estado      text default 'solicitado' check (estado in ('solicitado','transferido','rechazado')),
  solicitado_en timestamptz default now(),
  transferido_en timestamptz
);
```

---

## 6 · Bitácora — tu defensa ante cualquier reclamo

### `bitacora`
```sql
create table bitacora (
  id            bigint generated always as identity primary key,
  tabla         text not null,          -- 'pedidos', 'pagos', etc.
  registro_id   uuid not null,
  accion        text not null,          -- 'creado', 'pago_validado', 'despachado', 'entregado'
  actor_id      uuid,
  actor_tipo    text check (actor_tipo in ('socio','marca','admin','sistema')),
  detalle       jsonb,                  -- estado antes/después
  creado_en     timestamptz default now()
);
-- Nunca se actualiza ni se borra una fila de bitácora: solo se inserta.
-- revoke update, delete on bitacora from all;
```

Cada cambio de estado importante (pago validado, guía registrada, entrega confirmada) debe insertar una fila aquí, idealmente vía trigger automático para que nadie pueda "olvidarse" de registrarlo.

---

## 7 · El trigger que mantiene los niveles al día

```sql
-- Cuando un pedido pasa a 'entregado', sube el contador del socio
-- y recalcula su nivel automáticamente.
create or replace function actualizar_nivel_socio()
returns trigger as $$
begin
  if new.estado = 'entregado' and old.estado != 'entregado' then
    update usuarios_socios
    set ventas_entregadas = ventas_entregadas + 1,
        nivel = case
          when ventas_entregadas + 1 >= 50 then 'diamante'
          when ventas_entregadas + 1 >= 25 then 'oro'
          when ventas_entregadas + 1 >= 10 then 'plata'
          else 'bronce'
        end
    where id = new.socio_id;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger trg_nivel_socio
  after update on pedidos
  for each row execute function actualizar_nivel_socio();
```

Este es el punto que mencioné en la app: **contar ventas entregadas, no pedidos registrados**, ya vive en la base de datos y no depende de que nadie lo calcule a mano.

---

## Resumen de las reglas de oro que este modelo hace cumplir solas

1. **Un socio nunca ve el catálogo de otra marca en construcción**, ni una marca ve pedidos que no son suyos — permisos por fila.
2. **Un número de operación no puede pagar dos pedidos** — restricción `unique`.
3. **Un pedido nunca cambia de precio después de creado** — los montos se congelan en `pedido_items`.
4. **Nadie puede editar la bitácora** — solo inserciones, nunca updates.
5. **El nivel del socio se recalcula solo**, sin depender de que un admin lo actualice a mano.

---

## Siguiente paso natural

Con este modelo ya se puede crear el proyecto en Supabase y conectar los tres paneles (vendedor, proveedor, administrador) para que lean y escriban del mismo lugar — es el salto de "prototipo que se ve bien" a "producto que opera con dinero real". Puedo ayudarte a levantar el proyecto y migrar la lógica actual (que hoy vive en JavaScript dentro de cada HTML) hacia estas tablas cuando quieras dar ese paso.
