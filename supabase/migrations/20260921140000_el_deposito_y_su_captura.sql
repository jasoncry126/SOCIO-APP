-- =============================================================================
-- SOCIO · El depósito y su captura
--
-- Mientras no haya pasarela de pago, el pago se confirma así: el socio registra
-- el pedido, la página le dice el monto EXACTO que tiene que depositar, él
-- deposita por fuera y vuelve a subir la captura con su número de operación.
-- SOCIO la cruza contra el estado de cuenta y recién ahí el pedido avanza.
--
-- La base ya tenía casi todo (declarar_pago(), validar_pago(), la máquina de
-- estados). Lo que faltaba es lo que esta migración añade:
--
--   1 · DÓNDE VIVE LA CAPTURA. 'pagos.imagen_voucher_url' existía desde la
--       primera migración, pero no había ningún sitio donde guardar el archivo,
--       así que la app nunca lo mandaba. Se crea el cubo privado 'vouchers',
--       con las mismas reglas que el de las guías.
--
--   2 · UN PAGO RECHAZADO DEJABA EL PEDIDO MUERTO. declarar_pago() exige que el
--       pedido esté en 'pendiente_pago', y 'pagos.pedido_id' es único: un socio
--       que tecleaba mal su número de operación se quedaba sin forma de volver
--       a declarar, y su pedido se quedaba en 'pagado' para siempre. Ahora un
--       rechazo devuelve el pedido a 'pendiente_pago' y el socio puede declarar
--       otra vez sobre el mismo pedido.
--
--   3 · EL SOCIO NO VEÍA CUÁNTO DEPOSITAR NI EN QUÉ QUEDÓ SU PAGO. La vista
--       'pedidos_socio' no traía ni el monto con céntimos ni el estado del
--       pago. Si cerraba la app después de registrar el pedido, perdía el dato.
--
--   4 · SOCIO NO TENÍA COLA DE VALIDACIÓN. Los datos estaban repartidos entre
--       cuatro tablas; el panel tendría que haber hecho cuatro consultas y
--       cruzarlas a mano. Se añade la vista 'cola_de_validacion'.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · Dónde vive la captura del depósito
-- ---------------------------------------------------------------------------
--
-- Un cubo privado de Supabase Storage, igual que el de las guías de remisión.
-- Privado quiere decir que no se sirve por URL pública: para ver una captura
-- hay que pedir un enlace firmado, y solo lo consigue quien tenga permiso.
--
-- Convención de ruta:  vouchers/<socio_id>/<codigo_del_pedido>-<hora>.<ext>
-- La primera carpeta es el id del socio, y en eso se apoyan las reglas: un
-- socio solo escribe dentro de su propia carpeta y solo lee lo que hay en ella.
--
-- El bloque va condicionado a que exista el esquema 'storage' para que la
-- migración se pueda probar también en un Postgres normal, donde no existe.

do $$
begin
  if to_regclass('storage.objects') is null then
    raise notice 'Sin esquema storage (esto no es Supabase): se omite el cubo de vouchers.';
    return;
  end if;

  insert into storage.buckets (id, name, public)
       values ('vouchers', 'vouchers', false)
  on conflict (id) do nothing;

  -- El socio sube la captura dentro de su propia carpeta.
  execute $p$
    create policy "socio sube la captura de su deposito"
      on storage.objects for insert to authenticated
      with check (bucket_id = 'vouchers'
                  and (storage.foldername(name))[1] = auth.uid()::text)
  $p$;

  -- Y puede volver a verla: es su comprobante de que pagó.
  execute $p$
    create policy "socio ve sus propias capturas"
      on storage.objects for select to authenticated
      using (bucket_id = 'vouchers'
             and (storage.foldername(name))[1] = auth.uid()::text)
  $p$;

  -- SOCIO las ve todas: es quien cruza la captura contra el estado de cuenta.
  -- La MARCA no aparece aquí a propósito. El voucher es plata entre el socio y
  -- SOCIO; la marca cobra por hitos y no tiene nada que hacer mirándolo.
  execute $p$
    create policy "SOCIO ve todas las capturas de deposito"
      on storage.objects for select to authenticated
      using (bucket_id = 'vouchers' and es_admin())
  $p$;

  -- Nadie borra ni reemplaza una captura ya subida: es la evidencia del pago.
  -- Sin políticas de update ni delete, queda prohibido desde la app. Cuando un
  -- socio vuelve a declarar tras un rechazo, su nueva captura va a un archivo
  -- nuevo (el nombre lleva la hora) y la anterior se queda donde estaba.
exception
  when duplicate_object then
    raise notice 'Las reglas del cubo de vouchers ya existían: se dejan como están.';
end $$;

-- ---------------------------------------------------------------------------
-- 2 · Un pago rechazado devuelve el pedido a la cola, no lo mata
-- ---------------------------------------------------------------------------
--
-- Por qué hacía falta: 'pagos.pedido_id' es único —un pago por pedido— y
-- declarar_pago() exige que el pedido esté en 'pendiente_pago'. Con las dos
-- reglas juntas, el socio que se equivocaba al teclear su número de operación
-- no tenía ninguna forma de corregirlo: ni podía insertar otro pago, ni el
-- pedido podía volver atrás. Se quedaba en 'pagado' esperando una validación
-- que nunca iba a poder darse.
--
-- El motivo del rechazo se guarda en la fila del pago para que el socio lo lea.
-- Antes solo quedaba en la bitácora, que él no puede leer.

alter table pagos add column if not exists motivo_rechazo text;

comment on column pagos.motivo_rechazo is
  'Lo que SOCIO le dice al socio cuando le rechaza un pago. Lo lee él, así que '
  'se escribe para él: "el abono no aparece en la cuenta", no un código.';

-- La máquina de estados gana un solo camino nuevo: de 'pagado' se puede volver
-- a 'pendiente_pago', pero SOLO si el pago de ese pedido está rechazado. Esa
-- condición es la que impide que la marca —que tiene permiso de escribir la
-- columna 'estado'— desande un pago que sí era bueno.

-- IMPORTANTE al releer esto: la función se reescribe entera, así que lo que no
-- esté aquí desaparece. Esta versión parte de la de 20260920120000 —la última—
-- con TODOS sus controles: que el pago exista antes de marcar "pagado", que
-- solo SOCIO valide, y que despachar exija guía, foto de la guía y, si va por
-- agencia, courier y tracking. Lo único nuevo es el camino de vuelta.

create or replace function pedido_transicion_valida()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  permitidos text[];
begin
  if new.estado = old.estado then
    return new;
  end if;

  permitidos := case old.estado
    when 'pendiente_pago' then array['pagado','cancelado']
    when 'pagado'         then array['validado','cancelado','pendiente_pago']
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

  -- Volver a 'pendiente_pago' es el camino del pago rechazado, y solo ese. Sin
  -- esta condición, la marca —que tiene permiso de escribir la columna
  -- 'estado'— podría desandar un pago que sí era bueno.
  if old.estado = 'pagado' and new.estado = 'pendiente_pago' then
    if not exists (select 1 from pagos pg
                    where pg.pedido_id = new.id and pg.estado = 'rechazado') then
      raise exception
        'Un pedido solo vuelve a "pendiente de pago" cuando SOCIO le rechaza el pago. El de este pedido no está rechazado.';
    end if;
  end if;

  -- Quién puede dar cada paso, no solo en qué orden van.
  if new.estado = 'pagado'
     and not exists (select 1 from pagos pg where pg.pedido_id = new.id) then
    raise exception
      'Un pedido pasa a "pagado" cuando el vendedor declara su pago, no a mano. No hay ningún pago declarado para este pedido.';
  end if;

  if new.estado = 'validado' and not es_admin() then
    raise exception
      'Solo un administrador de SOCIO puede validar un pedido para despacho, después de cruzar el pago contra el estado de cuenta. La marca despacha a partir de ahí, no antes.';
  end if;

  -- Despacho obligatorio con evidencia (manual del contador, PASO 3, y FASE 3
  -- de la especificación técnica).
  if new.estado = 'en_camino' then
    if coalesce(trim(new.numero_guia), '') = '' then
      raise exception
        'Para marcar el pedido como despachado hace falta el número de la guía de remisión.';
    end if;

    if coalesce(trim(new.guia_url), '') = '' then
      raise exception
        'Falta la foto de la guía de remisión. Es obligatoria: es la evidencia de que el paquete salió, y sin ella el pedido no avanza.';
    end if;

    if new.modo_entrega = 'agencia'
       and (coalesce(trim(new.courier), '') = '' or coalesce(trim(new.tracking), '') = '') then
      raise exception
        'En un envío por agencia hacen falta también el courier y el número de tracking. Sin esa evidencia el pedido no avanza.';
    end if;

    new.despachado_en := coalesce(new.despachado_en, now());
  end if;

  if new.estado = 'entregado' then
    new.entregado_en := coalesce(new.entregado_en, now());
  end if;

  return new;
end;
$$;

-- validar_pago() gana dos cosas: guarda el motivo donde el socio lo lea, y al
-- rechazar devuelve el pedido a 'pendiente_pago'.

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

  if not p_validado and coalesce(trim(p_motivo), '') = '' then
    raise exception 'Para rechazar un pago hay que decir por qué: el socio lo va a leer y tiene que saber qué corregir.';
  end if;

  v_estado := case when p_validado then 'validado' else 'rechazado' end;

  update pagos
     set estado         = v_estado,
         validado_por   = auth.uid(),
         validado_en    = now(),
         motivo_rechazo = case when p_validado then null else trim(p_motivo) end
   where id = p_pago_id
     and estado = 'pendiente'
  returning pedido_id into v_pedido;

  if v_pedido is null then
    raise exception 'Ese pago no existe, o ya fue validado o rechazado antes';
  end if;

  if p_validado then
    update pedidos set estado = 'validado'
     where id = v_pedido and estado = 'pagado';
  else
    -- El pedido vuelve a la cola para que el socio pueda declarar de nuevo.
    -- El update va después de marcar el pago como rechazado, que es lo que el
    -- trigger de la máquina de estados comprueba.
    update pedidos set estado = 'pendiente_pago'
     where id = v_pedido and estado = 'pagado';
  end if;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('pagos', p_pago_id, 'pago_' || v_estado, auth.uid(), 'admin',
          jsonb_build_object('pedido_id', v_pedido, 'motivo', p_motivo));
end;
$$;

revoke execute on function validar_pago(uuid, boolean, text) from anon;

-- declarar_pago() acepta ahora un segundo intento sobre el mismo pedido cuando
-- el anterior fue rechazado: en vez de insertar otra fila —que la restricción
-- de un pago por pedido no permite— reescribe la que ya está.
--
-- Se conserva la comprobación de la foto repetida: la huella del archivo no
-- puede haber pagado otro pedido. Es la misma regla que el índice único sobre
-- 'hash_imagen'; aquí está para que el socio lea una explicación y no un error
-- de base de datos.

create or replace function declarar_pago(
  p_pedido_id        uuid,
  p_numero_operacion text,
  p_monto_reportado  numeric,
  p_metodo           text,
  p_voucher_url      text default null,
  p_hash_imagen      text default null
)
returns table (pago_id uuid, monto_esperado numeric, cuadra boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ped    record;
  v_monto  numeric;
  v_pago   uuid;
  v_previo record;
begin
  select id, codigo, precio_socio, costo_envio, estado
    into v_ped
    from pedidos
   where id = p_pedido_id and socio_id = auth.uid();

  if v_ped.id is null then
    raise exception 'Ese pedido no existe o no es tuyo';
  end if;

  if v_ped.estado <> 'pendiente_pago' then
    raise exception 'Ese pedido ya tiene un pago declarado';
  end if;

  if coalesce(trim(p_numero_operacion), '') = '' then
    raise exception 'Falta el número de operación de tu transferencia. Es lo que impide que un mismo voucher pague dos pedidos.';
  end if;

  if p_metodo is null or p_metodo not in ('yape','plin','transferencia','deposito') then
    raise exception 'Método de pago no reconocido';
  end if;

  if p_hash_imagen is not null
     and exists (select 1 from pagos pg
                  where pg.hash_imagen = p_hash_imagen
                    and pg.pedido_id <> p_pedido_id) then
    raise exception 'Esa captura ya se usó para pagar otro pedido. Adjunta la del depósito de este pedido.';
  end if;

  v_monto := monto_a_pagar(v_ped.codigo, round(v_ped.precio_socio + coalesce(v_ped.costo_envio, 0), 2));

  -- ¿Hay un intento anterior rechazado sobre este mismo pedido?
  select id, estado into v_previo from pagos where pedido_id = p_pedido_id;

  if v_previo.id is not null then
    if v_previo.estado <> 'rechazado' then
      raise exception 'Ese pedido ya tiene un pago declarado';
    end if;

    update pagos
       set numero_operacion   = trim(p_numero_operacion),
           monto_esperado     = v_monto,
           monto_reportado    = p_monto_reportado,
           metodo             = p_metodo,
           imagen_voucher_url = p_voucher_url,
           hash_imagen        = p_hash_imagen,
           estado             = 'pendiente',
           validado_por       = null,
           validado_en        = null,
           motivo_rechazo     = null,
           creado_en          = now()
     where id = v_previo.id
    returning id into v_pago;

    -- El trigger que mueve el pedido a 'pagado' cuelga del insert, así que un
    -- segundo intento tiene que empujarlo aquí.
    update pedidos set estado = 'pagado'
     where id = p_pedido_id and estado = 'pendiente_pago';
  else
    insert into pagos (pedido_id, numero_operacion, monto_esperado, monto_reportado,
                       metodo, imagen_voucher_url, hash_imagen)
    values (p_pedido_id, trim(p_numero_operacion), v_monto, p_monto_reportado,
            p_metodo, p_voucher_url, p_hash_imagen)
    returning id into v_pago;
  end if;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('pagos', v_pago, 'pago_declarado', auth.uid(), 'socio',
          jsonb_build_object('pedido', v_ped.codigo, 'operacion', trim(p_numero_operacion),
                             'esperado', v_monto, 'reportado', p_monto_reportado,
                             'con_captura', p_voucher_url is not null,
                             'reintento', v_previo.id is not null));

  return query select v_pago, v_monto, (abs(p_monto_reportado - v_monto) < 0.005);
end;
$$;

revoke execute on function declarar_pago(uuid, text, numeric, text, text, text) from anon;

-- ---------------------------------------------------------------------------
-- 3 · El socio ve cuánto depositar y en qué quedó su pago
-- ---------------------------------------------------------------------------
--
-- El monto con céntimos lo calculaba crear_pedido() y se devolvía una sola vez,
-- al registrar. Si el socio cerraba la app antes de ir al banco, lo perdía. Va
-- en la vista para que esté siempre, y con él el estado de su pago.
--
-- Del pago sale solo lo que es suyo: su número de operación, lo que declaró,
-- cómo quedó y —si se lo rechazaron— por qué. Quién lo validó y cuándo son de
-- SOCIO, y no aparecen aquí.

drop view if exists pedidos_socio;
create view pedidos_socio with (security_invoker = false) as
  select p.id, p.codigo, p.socio_id, p.marca_id,
         p.precio_publico,           -- lo que pagó el cliente; va en su boleta
         p.precio_socio,             -- lo que el socio transfiere
         p.ganancia_socio,           -- lo que gana
         p.costo_envio,
         p.destinatario, p.doc_destinatario, p.celular_destinatario,
         p.origen, p.modo_entrega, p.agencia, p.detalle_entrega,
         p.numero_guia, p.courier, p.tracking, p.guia_url,
         p.comprobante_tipo, p.comprobante_serie, p.comprobante_numero,
         p.comprobante_url, p.comprobante_en,
         p.estado, p.creado_en, p.despachado_en, p.entregado_en,
         m.nombre as marca,
         -- Lo que tiene que depositar, con los céntimos que lo identifican.
         monto_a_pagar(p.codigo, round(p.precio_socio + coalesce(p.costo_envio, 0), 2))
           as monto_a_pagar,
         pg.estado           as pago_estado,
         pg.numero_operacion as pago_operacion,
         pg.monto_reportado  as pago_reportado,
         pg.imagen_voucher_url as pago_captura,
         pg.motivo_rechazo   as pago_motivo,
         pg.creado_en        as pago_declarado_en
    from pedidos p
    join marcas m on m.id = p.marca_id
    left join pagos pg on pg.pedido_id = p.id
   where p.socio_id = auth.uid();

grant select on pedidos_socio to authenticated;
revoke all on pedidos_socio from anon;

comment on view pedidos_socio is
  'Los pedidos del socio con lo que tiene que depositar y en qué quedó su pago. '
  'De la fila de pagos sale solo lo suyo: quién validó y cuándo son de SOCIO.';

-- ---------------------------------------------------------------------------
-- 4 · La cola de validación de SOCIO
-- ---------------------------------------------------------------------------
--
-- Un pago por fila con todo lo que hace falta para cruzarlo contra el estado de
-- cuenta sin abrir otra pantalla: el monto que se pidió, el que el socio dice
-- haber depositado, si cuadran, el número de operación, la ruta de la captura y
-- quién vende.
--
-- 'cuadra' se calcula aquí y no en el panel por la misma razón de siempre: una
-- comparación que vive en el navegador la puede cambiar quien abra la página.
--
-- La vista no filtra por estado: SOCIO necesita volver sobre un pago ya
-- resuelto cuando alguien reclame. El panel muestra los pendientes primero.

create or replace view cola_de_validacion with (security_invoker = false) as
  select pg.id                as pago_id,
         pg.estado            as pago_estado,
         pg.numero_operacion,
         pg.monto_esperado,
         pg.monto_reportado,
         (abs(pg.monto_reportado - pg.monto_esperado) < 0.005) as cuadra,
         pg.metodo,
         pg.imagen_voucher_url as captura,
         pg.hash_imagen,
         pg.motivo_rechazo,
         pg.creado_en         as declarado_en,
         pg.validado_en,
         p.id                 as pedido_id,
         p.codigo             as pedido,
         p.estado             as pedido_estado,
         p.creado_en          as pedido_creado_en,
         round(p.precio_socio + coalesce(p.costo_envio, 0), 2) as total_pedido,
         p.destinatario,
         s.id                 as socio_id,
         s.nombre             as socio,
         s.celular            as socio_celular,
         s.nivel              as socio_nivel,
         m.nombre             as marca
    from pagos pg
    join pedidos p on p.id = pg.pedido_id
    join usuarios_socios s on s.id = p.socio_id
    join marcas m on m.id = p.marca_id
   where es_admin();

grant select on cola_de_validacion to authenticated;
revoke all on cola_de_validacion from anon;

comment on view cola_de_validacion is
  'Un pago por fila con todo lo que SOCIO necesita para cruzarlo contra el '
  'estado de cuenta. Solo devuelve filas si quien pregunta es administrador.';

-- ---------------------------------------------------------------------------
-- 5 · El socio puede desistir de un pedido que aún no pagó
-- ---------------------------------------------------------------------------
--
-- Esto no existía porque hasta ahora el pedido y el pago se registraban en el
-- mismo clic: no había ningún momento en el que un pedido estuviera vivo y sin
-- pagar. Ahora sí lo hay —el socio registra, va al banco, y a veces no vuelve—
-- y ese hueco tiene consecuencia: el pedido aparta stock desde que se crea, así
-- que un pedido abandonado deja mercadería reservada para nadie.
--
-- Solo desde 'pendiente_pago' y solo sobre el pedido propio. El trigger que
-- devuelve la mercadería al catálogo al cancelar se encarga del resto.
--
-- Va con 'security definer' porque el socio no tiene permiso de escribir en
-- 'pedidos': sin eso el update afectaría cero filas y nadie se enteraría.

create or replace function cancelar_pedido_sin_pagar(p_pedido_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ped record;
begin
  select id, codigo, estado into v_ped
    from pedidos
   where id = p_pedido_id and socio_id = auth.uid();

  if v_ped.id is null then
    raise exception 'Ese pedido no existe o no es tuyo';
  end if;

  if v_ped.estado <> 'pendiente_pago' then
    raise exception 'Ese pedido ya no se puede cancelar desde aquí: su estado es "%". Escríbele a SOCIO.', v_ped.estado;
  end if;

  update pedidos set estado = 'cancelado' where id = p_pedido_id;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('pedidos', p_pedido_id, 'cancelado_por_el_socio', auth.uid(), 'socio',
          jsonb_build_object('codigo', v_ped.codigo, 'desde', 'pendiente_pago'));
end;
$$;

revoke execute on function cancelar_pedido_sin_pagar(uuid) from anon;

comment on function cancelar_pedido_sin_pagar(uuid) is
  'El socio desiste de un pedido que registró y no llegó a pagar. Devuelve la '
  'mercadería al catálogo por el trigger de cancelación.';

commit;
