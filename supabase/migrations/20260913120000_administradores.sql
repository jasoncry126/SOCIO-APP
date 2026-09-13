-- =============================================================================
-- SOCIO · Acceso de administración
--
-- Quién es administrador de SOCIO vive en una tabla de la base, no en el
-- código de la página. La página es pública: cualquier "clave de admin"
-- escrita ahí la puede leer cualquiera.
--
-- Las acciones de administrador (validar un pago, aprobar un producto,
-- validar la identidad de un socio) NO se hacen escribiendo directo en las
-- tablas, sino llamando a las funciones de la sección 3. Cada una comprueba
-- primero que quien llama sea administrador y deja constancia en la bitácora.
--
-- Por qué así y no con permisos normales: los permisos por columna de la
-- migración anterior aplican al rol 'authenticated', y un administrador
-- también es 'authenticated'. Sin estas funciones, para dejar que el admin
-- marque a un socio como validado habría que abrir esa columna a TODOS los
-- socios, que es justo lo que se quería evitar.
--
-- Además, esto deja el camino hecho para el día que estas acciones se muevan
-- a un servidor propio: la app ya no escribe en las tablas, solo pide "valida
-- este pago". Cambiar quién atiende esa petición no toca la app.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · Quién es administrador
-- ---------------------------------------------------------------------------

create table administradores (
  id         uuid primary key,          -- el id de su cuenta en Supabase Auth
  nombre     text not null,
  creado_en  timestamptz default now()
);

alter table administradores enable row level security;

-- Un administrador puede comprobar que lo es. Nada más.
create policy "el administrador se ve a sí mismo"
  on administradores for select
  using (id = auth.uid());

-- Nadie se nombra administrador a sí mismo desde la app: las altas se hacen
-- desde el tablero de Supabase, a mano, por quien tiene acceso al proyecto.
revoke insert, update, delete on administradores from anon, authenticated;

-- 'security definer' para que la comprobación funcione aunque quien pregunta
-- no tenga permiso de leer la tabla entera.
create or replace function es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from administradores a where a.id = auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- 2 · Lo que el administrador puede VER
-- ---------------------------------------------------------------------------
--
-- Se suman a las reglas que ya había: un socio sigue viendo solo lo suyo y una
-- marca solo lo suyo. Esto no le quita visibilidad a nadie, solo se la da a
-- SOCIO, que necesita ver todo para arbitrar.

create policy "SOCIO ve todos los socios"
  on usuarios_socios for select using (es_admin());

create policy "SOCIO ve todas las marcas"
  on marcas for select using (es_admin());

create policy "SOCIO ve todos los productos"
  on productos for select using (es_admin());

create policy "SOCIO ve todas las presentaciones"
  on presentaciones for select using (es_admin());

create policy "SOCIO ve todos los pedidos"
  on pedidos for select using (es_admin());

create policy "SOCIO ve todos los items de pedido"
  on pedido_items for select using (es_admin());

create policy "SOCIO ve todos los pagos"
  on pagos for select using (es_admin());

create policy "SOCIO ve todo el dinero liberado"
  on liberaciones_dinero for select using (es_admin());

create policy "SOCIO ve todos los retiros"
  on retiros for select using (es_admin());

-- La bitácora es la defensa ante un reclamo: SOCIO tiene que poder leerla.
-- Sigue sin poder editarse ni borrarse por nadie.
create policy "SOCIO lee la bitácora"
  on bitacora for select using (es_admin());

-- ---------------------------------------------------------------------------
-- 3 · Lo que el administrador puede HACER
-- ---------------------------------------------------------------------------

-- Validar o rechazar el pago de un pedido, tras cruzarlo contra el estado de
-- cuenta. Al validarlo, el pedido pasa a 'pagado' y la marca ya puede despachar.
create or replace function validar_pago(
  p_pago_id  uuid,
  p_validado boolean,
  p_motivo   text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedido uuid;
  v_estado text;
begin
  if not es_admin() then
    raise exception 'Solo un administrador de SOCIO puede validar pagos';
  end if;

  v_estado := case when p_validado then 'validado' else 'rechazado' end;

  update pagos
     set estado       = v_estado,
         validado_por = auth.uid(),
         validado_en  = now()
   where id = p_pago_id
     and estado = 'pendiente'
  returning pedido_id into v_pedido;

  if v_pedido is null then
    raise exception 'Ese pago no existe, o ya fue validado o rechazado antes';
  end if;

  if p_validado then
    update pedidos set estado = 'pagado'
     where id = v_pedido and estado = 'pendiente_pago';
  end if;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('pagos', p_pago_id, 'pago_' || v_estado, auth.uid(), 'admin',
          jsonb_build_object('pedido_id', v_pedido, 'motivo', p_motivo));
end;
$$;

-- Aprobar o rechazar un producto que una marca envió a revisión.
create or replace function aprobar_producto(
  p_producto_id uuid,
  p_aprobado    boolean,
  p_motivo      text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not es_admin() then
    raise exception 'Solo un administrador de SOCIO puede aprobar productos';
  end if;

  update productos
     set estado = case when p_aprobado then 'aprobado' else 'rechazado' end,
         activo = p_aprobado
   where id = p_producto_id;

  if not found then
    raise exception 'Ese producto no existe';
  end if;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('productos', p_producto_id,
          case when p_aprobado then 'producto_aprobado' else 'producto_rechazado' end,
          auth.uid(), 'admin', jsonb_build_object('motivo', p_motivo));
end;
$$;

-- Marcar la identidad de un socio como verificada.
create or replace function validar_socio(
  p_socio_id uuid,
  p_validado boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not es_admin() then
    raise exception 'Solo un administrador de SOCIO puede validar identidades';
  end if;

  update usuarios_socios set validado = p_validado where id = p_socio_id;

  if not found then
    raise exception 'Ese socio no existe';
  end if;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo)
  values ('usuarios_socios', p_socio_id,
          case when p_validado then 'socio_validado' else 'socio_invalidado' end,
          auth.uid(), 'admin');
end;
$$;

-- Las funciones son llamables por cualquiera con sesión; lo que decide es la
-- comprobación de es_admin() que llevan dentro. Sin sesión, ni eso.
revoke execute on function validar_pago(uuid, boolean, text)      from anon;
revoke execute on function aprobar_producto(uuid, boolean, text)  from anon;
revoke execute on function validar_socio(uuid, boolean)           from anon;

commit;
