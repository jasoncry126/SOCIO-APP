-- =============================================================================
-- SOCIO · Los otros cuatro huecos de permisos
--
-- La revisión de los permisos por fila encontró seis. Los dos que tocaban
-- dinero se cerraron en la migración anterior; aquí van los cuatro restantes.
-- Los cuatro son de la misma familia: dentro de una relación legítima —mi
-- pedido, mi catálogo, mi retiro— alguien alcanza un dato o una acción que el
-- diseño reservaba para otro.
--
--   3 · LA MARCA PODÍA DEDUCIR LO QUE PAGA EL SOCIO.
--       Podía leer la fila entera de 'pagos' de sus pedidos, y ahí está
--       monto_esperado, que es el precio del socio más el envío. La vista
--       pedidos_marca se cuida de esconder precio_socio justamente porque
--       «si la marca ve lo que paga el socio, deduce la comisión de SOCIO
--       restando su mayorista, y de ahí a saltarse la plataforma hay un paso»
--       (4ª migración). Por la tabla de pagos ese cuidado se saltaba entero.
--       De paso veía el número de operación y el voucher de su vendedor, que
--       son datos bancarios personales del socio.
--       Probado: pedidos_marca le mostraba S/ 100.00 y en 'pagos' leía S/ 180.42.
--
--   4 · UNA MARCA PODÍA PUBLICAR SU CATÁLOGO SIN QUE SOCIO LO REVISARA.
--       Tiene control total sobre sus propios productos, y eso incluía las dos
--       columnas que deciden si un producto está a la venta. Podía crear uno
--       ya 'aprobado', o pasar a 'aprobado' uno que estaba en revisión.
--       Probado: producto creado en revisión y autoaprobado con un update.
--       Contradice lo que promete el panel de carga masiva —«subir 60 productos
--       de golpe no es una puerta trasera para autopublicarse»— y deja sin
--       efecto aprobar_producto().
--
--   5 · CUALQUIERA PODÍA PEDIR UN RETIRO DE CUALQUIER MONTO.
--       Para crear una solicitud bastaba con que UNA de las dos columnas
--       (socio o marca) fuera la tuya; la otra la ponías libre. Y no se
--       comprobaba ningún saldo.
--       Probado: un socio insertó un retiro de S/ 999,999 anclado a una marca
--       ajena, que lo veía en su lista como si fuera suyo.
--
--   6 · LA BITÁCORA SE PODÍA FIRMAR CON EL NOMBRE DE OTRO.
--       El único requisito para escribir era tener sesión; quien escribía
--       elegía el autor y el tipo de autor.
--       Probado: un socio insertó una entrada 'pago_validado' firmada como
--       administrador.
--       Borrarla y editarla ya estaba bien cerrado, pero la bitácora existe
--       para defenderse de un reclamo y una en la que cualquiera puede firmar
--       a nombre ajeno pierde parte de ese valor.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 3 · La marca ve SI le pagaron, no CUÁNTO pagó el socio
-- ---------------------------------------------------------------------------
--
-- Lo que la marca necesita saber del pago es si está validado, porque de eso
-- depende que pueda despachar. El importe, el número de operación y la imagen
-- del voucher son del socio y de SOCIO.
--
-- Mismo remedio que en todo el resto del sistema: se retira el acceso a la
-- tabla y queda una vista con lo justo.

drop policy if exists "marca ve el pago de sus pedidos" on pagos;

create or replace view pagos_marca with (security_invoker = false) as
  select pg.pedido_id,
         p.codigo,
         pg.estado,
         pg.creado_en,
         pg.validado_en
    from pagos pg
    join pedidos p on p.id = pg.pedido_id
   where p.marca_id = auth.uid();

comment on view pagos_marca is
  'Lo que la marca puede saber del pago de sus pedidos: si está pendiente, validado o rechazado, y cuándo. Sin el monto, que revelaría el precio del socio y con él la comisión de SOCIO.';

grant select on pagos_marca to authenticated;
revoke all on pagos_marca from anon;

-- ---------------------------------------------------------------------------
-- 4 · Publicar un producto lo decide SOCIO, no la marca
-- ---------------------------------------------------------------------------
--
-- Dos cierres, uno por cada puerta:
--
--   · el update, por permisos de columna — el mismo patrón con el que ya se
--     impidió que un socio se ponga nivel 'diamante' y que una marca se ponga
--     'aliada'. La fila es suya; las columnas, no todas.
--
--   · el insert, por trigger — porque ahí no basta con quitar la columna: el
--     panel de la marca manda estado='revision' explícitamente al crear un
--     producto, y quitarle el permiso rompería la carga de catálogo. El
--     trigger lo deja entrar y le pone 'revision' diga lo que diga el
--     navegador, que es lo que el panel promete.
--
-- 'activo' SÍ sigue siendo de la marca: es su interruptor de pausa, y no
-- publica nada por sí solo — el catálogo exige estado='aprobado' Y activo.

revoke update on productos from anon, authenticated;
grant update (
  nombre, nombre_comprobante, categoria, emoji, descripcion, recomendaciones,
  tiempo_prep, cobertura, corte_nacional, corte_local, dias_despacho, activo
) on productos to authenticated;

create or replace function producto_lo_aprueba_socio()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Sin sesión no hay navegador detrás: es el propio servidor sembrando datos
  -- o una migración. Por la API web eso no llega, porque sin sesión los
  -- permisos por fila de 'productos' no dejan escribir nada.
  --
  -- Y aprobar_producto() comprueba es_admin() por su cuenta, y llega hasta
  -- aquí con la sesión del administrador puesta.
  if auth.uid() is null or es_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.estado := 'revision';
    return new;
  end if;

  if new.estado is distinct from old.estado then
    raise exception
      'Un producto lo aprueba o lo rechaza SOCIO, no la marca. El tuyo queda en revisión hasta que lo miremos.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_producto_lo_aprueba_socio on productos;
create trigger trg_producto_lo_aprueba_socio
  before insert or update on productos
  for each row execute function producto_lo_aprueba_socio();

-- ---------------------------------------------------------------------------
-- 5 · Un retiro se pide sobre el saldo que uno tiene
-- ---------------------------------------------------------------------------
--
-- Primero lo estructural: una solicitud es de una marca O de un socio, nunca
-- de los dos ni de ninguno. Sin esto, la columna que no era tuya quedaba libre
-- y se le podía colgar el retiro a otro.

alter table retiros drop constraint if exists retiros_un_solo_dueno;
alter table retiros add constraint retiros_un_solo_dueno
  check ((marca_id is null) <> (socio_id is null));

-- Y después el monto, que es lo que de verdad importa: se calcula en la base,
-- no se acepta del navegador. Igual que con crear_pedido() y declarar_pago().
--
-- Qué es el saldo de cada quien:
--   · de una marca · lo que se le ha liberado por hitos, menos lo que ya pidió
--   · de un socio  · lo que ganó en pedidos ENTREGADOS, menos lo que ya pidió
--
-- Un retiro rechazado no descuenta: el dinero nunca salió.
--
-- Lo del socio se apoya en docs/13 y en la regla nº 5 de CLAUDE.md (el nivel
-- cuenta ventas entregadas, no pedidos registrados): se cobra lo entregado. Si
-- SOCIO quiere además un periodo de retención antes de pagar, es esta función
-- la que cambia, y solo esta.

create or replace function saldo_disponible()
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ganado   numeric := 0;
  v_pedido   numeric := 0;
begin
  if exists (select 1 from marcas m where m.id = auth.uid()) then
    select coalesce(sum(l.monto), 0) into v_ganado
      from liberaciones_dinero l where l.marca_id = auth.uid();
    select coalesce(sum(r.monto), 0) into v_pedido
      from retiros r where r.marca_id = auth.uid() and r.estado <> 'rechazado';

  elsif exists (select 1 from usuarios_socios s where s.id = auth.uid()) then
    select coalesce(sum(p.ganancia_socio), 0) into v_ganado
      from pedidos p where p.socio_id = auth.uid() and p.estado = 'entregado';
    select coalesce(sum(r.monto), 0) into v_pedido
      from retiros r where r.socio_id = auth.uid() and r.estado <> 'rechazado';

  else
    raise exception 'Solo un socio o una marca con sesión puede pedir un retiro';
  end if;

  return round(v_ganado - v_pedido, 2);
end;
$$;

create or replace function solicitar_retiro(p_monto numeric)
returns table (retiro_id uuid, monto numeric, saldo_restante numeric)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_saldo  numeric;
  v_marca  boolean;
  v_id     uuid;
begin
  if p_monto is null or p_monto <= 0 then
    raise exception 'El monto del retiro tiene que ser mayor que cero';
  end if;

  v_saldo := saldo_disponible();

  if p_monto > v_saldo then
    raise exception 'Estás pidiendo S/ % y tu saldo disponible es S/ %.',
      to_char(p_monto, 'FM999999990.00'), to_char(v_saldo, 'FM999999990.00');
  end if;

  v_marca := exists (select 1 from marcas m where m.id = auth.uid());

  insert into retiros (marca_id, socio_id, monto)
  values (case when v_marca then auth.uid() end,
          case when v_marca then null else auth.uid() end,
          round(p_monto, 2))
  returning id into v_id;

  insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo, detalle)
  values ('retiros', v_id, 'retiro_solicitado', auth.uid(),
          case when v_marca then 'marca' else 'socio' end,
          jsonb_build_object('monto', round(p_monto, 2)));

  return query select v_id, round(p_monto, 2), round(v_saldo - p_monto, 2);
end;
$$;

-- Con la función puesta, insertar a mano ya no hace falta, y mientras se pueda
-- hacer la comprobación del saldo es opcional para quien sepa llamar a la API
-- directamente. Misma decisión que con los pedidos y los pagos.
drop policy if exists "cada quien solicita su propio retiro" on retiros;
revoke insert on retiros from anon, authenticated;

revoke execute on function solicitar_retiro(numeric) from anon;
revoke execute on function saldo_disponible()        from anon;

-- ---------------------------------------------------------------------------
-- 6 · En la bitácora cada quien firma con su nombre
-- ---------------------------------------------------------------------------
--
-- Sigue siendo un buzón de una sola dirección: se escribe, no se lee (salvo
-- SOCIO), no se edita y no se borra. Lo que cambia es que ya no se puede
-- firmar por otro.
--
-- Esto solo afecta a quien escribe directo desde la app. Las funciones de la
-- plataforma —validar_pago(), crear_pedido(), declarar_pago()…— corren con
-- permisos de dueño y ya ponían auth.uid() como autor; ninguna cambia.

create or replace function tipo_de_actor()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
           when exists (select 1 from administradores a where a.id = auth.uid()) then 'admin'
           when exists (select 1 from marcas m           where m.id = auth.uid()) then 'marca'
           when exists (select 1 from usuarios_socios s  where s.id = auth.uid()) then 'socio'
         end;
$$;

drop policy if exists "cualquiera con sesión deja constancia" on bitacora;

create policy "cada quien deja constancia con su nombre"
  on bitacora for insert
  with check (auth.uid() is not null
              and actor_id = auth.uid()
              and actor_tipo = tipo_de_actor());

commit;
