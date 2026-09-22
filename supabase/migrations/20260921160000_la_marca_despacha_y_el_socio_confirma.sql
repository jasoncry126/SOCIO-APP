-- =============================================================================
-- SOCIO · La marca despacha, el socio confirma que llegó
--
-- Hasta aquí el pedido se quedaba en 'validado' para siempre. El panel de la
-- marca tenía la pantalla de despacho dibujada, pero contra datos de mentira
-- guardados en su propio navegador: nada de lo que hacía ahí llegaba a la base.
-- Un pedido real nunca pasaba de 'validado', y como el nivel del socio, el
-- dinero de la marca y el saldo para retirar cuelgan TODOS de la entrega, el
-- recorrido entero se cortaba justo antes de pagar a nadie.
--
-- Esta migración cierra ese tramo y resuelve de paso un hallazgo que estaba
-- abierto desde la auditoría del 20 de septiembre:
--
--   QUIEN CONFIRMABA LA ENTREGA ERA LA MARCA, Y ESE MISMO CAMBIO LE SOLTABA
--   SU SEGUNDO HITO DE PAGO. Es decir, la marca se daba por cumplida sola y
--   cobraba el resto de su mayorista sin que nadie hubiera recibido nada.
--
-- A partir de aquí:
--
--   · La marca marca DESPACHADO ('en_camino') con su guía, su foto y, si va
--     por agencia, courier y tracking. Eso ya estaba y no cambia.
--   · La ENTREGA la confirma el socio, que es quien tiene al cliente del otro
--     lado del teléfono, o SOCIO si el socio no aparece. La marca ya no.
--
-- El socio no tiene permiso de escribir en 'pedidos' —y no conviene dárselo,
-- porque la columna 'estado' es la misma que mueve el dinero—, así que la
-- confirmación entra por una función, confirmar_entrega(), igual que el pedido
-- entra por crear_pedido() y el pago por declarar_pago().
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · El candado de estados: quién puede dar por entregado
-- ---------------------------------------------------------------------------
--
-- IMPORTANTE al releer esto: la función se reescribe ENTERA, así que lo que no
-- esté aquí desaparece. Esta versión parte de la de 20260921140000 —la última—
-- con todos sus controles: el camino de vuelta del pago rechazado, que el pago
-- exista antes de marcar "pagado", que solo SOCIO valide, y que despachar exija
-- guía, foto de la guía y, por agencia, courier y tracking. Lo único nuevo es
-- el último párrafo, el de 'entregado'.

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

  -- NUEVO · La entrega la confirma quien la recibe, no quien cobra por ella.
  -- El segundo hito de la marca se suelta con este cambio de estado, así que
  -- dejárselo a la propia marca era dejarle firmar su propio cobro.
  if new.estado = 'entregado' then
    if not (auth.uid() = new.socio_id or es_admin()) then
      raise exception
        'La entrega la confirma el socio que hizo la venta, o SOCIO. La marca despacha y registra su guía; dar por recibido el paquete no le toca a ella, porque es el mismo paso que le libera el resto de su pago.';
    end if;

    new.entregado_en := coalesce(new.entregado_en, now());
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2 · confirmar_entrega(): el botón del socio
-- ---------------------------------------------------------------------------
--
-- El socio no tiene política de update sobre 'pedidos' y no se le va a dar:
-- con permiso de escribir 'estado' podría saltarse el pago. Entra por aquí,
-- que comprueba que el pedido sea suyo y que esté realmente en camino.
--
-- SOCIO también puede llamarla, para el caso de siempre: el socio se fue de
-- viaje, el cliente ya recibió, y la marca lleva una semana esperando su 30%.

create or replace function confirmar_entrega(p_pedido_id uuid)
returns table (codigo text, estado text, entregado_en timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedido pedidos%rowtype;
  v_admin  boolean := es_admin();
begin
  select * into v_pedido from pedidos where id = p_pedido_id;

  if not found then
    raise exception 'No existe ese pedido.';
  end if;

  if not (v_admin or v_pedido.socio_id = auth.uid()) then
    raise exception 'Solo el socio que hizo la venta puede confirmar que su pedido llegó.';
  end if;

  if v_pedido.estado = 'entregado' then
    raise exception 'Ese pedido ya estaba confirmado como entregado el %.',
      to_char(v_pedido.entregado_en, 'DD/MM/YYYY');
  end if;

  if v_pedido.estado <> 'en_camino' then
    raise exception
      'Solo se confirma la entrega de un pedido que ya salió. Este está en "%".',
      v_pedido.estado;
  end if;

  update pedidos set estado = 'entregado' where id = p_pedido_id;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('pedidos', p_pedido_id, 'entrega_confirmada', auth.uid(),
          case when v_admin then 'admin' else 'socio' end,
          jsonb_build_object('codigo', v_pedido.codigo));

  return query
    select p.codigo, p.estado, p.entregado_en from pedidos p where p.id = p_pedido_id;
end;
$$;

revoke execute on function confirmar_entrega(uuid) from anon;
grant   execute on function confirmar_entrega(uuid) to authenticated;

comment on function confirmar_entrega(uuid) is
  'El socio (o SOCIO) da por recibido un pedido en camino. Es el paso que suelta el resto del pago de la marca, sube la venta entregada del socio y abre su saldo para retirar.';

-- ---------------------------------------------------------------------------
-- 3 · La marca necesita saber QUÉ empacar
-- ---------------------------------------------------------------------------
--
-- 'pedido_items_marca' devolvía el id de la presentación y la cantidad. Con eso
-- no se arma una caja: hace falta el nombre del producto y el de su
-- presentación. Se recrea entera porque Postgres no deja meter columnas en
-- medio de una vista existente.
--
-- Sigue sin llevar 'precio_unit_socio': lo que el socio paga no es asunto de la
-- marca (CLAUDE.md, regla nº 1).

drop view if exists pedido_items_marca;

create view pedido_items_marca with (security_invoker = false) as
  select i.id,
         i.pedido_id,
         i.presentacion_id,
         i.cantidad,
         i.precio_unit_mayorista,
         pres.nombre  as presentacion,
         prod.nombre  as producto,
         prod.emoji   as emoji
    from pedido_items i
    join pedidos p        on p.id = i.pedido_id
    join presentaciones pres on pres.id = i.presentacion_id
    join productos prod     on prod.id = pres.producto_id
   where p.marca_id = auth.uid();

comment on view pedido_items_marca is
  'Lo que la marca tiene que empacar de cada pedido suyo: producto, presentación y cantidad, con su precio mayorista. Sin el precio del socio.';

grant select on pedido_items_marca to authenticated;
revoke all on pedido_items_marca from anon;

commit;
