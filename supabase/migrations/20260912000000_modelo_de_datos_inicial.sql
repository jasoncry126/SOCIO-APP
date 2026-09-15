-- =============================================================================
-- SOCIO · Modelo de datos inicial (Supabase / Postgres)
--
-- Implementación literal de docs/13-modelo-de-datos.md. Las tablas, columnas,
-- tipos, defaults, checks, claves foráneas, políticas RLS, la función y el
-- trigger son exactamente los definidos en ese documento: esta migración NO
-- introduce cambios de diseño.
--
-- Las tablas se crean en orden de dependencia (una clave foránea exige que la
-- tabla referenciada ya exista), que coincide con el orden del documento.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1 · Cuentas
-- -----------------------------------------------------------------------------

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

-- -----------------------------------------------------------------------------
-- 2 · Catálogo
-- -----------------------------------------------------------------------------

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

create table presentaciones (
  id              uuid primary key default gen_random_uuid(),
  producto_id     uuid not null references productos(id) on delete cascade,
  nombre          text not null,             -- 'Vial 50 mg', 'Talla M'...
  precio_mayorista numeric(10,2) not null,   -- lo que cobra la marca, siempre
  precio_publico   numeric(10,2) not null,   -- precio de página, mínimo de venta
  stock_almacen    int default 0,
  stock_punto      int default 0,
  check (precio_publico > precio_mayorista)  -- sin esto no hay margen que repartir
);

-- -----------------------------------------------------------------------------
-- 3 · Pedidos
-- -----------------------------------------------------------------------------

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

create table pedido_items (
  id              uuid primary key default gen_random_uuid(),
  pedido_id       uuid not null references pedidos(id) on delete cascade,
  presentacion_id uuid not null references presentaciones(id),
  cantidad        int not null check (cantidad > 0),
  precio_unit_socio numeric(10,2) not null,   -- congelado al momento de la venta
  precio_unit_mayorista numeric(10,2) not null
);

-- -----------------------------------------------------------------------------
-- 4 · Pagos — donde se resuelve el problema del voucher
-- -----------------------------------------------------------------------------

create table pagos (
  id                uuid primary key default gen_random_uuid(),
  pedido_id         uuid not null references pedidos(id) unique,   -- un pago por pedido
  numero_operacion  text not null unique,       -- la regla que mata el voucher reciclado
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

-- -----------------------------------------------------------------------------
-- 5 · Dinero — pagos por hitos a la marca
-- -----------------------------------------------------------------------------

create table liberaciones_dinero (
  id          uuid primary key default gen_random_uuid(),
  pedido_id   uuid not null references pedidos(id),
  marca_id    uuid not null references marcas(id),
  hito        text not null check (hito in ('guia_registrada','entrega_confirmada')),
  monto       numeric(10,2) not null,
  liberado_en timestamptz default now()
);

create table retiros (
  id          uuid primary key default gen_random_uuid(),
  marca_id    uuid references marcas(id),
  socio_id    uuid references usuarios_socios(id),
  monto       numeric(10,2) not null,
  estado      text default 'solicitado' check (estado in ('solicitado','transferido','rechazado')),
  solicitado_en timestamptz default now(),
  transferido_en timestamptz
);

-- -----------------------------------------------------------------------------
-- 6 · Bitácora — defensa ante cualquier reclamo
-- -----------------------------------------------------------------------------

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

-- -----------------------------------------------------------------------------
-- 7 · El trigger que mantiene los niveles al día
-- -----------------------------------------------------------------------------

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

commit;
