-- =============================================================================
-- SOCIO · Manual operativo y tributario (actualización del contador, set-2026)
--
-- El manual precisa tres cosas que el informe anterior dejaba abiertas, y añade
-- una cuarta que no estaba:
--
--   1 · PASO 1 — la boleta del vendedor lleva una "descripción comercial
--       genérica", no el nombre de catálogo. Hace falta guardar esa descripción
--       por producto.
--   2 · PASO 3 — la factura de costo de la marca va al VENDEDOR (antes decía
--       "SOCIO o el vendedor, según cadena logística"). Con eso el vendedor
--       sustenta su costo de adquisición ante SUNAT. No cambia ninguna tabla:
--       cambia quién emite a quién, y eso vive en el reporte.
--   3 · PASO 4 — la liquidación deja de ser un concepto y pasa a registrarse:
--       cada hito escribe su fila en liberaciones_dinero. La tabla existía
--       desde docs/13 y nunca se llenaba.
--   4 · El estado 5 del manual es "Liquidado y Finalizado". Aquí es 'entregado'
--       más sus liberaciones: no se añade un sexto estado porque no habría nada
--       que decidir en él.
--
-- Y corrige un fallo de la migración anterior: la regla "sin guía, courier y
-- tracking no se despacha" se escribió pensando solo en el envío nacional. Una
-- entrega local en la misma ciudad no tiene courier ni tracking que poner, así
-- que tal como estaba, ningún pedido de entrega a domicilio podía despacharse
-- nunca. Se ajusta abajo.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · La descripción que va en la boleta del cliente
-- ---------------------------------------------------------------------------
--
-- El manual pide una descripción comercial genérica en el comprobante
-- ("Kit de Optimización Biológica" en vez del nombre del catálogo). Es un campo
-- de la marca, no del vendedor: la marca sabe cómo quiere que se nombre su
-- producto en un documento que va dentro de la caja.

alter table productos
  add column if not exists nombre_comprobante text;

comment on column productos.nombre_comprobante is
  'Descripción comercial genérica para la boleta del cliente final (manual del contador, PASO 1). Si está vacía, el vendedor usa el nombre del producto.';

-- ---------------------------------------------------------------------------
-- 2 · El candado logístico, ahora distinguiendo envío nacional de entrega local
-- ---------------------------------------------------------------------------
--
-- Envío nacional (modo_entrega = 'agencia'): guía de remisión + courier +
-- tracking, tal como pide el manual.
--
-- Entrega local en la misma ciudad (modo_entrega = 'domicilio', que en la app
-- solo se ofrece desde un punto de venta): no hay courier ni número de
-- seguimiento que registrar, pero la guía de remisión sí se exige — transportar
-- mercadería sin ella es sancionable igual.

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

  -- Despacho obligatorio con evidencia (manual, PASO 3).
  if new.estado = 'en_camino' then
    if coalesce(trim(new.numero_guia), '') = '' then
      raise exception
        'Para marcar el pedido como despachado hace falta la guía de remisión. Sin esa evidencia el pedido no avanza.';
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

-- ---------------------------------------------------------------------------
-- 3 · La liquidación, registrada sola (manual, PASO 4)
-- ---------------------------------------------------------------------------
--
-- Cuánto cobra la marca en cada hito lo decide su nivel de fiabilidad, tal como
-- lo definió docs/08. No es un porcentaje del precio de página: es un
-- porcentaje de SU precio mayorista, que cobra íntegro en los dos hitos juntos.
--
--   🌱 Nueva       ·   0% al registrar la guía · 100% a la entrega
--   ✅ Confiable   ·  70% · 30%
--   ⭐ Preferente  ·  90% · 10%
--   🏅 Aliada      · 100% ·   0%
--
-- El segundo hito paga SIEMPRE el resto, no un porcentaje calculado otra vez:
-- así la marca cobra su mayorista exacto aunque el redondeo no sea limpio.

create or replace function liquidar_hito()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pct_guia numeric;
  v_monto    numeric;
  v_ya       numeric;
begin
  if new.estado = old.estado then
    return new;
  end if;

  select case nivel_fiabilidad
           when 'aliada'     then 1.00
           when 'preferente' then 0.90
           when 'confiable'  then 0.70
           else 0.00
         end
    into v_pct_guia
    from marcas where id = new.marca_id;

  if new.estado = 'en_camino' then
    v_monto := round(new.precio_mayorista * v_pct_guia, 2);
    if v_monto > 0 then
      insert into liberaciones_dinero (pedido_id, marca_id, hito, monto)
      values (new.id, new.marca_id, 'guia_registrada', v_monto);
    end if;

  elsif new.estado = 'entregado' then
    select coalesce(sum(monto), 0) into v_ya
      from liberaciones_dinero where pedido_id = new.id;

    v_monto := round(new.precio_mayorista - v_ya, 2);
    if v_monto > 0 then
      insert into liberaciones_dinero (pedido_id, marca_id, hito, monto)
      values (new.id, new.marca_id, 'entrega_confirmada', v_monto);
    end if;

    -- La marca sube de nivel cumpliendo, igual que el socio vendiendo. Aquí
    -- solo se cuenta: promover es decisión de SOCIO, porque los niveles de
    -- docs/08 piden además historial limpio y antigüedad, y eso no lo sabe un
    -- contador de entregas.
    update marcas set entregas_ok = entregas_ok + 1 where id = new.marca_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_liquidar_hito on pedidos;
create trigger trg_liquidar_hito
  after update on pedidos
  for each row execute function liquidar_hito();

-- El socio también necesita ver si su pedido ya fue liquidado a la marca: es lo
-- que le dice si puede dejar de estar pendiente.
create policy "socio ve las liberaciones de sus pedidos"
  on liberaciones_dinero for select
  using (exists (select 1 from pedidos p
                  where p.id = pedido_id and p.socio_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 4 · El catálogo lleva la descripción del comprobante
-- ---------------------------------------------------------------------------

-- Se recrea entera en vez de reemplazarla: Postgres no deja meter una columna
-- en medio de una vista existente, y nombre_comprobante va junto al nombre del
-- producto, que es donde el vendedor la va a buscar.
drop view if exists catalogo_publico;

create view catalogo_publico as
  select pr.id,
         pr.producto_id,
         pr.nombre           as presentacion,
         pr.precio_publico,
         pr.stock_almacen,
         pr.stock_punto,
         p.marca_id,
         p.nombre            as producto,
         p.nombre_comprobante,
         p.categoria,
         p.emoji,
         p.descripcion,
         p.recomendaciones,
         p.tiempo_prep,
         p.cobertura,
         p.corte_nacional,
         p.corte_local,
         p.dias_despacho
    from presentaciones pr
    join productos p on p.id = pr.producto_id
   where p.estado = 'aprobado'
     and p.activo = true;

grant select on catalogo_publico to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5 · El reporte contable, con la liquidación
-- ---------------------------------------------------------------------------
--
-- Las columnas que pide el manual (sección 4.3) estaban ya. Se añade el estado
-- de la liquidación, que es lo que dice si el pedido está cerrado de verdad, y
-- el RUC de las dos partes, porque la factura de comisión puede ir a una o a
-- otra y esa decisión todavía no está tomada (ver docs/15, sección 6).

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
         p.numero_guia, p.courier, p.tracking,
         coalesce((select sum(l.monto) from liberaciones_dinero l
                    where l.pedido_id = p.id), 0)            as liberado_a_marca,
         p.precio_mayorista
           - coalesce((select sum(l.monto) from liberaciones_dinero l
                        where l.pedido_id = p.id), 0)        as pendiente_a_marca
    from pedidos p
    join marcas m           on m.id = p.marca_id
    join usuarios_socios s  on s.id = p.socio_id
   where es_admin();

grant select on reporte_contable to authenticated;
revoke all on reporte_contable from anon;

commit;
