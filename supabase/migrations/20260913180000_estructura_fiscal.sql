-- =============================================================================
-- SOCIO · Estructura fiscal y de custodia
--
-- Implementa la sección 4 del informe del contador ("Especificaciones Técnicas
-- para el Desarrollador del Aplicativo"), que es de cumplimiento obligatorio:
--
--   A · Los campos financieros se segmentan por rol. Nadie ve el número que no
--       le corresponde: el socio no ve el mayorista, la marca no ve la comisión
--       de la plataforma, el cliente final no ve nada de eso.
--   B · El vendedor puede registrar sus datos de emisor electrónico (RUC) y el
--       comprobante que emitió por cada venta, porque esa obligación es suya.
--   C · Máquina de estados con despacho bloqueado: sin guía de remisión y sin
--       tracking del courier, el pedido no avanza. Lo impide la base de datos,
--       no la pantalla.
--   D · Reporte contable exportable, para emitir las facturas globales.
--
-- De paso cierra dos agujeros que quedaban de las migraciones anteriores y que
-- la revisión del contador dejó a la vista:
--   · la marca podía reescribir los importes de un pedido (tenía update sobre
--     TODAS las columnas, no solo sobre el estado y la guía),
--   · la marca podía saltar un pedido directo a 'entregado' sin despacharlo.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0 · Columnas nuevas
-- ---------------------------------------------------------------------------

-- B · Datos de emisor electrónico del vendedor. Todos opcionales: un socio que
-- todavía no tiene RUC puede operar igual, pero entonces no puede emitir el
-- comprobante que la ley le exige. La app se lo dirá; la base no se lo impide,
-- porque quién puede vender sin RUC es una decisión de negocio, no técnica.
alter table usuarios_socios
  add column if not exists ruc              varchar(11),
  add column if not exists razon_social     text,
  add column if not exists direccion_fiscal text,
  add column if not exists emite_comprobante boolean default false;

-- C · Evidencia obligatoria del despacho. La guía de remisión y el tracking del
-- courier son lo que respalda que el bien salió: sin eso, ni SUNAT ni un
-- cliente que reclama tienen con qué.
alter table pedidos
  add column if not exists courier   text,     -- 'olva', 'shalom', 'motorizado'...
  add column if not exists tracking  text,     -- número de seguimiento del courier
  add column if not exists guia_url  text;     -- imagen o PDF de la guía de remisión

-- B · El comprobante que el vendedor emitió al cliente final por esa venta.
alter table pedidos
  add column if not exists comprobante_tipo   text
    check (comprobante_tipo in ('boleta','factura')),
  add column if not exists comprobante_serie  text,
  add column if not exists comprobante_numero text,
  add column if not exists comprobante_url    text,
  add column if not exists comprobante_en     timestamptz;

-- C · El estado que faltaba. El informe distingue "pago registrado por el
-- vendedor" (lo dice el socio) de "validado para despacho" (lo comprobó SOCIO
-- contra el estado de cuenta). Antes eran el mismo estado, y esa confusión es
-- justo la que deja despachar contra un voucher falso.
alter table pedidos drop constraint if exists pedidos_estado_check;
alter table pedidos add constraint pedidos_estado_check
  check (estado in ('pendiente_pago','pagado','validado','en_camino','entregado','cancelado'));

-- ---------------------------------------------------------------------------
-- A · Privacidad: cada rol lee solo los importes que le tocan
-- ---------------------------------------------------------------------------
--
-- Los permisos por fila (RLS) deciden QUÉ FILAS se ven. Aquí se decide QUÉ
-- COLUMNAS, que es otra cosa y hasta ahora estaba abierta: un socio podía leer
-- pedidos.precio_mayorista de sus propios pedidos y calcular exactamente cuánto
-- gana la plataforma; una marca podía leer comision_socio_app y lo mismo.
--
-- Postgres no permite quitar columnas de un permiso ya dado sobre la tabla
-- entera: hay que retirar el select y devolverlo solo sobre lo neutral. Lo
-- sensible se sirve por vistas, una por rol.

revoke select on pedidos from anon, authenticated;
grant select (
  id, codigo, socio_id, marca_id, costo_envio,
  destinatario, doc_destinatario, celular_destinatario,
  origen, modo_entrega, agencia, detalle_entrega,
  numero_guia, courier, tracking, guia_url,
  comprobante_tipo, comprobante_serie, comprobante_numero, comprobante_url, comprobante_en,
  estado, creado_en, despachado_en, entregado_en
) on pedidos to authenticated;

revoke select on pedido_items from anon, authenticated;
grant select (id, pedido_id, presentacion_id, cantidad) on pedido_items to authenticated;

-- Las vistas se crean SIN security_invoker: corren con los permisos de quien
-- las creó, así que sí pueden leer las columnas que acabamos de cerrar. Lo que
-- protege cada fila es el WHERE que llevan dentro — por eso el WHERE es la
-- parte que hay que leer con lupa. Sin sesión, auth.uid() es null, ninguna
-- comparación se cumple y la vista devuelve cero filas.

create or replace view pedidos_socio with (security_invoker = false) as
  select p.id, p.codigo, p.socio_id, p.marca_id,
         p.precio_socio,            -- lo que el socio transfiere
         p.ganancia_socio,          -- lo que gana
         p.costo_envio,
         p.destinatario, p.doc_destinatario, p.celular_destinatario,
         p.origen, p.modo_entrega, p.agencia, p.detalle_entrega,
         p.numero_guia, p.courier, p.tracking, p.guia_url,
         p.comprobante_tipo, p.comprobante_serie, p.comprobante_numero,
         p.comprobante_url, p.comprobante_en,
         p.estado, p.creado_en, p.despachado_en, p.entregado_en,
         m.nombre as marca
    from pedidos p
    join marcas m on m.id = p.marca_id
   where p.socio_id = auth.uid();
-- No están precio_mayorista ni comision_socio_app: CLAUDE.md regla nº 1 y la
-- sección 4.A del informe.

create or replace view pedidos_marca with (security_invoker = false) as
  select p.id, p.codigo, p.socio_id, p.marca_id,
         p.precio_mayorista,        -- lo suyo, íntegro
         p.costo_envio,
         p.destinatario, p.doc_destinatario, p.celular_destinatario,
         p.origen, p.modo_entrega, p.agencia, p.detalle_entrega,
         p.numero_guia, p.courier, p.tracking, p.guia_url,
         p.estado, p.creado_en, p.despachado_en, p.entregado_en
    from pedidos p
   where p.marca_id = auth.uid();
-- No están precio_socio, ganancia_socio ni comision_socio_app. Si la marca ve
-- lo que paga el socio, deduce la comisión de SOCIO restando su mayorista, y
-- de ahí a saltarse la plataforma hay un paso.

create or replace view pedidos_admin with (security_invoker = false) as
  select p.* from pedidos p where es_admin();

create or replace view pedido_items_socio with (security_invoker = false) as
  select i.id, i.pedido_id, i.presentacion_id, i.cantidad, i.precio_unit_socio
    from pedido_items i
    join pedidos p on p.id = i.pedido_id
   where p.socio_id = auth.uid();

create or replace view pedido_items_marca with (security_invoker = false) as
  select i.id, i.pedido_id, i.presentacion_id, i.cantidad, i.precio_unit_mayorista
    from pedido_items i
    join pedidos p on p.id = i.pedido_id
   where p.marca_id = auth.uid();

grant select on pedidos_socio, pedidos_marca, pedidos_admin,
                pedido_items_socio, pedido_items_marca to authenticated;
revoke all on pedidos_socio, pedidos_marca, pedidos_admin,
              pedido_items_socio, pedido_items_marca from anon;

-- ---------------------------------------------------------------------------
-- A (cont.) · La marca solo puede tocar el despacho, no los importes
-- ---------------------------------------------------------------------------
--
-- La política "marca actualiza los pedidos de su catálogo" le daba update sobre
-- la fila entera. Podía subirse el precio_mayorista de un pedido ya cerrado y
-- cobrar de más. Igual que con el nivel del socio en la migración anterior: la
-- fila es suya, las columnas no todas.

revoke update on pedidos from anon, authenticated;
grant update (estado, numero_guia, courier, tracking, guia_url) on pedidos to authenticated;

-- El socio no tiene política de update sobre pedidos, así que este permiso no
-- le sirve de nada: lo frena la regla por fila. Su comprobante lo registra por
-- la función de la sección B, que comprueba que el pedido sea suyo.

revoke update on usuarios_socios from anon, authenticated;
grant update (nombre, ciudad, ruc, razon_social, direccion_fiscal, emite_comprobante)
  on usuarios_socios to authenticated;

-- ---------------------------------------------------------------------------
-- C · Máquina de estados: el orden del informe, sin atajos
-- ---------------------------------------------------------------------------
--
--   [1 pendiente_pago]  el pedido existe, el cliente aún no pagó
--          ↓
--   [2 pagado]          el vendedor registró el pago y adjuntó el voucher
--          ↓
--   [3 validado]        SOCIO lo cruzó contra el estado de cuenta
--          ↓
--   [4 en_camino]       despachado — EXIGE guía de remisión + courier + tracking
--          ↓
--   [5 entregado]       entregado y liquidado
--
-- Cancelar se puede desde cualquier estado anterior a la entrega. De 'entregado'
-- no se sale: es el final del camino y lo que sostiene el nivel del socio.

create or replace function pedido_transicion_valida()
returns trigger
language plpgsql
as $$
declare
  permitidos text[];
begin
  if new.estado = old.estado then
    return new;
  end if;

  permitidos := case old.estado
    when 'pendiente_pago' then array['pagado','cancelado']
    when 'pagado'         then array['validado','cancelado']
    when 'validado'       then array['en_camino','cancelado']
    when 'en_camino'      then array['entregado','cancelado']
    else array[]::text[]
  end;

  if not (new.estado = any (permitidos)) then
    raise exception
      'Un pedido en "%" no puede pasar a "%". Desde "%" solo puede ir a: %',
      old.estado, new.estado, old.estado,
      coalesce(nullif(array_to_string(permitidos, ', '), ''), 'ningún otro estado');
  end if;

  -- Despacho obligatorio con evidencia (informe, sección 3, punto 4).
  if new.estado = 'en_camino' then
    if coalesce(trim(new.numero_guia), '') = ''
       or coalesce(trim(new.courier), '') = ''
       or coalesce(trim(new.tracking), '') = '' then
      raise exception
        'Para marcar el pedido como despachado hace falta la guía de remisión, el courier y el número de tracking. Sin esa evidencia el pedido no avanza.';
    end if;
    new.despachado_en := coalesce(new.despachado_en, now());
  end if;

  if new.estado = 'entregado' then
    new.entregado_en := coalesce(new.entregado_en, now());
  end if;

  return new;
end;
$$;

drop trigger if exists trg_pedido_transicion on pedidos;
create trigger trg_pedido_transicion
  before update on pedidos
  for each row execute function pedido_transicion_valida();

-- Paso 2 del flujo: cuando el vendedor registra el pago, el pedido avanza solo.
-- Va con 'security definer' porque quien inserta el pago es el socio, y el
-- socio no tiene permiso para actualizar pedidos — sin esto el update afectaría
-- cero filas y nadie se enteraría.
create or replace function marcar_pago_registrado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update pedidos set estado = 'pagado'
   where id = new.pedido_id and estado = 'pendiente_pago';
  return new;
end;
$$;

drop trigger if exists trg_pago_registrado on pagos;
create trigger trg_pago_registrado
  after insert on pagos
  for each row execute function marcar_pago_registrado();

-- validar_pago() venía de la migración anterior dejando el pedido en 'pagado'.
-- Ahora 'pagado' significa "el vendedor dice que pagaron" y lo que la
-- validación produce es el estado siguiente: 'validado', que es el permiso para
-- despachar.
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
    update pedidos set estado = 'validado'
     where id = v_pedido and estado = 'pagado';
  end if;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('pagos', p_pago_id, 'pago_' || v_estado, auth.uid(), 'admin',
          jsonb_build_object('pedido_id', v_pedido, 'motivo', p_motivo));
end;
$$;

revoke execute on function validar_pago(uuid, boolean, text) from anon;

-- ---------------------------------------------------------------------------
-- B · El comprobante lo registra el vendedor, sobre su propio pedido
-- ---------------------------------------------------------------------------
--
-- Por función y no por permiso de tabla: si al socio se le diera update sobre
-- pedidos para esto, el permiso es por columna pero la regla por fila es por
-- comando, y con una política de update abierta también podría mover el estado.
create or replace function registrar_comprobante(
  p_pedido_id uuid,
  p_tipo      text,
  p_serie     text,
  p_numero    text,
  p_url       text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ok boolean;
begin
  select true into v_ok
    from pedidos where id = p_pedido_id and socio_id = auth.uid();

  if v_ok is not true then
    raise exception 'Ese pedido no existe o no es tuyo';
  end if;

  if p_tipo not in ('boleta','factura') then
    raise exception 'El comprobante debe ser boleta o factura';
  end if;

  if coalesce(trim(p_serie), '') = '' or coalesce(trim(p_numero), '') = '' then
    raise exception 'Falta la serie o el número del comprobante';
  end if;

  update pedidos
     set comprobante_tipo   = p_tipo,
         comprobante_serie  = trim(p_serie),
         comprobante_numero = trim(p_numero),
         comprobante_url    = p_url,
         comprobante_en     = now()
   where id = p_pedido_id;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('pedidos', p_pedido_id, 'comprobante_registrado', auth.uid(), 'socio',
          jsonb_build_object('tipo', p_tipo, 'serie', p_serie, 'numero', p_numero));
end;
$$;

revoke execute on function registrar_comprobante(uuid, text, text, text, text) from anon;

-- ---------------------------------------------------------------------------
-- D · Reporte contable
-- ---------------------------------------------------------------------------
--
-- Lo que el contador pidió, columna por columna, para exportar a CSV/Excel y
-- emitir con eso las facturas globales del periodo. Solo SOCIO lo ve: es el
-- único sitio de todo el sistema donde los tres importes aparecen juntos.

create or replace view reporte_contable with (security_invoker = false) as
  select p.codigo                as pedido,
         p.creado_en             as fecha,
         p.entregado_en          as fecha_entrega,
         p.estado,
         m.nombre                as marca,
         m.ruc                   as ruc_marca,
         s.nombre                as vendedor,
         s.ruc                   as ruc_vendedor,
         s.nivel                 as nivel_vendedor,
         (p.precio_socio + p.ganancia_socio) as precio_venta,
         p.precio_mayorista      as costo_mayorista,
         p.ganancia_socio        as comision_vendedor,
         p.comision_socio_app    as comision_plataforma,
         round(p.comision_socio_app * 0.18 / 1.18, 2) as igv_comision_plataforma,
         round(p.comision_socio_app / 1.18, 2)        as comision_plataforma_sin_igv,
         p.costo_envio,
         p.comprobante_tipo, p.comprobante_serie, p.comprobante_numero,
         p.numero_guia, p.courier, p.tracking
    from pedidos p
    join marcas m           on m.id = p.marca_id
    join usuarios_socios s  on s.id = p.socio_id
   where es_admin();

grant select on reporte_contable to authenticated;
revoke all on reporte_contable from anon;

commit;
