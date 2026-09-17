-- =============================================================================
-- SOCIO · El circuito de venta: crear el pedido y declarar el pago
--
-- Hasta aquí el socio no tenía forma de registrar una venta, y las dos razones
-- eran la misma:
--
--   1 · La tabla 'pedidos' exige precio_mayorista, y el socio NO PUEDE saberlo
--       (CLAUDE.md regla nº 1). Para que el navegador lo escribiera habría que
--       mandárselo antes, que es justo lo prohibido.
--
--   2 · La política de inserción comprueba que el pedido sea suyo, pero NO los
--       importes. Un socio podía registrar una venta de S/ 175 declarando una
--       comisión de S/ 170 y quedarse con casi todo. Se probó: funcionaba.
--
-- La salida es la misma para los dos: el pedido lo arma la base. El navegador
-- manda lo que el socio SÍ conoce —qué presentaciones, cuántas, para quién y a
-- dónde— y aquí se calculan los cuatro montos leyendo el catálogo y el nivel
-- del socio. El navegador no envía ni un solo precio.
--
-- Desde ahora nadie inserta a mano en pedidos, pedido_items ni pagos: se quitan
-- esos permisos y queda esta puerta, que es la única que calcula bien.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · Las mismas reglas de dinero que app/socio-precios.js
-- ---------------------------------------------------------------------------
--
-- Este cálculo tiene que vivir aquí: si viviera solo en el navegador, bastaría
-- con abrir las herramientas de desarrollo para cobrarse lo que uno quiera.
-- Pero entonces existe en dos sitios, y dos sitios se desincronizan. La prueba
-- 11-circuito-de-venta.sql compara los dos contra la misma tabla de casos, para
-- que una diferencia salte el día que se introduzca y no el día que alguien
-- cobre de menos.

create or replace function comision_de_nivel(p_nivel text)
returns numeric
language sql
immutable
as $$
  select case p_nivel
           when 'diamante' then 0.20
           when 'oro'      then 0.16
           when 'plata'    then 0.13
           else                 0.10
         end;
$$;

-- Lo que gana el socio por una unidad, ya con la red de seguridad: si el margen
-- no alcanza para pagarle su porcentaje Y dejarle a SOCIO su mínimo, se recorta
-- la comisión. La marca cobra su mayorista íntegro SIEMPRE — eso no se toca.
create or replace function ganancia_unitaria(
  p_publico numeric, p_mayorista numeric, p_nivel text
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_gana   numeric;
  v_techo  numeric;
begin
  v_gana  := round(p_publico * comision_de_nivel(p_nivel), 2);
  -- 0.059 = el 5% neto que necesita SOCIO, más su IGV (0.05 × 1.18)
  v_techo := round((p_publico - p_mayorista) - p_publico * 0.059, 2);
  if v_gana > v_techo then
    v_gana := greatest(0, v_techo);
  end if;
  return v_gana;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2 · El monto con céntimos únicos (docs/12, capa 2)
-- ---------------------------------------------------------------------------
--
--   «En lugar de pedir S/ 158.00 exactos, el sistema pide S/ 158.37 — con
--    céntimos generados a partir del código del pedido. Como es prácticamente
--    imposible que dos pedidos del mismo día tengan el mismo monto, al mirar el
--    estado de cuenta cada depósito se identifica solo.»
--
-- Los céntimos salen del código, así que son estables: el mismo pedido pide
-- siempre lo mismo. Se redondea HACIA ARRIBA para que nunca se cobre de menos;
-- la diferencia es de menos de un sol y queda a favor de SOCIO.

create or replace function monto_a_pagar(p_codigo text, p_total numeric)
returns numeric
language sql
immutable
as $$
  select case
           when floor(p_total) + (1 + abs(hashtext(p_codigo)) % 99) / 100.0 < p_total
           then floor(p_total) + 1 + (1 + abs(hashtext(p_codigo)) % 99) / 100.0
           else floor(p_total)     + (1 + abs(hashtext(p_codigo)) % 99) / 100.0
         end::numeric(10,2);
$$;

-- ---------------------------------------------------------------------------
-- 3 · Crear el pedido
-- ---------------------------------------------------------------------------
--
-- Recibe solo lo que el socio conoce. Devuelve solo lo que puede ver: su
-- código, lo que tiene que transferir, lo que gana y el monto exacto a pagar.
-- Ni el mayorista ni la comisión de la plataforma salen de aquí.

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
           pr.stock_almacen, pr.stock_punto, p.marca_id, p.nombre
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

    v_stock := case when p_origen = 'punto_venta'
                    then v_pres.stock_punto else v_pres.stock_almacen end;
    if coalesce(v_stock, 0) < it.cant then
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

-- ---------------------------------------------------------------------------
-- 4 · Declarar el pago
-- ---------------------------------------------------------------------------
--
-- El monto esperado NO lo manda el navegador: se recalcula aquí. Si lo mandara
-- el socio, podría declarar que su pedido costaba S/ 10 y adjuntar un voucher
-- de S/ 10 perfectamente válido.

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

-- ---------------------------------------------------------------------------
-- 5 · Se cierra la puerta de atrás
-- ---------------------------------------------------------------------------
--
-- Con las funciones en su sitio, insertar a mano ya no hace falta, y mientras
-- se pueda hacer, la validación de arriba es opcional para quien sepa llamar a
-- la API directamente. Las políticas se quedan sin efecto y se retiran para que
-- nadie las lea creyendo que protegen algo.

drop policy if exists "socio registra sus pedidos"        on pedidos;
drop policy if exists "socio agrega los items de su pedido" on pedido_items;
drop policy if exists "socio declara el pago de su pedido"  on pagos;

revoke insert on pedidos, pedido_items, pagos from anon, authenticated;

revoke execute on function crear_pedido(jsonb, text, text, text, text, text, text, text, numeric) from anon;
revoke execute on function declarar_pago(uuid, text, numeric, text, text, text)                   from anon;

commit;
