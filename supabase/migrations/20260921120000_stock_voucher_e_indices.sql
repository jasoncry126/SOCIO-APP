-- =============================================================================
-- SOCIO · El stock se reserva, el voucher no se reutiliza, y las consultas
--         dejan de recorrer las tablas enteras
--
-- Tres arreglos independientes que no tocan ninguna regla de negocio ya
-- decidida. Salen de la auditoría del 20 de setiembre de 2026.
--
--   1 · EL STOCK NUNCA SE DESCONTABA.
--       crear_pedido() comprobaba que hubiera suficiente y luego no restaba
--       nada. Dos socios que venden la última unidad el mismo minuto pasan los
--       dos la comprobación, los dos registran su pedido, y la marca se entera
--       al despachar — con un cliente ya cobrado del otro lado.
--
--   2 · EL MISMO VOUCHER VALÍA DOS VECES.
--       'numero_operacion' es único, así que un voucher no paga dos pedidos
--       con el mismo número. Pero 'hash_imagen' —la huella del archivo, que
--       existe justamente para detectar la foto reusada— no era única: bastaba
--       con teclear otro número de operación y la misma imagen entraba otra
--       vez. Lo detectaba, si acaso, el ojo del administrador.
--
--   3 · NO HABÍA UN SOLO ÍNDICE.
--       Ni sobre pedidos(socio_id), ni pedido_items(pedido_id), ni ninguna de
--       las claves foráneas por las que se consulta todo el tiempo. Con RLS
--       cada política se evalúa fila por fila sobre un recorrido completo de la
--       tabla. Hoy no se nota; con diez mil pedidos, sí.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · El stock se reserva al registrar el pedido
-- ---------------------------------------------------------------------------
--
-- La función es la misma de la 7ª migración; lo único que cambia está dentro
-- del recorrido del carrito. Donde antes había un select del stock y una
-- comparación, ahora hay un update condicionado.
--
-- La diferencia importa y no es de estilo. Un select no bloquea nada: dos
-- socios que piden la última unidad a la vez leen los dos "queda 1", los dos
-- pasan la comprobación y los dos registran su venta. Un update sí bloquea la
-- fila: el segundo espera a que el primero termine y se encuentra el stock ya
-- en cero, así que su 'where stock >= cantidad' no encuentra nada que
-- actualizar y el pedido se rechaza. Es la base la que serializa, no el orden
-- en que lleguen los dos navegadores.
--
-- Si falla una presentación a media lista, la excepción deshace también lo
-- descontado de las anteriores: todo el pedido va en una sola transacción.

create or replace function crear_pedido(
  p_items            jsonb,      -- [{"presentacion_id":"...","cantidad":2}, ...]
  p_destinatario     text,
  p_doc              text,
  p_celular          text,
  p_origen           text,
  p_modo_entrega     text,
  p_detalle_entrega  text,
  p_agencia          text    default null,
  p_costo_envio      numeric default 0
)
returns table (
  pedido_id       uuid,
  codigo          text,
  precio_socio    numeric,
  ganancia_socio  numeric,
  precio_publico  numeric,
  monto_esperado  numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_socio     usuarios_socios%rowtype;
  v_marca     uuid;
  v_codigo    text;
  v_pedido    uuid;
  v_tot_socio numeric := 0;
  v_tot_may   numeric := 0;
  v_tot_gana  numeric := 0;
  v_monto     numeric;
  it          record;
  v_pres      record;
  v_gana_u    numeric;
  v_socio_u   numeric;
  v_stock     int;
  v_lineas    jsonb := '[]'::jsonb;
  v_i         int;
  v_j         int;
  v_alfabeto  constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
begin
  select * into v_socio from usuarios_socios where id = auth.uid();
  if v_socio.id is null then
    raise exception 'Solo un socio con sesión puede registrar un pedido';
  end if;

  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'El pedido no tiene ninguna presentación';
  end if;

  if coalesce(trim(p_destinatario), '') = ''
     or coalesce(trim(p_doc), '') = ''
     or coalesce(trim(p_celular), '') = ''
     or coalesce(trim(p_detalle_entrega), '') = '' then
    raise exception 'Faltan los datos de quien recibe el pedido';
  end if;

  -- El código, con el mismo alfabeto que usaba la app: sin i/l/1 ni O/0, que se
  -- confunden al dictarlos por teléfono. Se reintenta por si sale uno repetido
  -- (es raro, pero 'codigo' es único y un choque dejaría al socio sin registrar
  -- su venta sin entender por qué).
  for v_i in 1..10 loop
    v_codigo := 'SOC-' || to_char(now(), 'MMDD') || '-';
    for v_j in 1..4 loop
      v_codigo := v_codigo || substr(v_alfabeto, 1 + floor(random() * length(v_alfabeto))::int, 1);
    end loop;
    exit when not exists (select 1 from pedidos pe where pe.codigo = v_codigo);
  end loop;

  -- Se recorre el carrito leyendo SIEMPRE los precios del catálogo, nunca los
  -- que venga diciendo el navegador.
  for it in select (e->>'presentacion_id')::uuid as pres_id,
                   (e->>'cantidad')::int         as cant
              from jsonb_array_elements(p_items) e
  loop
    if it.cant is null or it.cant <= 0 then
      raise exception 'Cantidad inválida en el pedido';
    end if;

    select pr.id, pr.precio_mayorista, pr.precio_publico,
           p.marca_id, p.nombre
      into v_pres
      from presentaciones pr
      join productos p on p.id = pr.producto_id
     where pr.id = it.pres_id
       and p.estado = 'aprobado'
       and p.activo = true;

    if v_pres.id is null then
      raise exception 'Una de las presentaciones no existe o ya no está a la venta';
    end if;

    -- Un pedido va a una sola marca: la tabla tiene un solo marca_id, y cada
    -- marca despacha por su cuenta.
    if v_marca is null then
      v_marca := v_pres.marca_id;
    elsif v_marca <> v_pres.marca_id then
      raise exception 'Un pedido no puede mezclar productos de dos marcas. Registra uno por marca.';
    end if;

    -- Aquí se aparta la mercadería. El 'where' es la comprobación y el 'set' es
    -- la reserva, en una sola operación que nadie puede partir por la mitad.
    if p_origen = 'punto_venta' then
      update presentaciones
         set stock_punto = stock_punto - it.cant
       where id = it.pres_id
         and stock_punto >= it.cant;
    else
      update presentaciones
         set stock_almacen = stock_almacen - it.cant
       where id = it.pres_id
         and stock_almacen >= it.cant;
    end if;

    if not found then
      select case when p_origen = 'punto_venta' then stock_punto else stock_almacen end
        into v_stock
        from presentaciones where id = it.pres_id;
      raise exception 'No hay stock suficiente de "%": quedan %, pediste %',
        v_pres.nombre, coalesce(v_stock, 0), it.cant;
    end if;

    v_gana_u  := ganancia_unitaria(v_pres.precio_publico, v_pres.precio_mayorista, v_socio.nivel);
    v_socio_u := round(v_pres.precio_publico - v_gana_u, 2);

    v_tot_gana  := v_tot_gana  + v_gana_u                  * it.cant;
    v_tot_socio := v_tot_socio + v_socio_u                 * it.cant;
    v_tot_may   := v_tot_may   + v_pres.precio_mayorista   * it.cant;

    -- La línea se guarda después de crear el pedido; aquí solo se acumula.
    v_lineas := v_lineas || jsonb_build_object(
      'pres', it.pres_id, 'cant', it.cant,
      'unit_socio', v_socio_u, 'unit_may', v_pres.precio_mayorista);
  end loop;

  insert into pedidos (
    codigo, socio_id, marca_id,
    precio_socio, precio_mayorista, ganancia_socio, comision_socio_app, costo_envio,
    destinatario, doc_destinatario, celular_destinatario,
    origen, modo_entrega, agencia, detalle_entrega
  ) values (
    v_codigo, v_socio.id, v_marca,
    v_tot_socio, v_tot_may, v_tot_gana, round(v_tot_socio - v_tot_may, 2), coalesce(p_costo_envio, 0),
    trim(p_destinatario), trim(p_doc), trim(p_celular),
    p_origen, p_modo_entrega, p_agencia, trim(p_detalle_entrega)
  ) returning id into v_pedido;

  insert into pedido_items (pedido_id, presentacion_id, cantidad, precio_unit_socio, precio_unit_mayorista)
  select v_pedido, (l->>'pres')::uuid, (l->>'cant')::int,
         (l->>'unit_socio')::numeric, (l->>'unit_may')::numeric
    from jsonb_array_elements(v_lineas) l;

  v_monto := monto_a_pagar(v_codigo, round(v_tot_socio + coalesce(p_costo_envio, 0), 2));

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('pedidos', v_pedido, 'creado', v_socio.id, 'socio',
          jsonb_build_object('codigo', v_codigo, 'monto_esperado', v_monto));

  return query select v_pedido, v_codigo, v_tot_socio, v_tot_gana,
                      round(v_tot_socio + v_tot_gana, 2), v_monto;
end;
$$;

revoke execute on function crear_pedido(jsonb, text, text, text, text, text, text, text, numeric) from anon;

-- ---------------------------------------------------------------------------
-- 2 · Cancelar un pedido devuelve la mercadería al catálogo
-- ---------------------------------------------------------------------------
--
-- La otra mitad de reservar. Sin esto, cada pedido cancelado se lleva su stock
-- para siempre y el catálogo se vacía solo.
--
-- Con una excepción: si el pedido ya iba 'en_camino', la mercadería salió del
-- almacén y no está de vuelta en el estante. Devolverla al catálogo pondría a
-- la venta algo que físicamente va camino a un cliente. Lo que haya que hacer
-- con esa caja es una decisión de la marca, no un automatismo.
--
-- Las cantidades se suman por presentación antes de devolverlas: un carrito
-- puede traer la misma presentación en dos líneas, y un update que se limite a
-- cruzar las tablas devolvería solo una de las dos.

create or replace function devolver_stock_al_cancelar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado <> 'cancelado' or old.estado = 'cancelado' then
    return new;
  end if;

  if old.estado = 'en_camino' then
    return new;
  end if;

  if new.origen = 'punto_venta' then
    update presentaciones pr
       set stock_punto = stock_punto + s.total
      from (select presentacion_id, sum(cantidad) as total
              from pedido_items where pedido_id = new.id
             group by presentacion_id) s
     where pr.id = s.presentacion_id;
  else
    update presentaciones pr
       set stock_almacen = stock_almacen + s.total
      from (select presentacion_id, sum(cantidad) as total
              from pedido_items where pedido_id = new.id
             group by presentacion_id) s
     where pr.id = s.presentacion_id;
  end if;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('pedidos', new.id, 'stock_devuelto', auth.uid(), 'sistema',
          jsonb_build_object('codigo', new.codigo, 'desde', old.estado));

  return new;
end;
$$;

drop trigger if exists trg_devolver_stock on pedidos;
create trigger trg_devolver_stock
  after update on pedidos
  for each row execute function devolver_stock_al_cancelar();

-- ---------------------------------------------------------------------------
-- 3 · La misma foto de voucher no pasa dos veces
-- ---------------------------------------------------------------------------
--
-- El índice es el candado de verdad: lo comprueba la base, venga la petición de
-- donde venga. La comprobación dentro de declarar_pago() está solo para que el
-- socio lea una explicación en vez de un error de restricción única.
--
-- Va sobre los pagos que TIENEN huella: mientras la app no suba el archivo, ese
-- campo llega vacío y varios nulos no chocan entre sí.
--
-- Si al aplicar esta migración sobre una base con datos el índice falla, es que
-- ya hay dos pagos con la misma foto: eso es justo lo que había que encontrar,
-- y hay que mirarlos antes de seguir.

create unique index if not exists pagos_hash_imagen_unico
  on pagos (hash_imagen)
  where hash_imagen is not null;

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
     and exists (select 1 from pagos pg where pg.hash_imagen = p_hash_imagen) then
    raise exception 'Esa foto de voucher ya se usó para pagar otro pedido. Adjunta la captura de tu transferencia de este pedido.';
  end if;

  v_monto := monto_a_pagar(v_ped.codigo, round(v_ped.precio_socio + coalesce(v_ped.costo_envio, 0), 2));

  insert into pagos (pedido_id, numero_operacion, monto_esperado, monto_reportado,
                     metodo, imagen_voucher_url, hash_imagen)
  values (p_pedido_id, trim(p_numero_operacion), v_monto, p_monto_reportado,
          p_metodo, p_voucher_url, p_hash_imagen)
  returning id into v_pago;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('pagos', v_pago, 'pago_declarado', auth.uid(), 'socio',
          jsonb_build_object('pedido', v_ped.codigo, 'operacion', trim(p_numero_operacion),
                             'esperado', v_monto, 'reportado', p_monto_reportado));

  return query select v_pago, v_monto, (abs(p_monto_reportado - v_monto) < 0.005);
end;
$$;

revoke execute on function declarar_pago(uuid, text, numeric, text, text, text) from anon;

-- ---------------------------------------------------------------------------
-- 4 · Índices sobre las columnas por las que se consulta
-- ---------------------------------------------------------------------------
--
-- Postgres indexa sola la clave primaria y las columnas únicas; las claves
-- foráneas, no. Y son justo esas las que usan todas las políticas RLS ("mis
-- pedidos" = pedidos.socio_id = auth.uid()) y todas las pantallas.
--
-- Van los cruces que el código hace hoy, ni uno más: un índice que nadie usa
-- ocupa espacio y hace más lenta cada escritura.

create index if not exists idx_productos_marca          on productos (marca_id);
create index if not exists idx_productos_a_la_venta     on productos (estado, activo);
create index if not exists idx_presentaciones_producto  on presentaciones (producto_id);

create index if not exists idx_pedidos_socio            on pedidos (socio_id);
create index if not exists idx_pedidos_marca            on pedidos (marca_id);
create index if not exists idx_pedidos_estado           on pedidos (estado);

create index if not exists idx_pedido_items_pedido      on pedido_items (pedido_id);
create index if not exists idx_pedido_items_presentacion on pedido_items (presentacion_id);

-- pagos.pedido_id ya es único (un pago por pedido), así que tiene índice propio.
create index if not exists idx_pagos_estado             on pagos (estado);

create index if not exists idx_liberaciones_pedido      on liberaciones_dinero (pedido_id);
create index if not exists idx_liberaciones_marca       on liberaciones_dinero (marca_id);

create index if not exists idx_retiros_marca            on retiros (marca_id);
create index if not exists idx_retiros_socio            on retiros (socio_id);

create index if not exists idx_bitacora_registro        on bitacora (tabla, registro_id);

commit;
