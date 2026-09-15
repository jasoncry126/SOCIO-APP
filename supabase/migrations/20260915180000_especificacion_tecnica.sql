-- =============================================================================
-- SOCIO · Especificación técnica del flujo financiero (contador, set-2026)
--
-- Tercer documento del contador, este dirigido al equipo de desarrollo. Casi
-- todo ya estaba. Esto es lo que faltaba:
--
--   §1 · Los cuatro montos "de forma separada por cada pedido". El PVP se venía
--        calculando al vuelo (precio_socio + ganancia_socio). Ahora es una
--        columna propia: es el monto que el cliente pagó y el que va en su
--        boleta, así que conviene que exista como dato y no como cuenta.
--
--   FASE 3 · El candado logístico pide DOS datos obligatorios: la FOTO de la
--        guía de remisión y el número de tracking. La foto no se exigía — solo
--        el número de guía. Se exige ahora, y se prepara dónde guardarla.
--
-- Lo demás de la especificación (diccionario de montos, privacidad por rol,
-- máquina de estados, liquidación, reporte) ya estaba implementado en las
-- migraciones 4 y 5.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · El PVP como dato propio (§1 del documento)
-- ---------------------------------------------------------------------------
--
-- Columna calculada y almacenada: Postgres la mantiene sola y no puede quedar
-- desfasada respecto de sus dos sumandos. Se tiene el monto separado, como pide
-- la especificación, sin el riesgo de que alguien actualice uno y no el otro.

alter table pedidos
  add column if not exists precio_publico numeric(10,2)
  generated always as (precio_socio + ganancia_socio) stored;

comment on column pedidos.precio_publico is
  'PVP: lo que pagó el cliente final y lo que va en su boleta. Se calcula solo.';

-- La columna es nueva, así que hay que abrirla explícitamente: el permiso de
-- lectura de esta tabla está dado columna por columna desde la migración 4.
grant select (precio_publico) on pedidos to authenticated;

-- ---------------------------------------------------------------------------
-- 2 · El candado logístico, con la foto (FASE 3 del documento)
-- ---------------------------------------------------------------------------
--
--   «El portal de la marca no puede cerrar el pedido ni avanzar en el flujo si
--    obligatoriamente no carga dos datos en el app: Foto de la Guía de Remisión
--    y Número de Seguimiento (Tracking) del Courier.»
--
-- Antes se exigía el NÚMERO de la guía, no la foto. Un número se inventa; una
-- foto, no. Ahora se exigen los dos.
--
-- Se mantiene la distinción de la migración anterior entre envío nacional y
-- entrega local: el tracking del courier solo existe cuando hay courier. La
-- guía de remisión y su foto se exigen en los dos casos.

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

-- ---------------------------------------------------------------------------
-- 3 · Dónde vive la foto de la guía
-- ---------------------------------------------------------------------------
--
-- Un cubo privado de Supabase Storage. Privado quiere decir que no se sirve por
-- URL pública: para verla hay que pedir un enlace firmado, y solo lo consigue
-- quien tenga permiso según las reglas de abajo.
--
-- Convención de ruta:  guias/<marca_id>/<codigo_del_pedido>.<ext>
-- La primera carpeta es el id de la marca, y en eso se apoyan las reglas: una
-- marca solo puede escribir dentro de su propia carpeta.
--
-- El bloque va condicionado a que exista el esquema 'storage' para que la
-- migración se pueda probar también en un Postgres normal, donde ese esquema
-- no existe.

do $$
begin
  if to_regclass('storage.objects') is null then
    raise notice 'Sin esquema storage (esto no es Supabase): se omite el cubo de guías.';
    return;
  end if;

  insert into storage.buckets (id, name, public)
       values ('guias', 'guias', false)
  on conflict (id) do nothing;

  -- La marca sube la foto dentro de su propia carpeta.
  execute $p$
    create policy "marca sube las guias de sus despachos"
      on storage.objects for insert to authenticated
      with check (bucket_id = 'guias'
                  and (storage.foldername(name))[1] = auth.uid()::text)
  $p$;

  -- Y puede volver a verlas.
  execute $p$
    create policy "marca ve sus propias guias"
      on storage.objects for select to authenticated
      using (bucket_id = 'guias'
             and (storage.foldername(name))[1] = auth.uid()::text)
  $p$;

  -- SOCIO las ve todas: es quien tiene que responder si el cliente reclama que
  -- nunca le llegó.
  execute $p$
    create policy "SOCIO ve todas las guias"
      on storage.objects for select to authenticated
      using (bucket_id = 'guias' and es_admin())
  $p$;

  -- Nadie borra ni reemplaza una guía ya subida: es la evidencia del despacho.
  -- Sin políticas de update ni delete, queda prohibido desde la app.
exception
  when duplicate_object then
    raise notice 'Las reglas del cubo de guías ya existían: se dejan como están.';
end $$;

-- ---------------------------------------------------------------------------
-- 4 · Las vistas, con el PVP donde corresponde
-- ---------------------------------------------------------------------------
--
-- Al socio y a SOCIO sí; a la marca no. La especificación es explícita sobre lo
-- que ve cada pantalla (§2), y a la marca le corresponde "su precio mayorista de
-- salida y el volumen de despacho", no el precio final.

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
         m.nombre as marca
    from pedidos p
    join marcas m on m.id = p.marca_id
   where p.socio_id = auth.uid();

drop view if exists pedidos_admin;
create view pedidos_admin with (security_invoker = false) as
  select p.* from pedidos p where es_admin();

grant select on pedidos_socio, pedidos_admin to authenticated;
revoke all on pedidos_socio, pedidos_admin from anon;

-- ---------------------------------------------------------------------------
-- 5 · El reporte contable, en el orden que pide la especificación (§4)
-- ---------------------------------------------------------------------------
--
-- Las ocho columnas obligatorias van primero y en su orden:
--   ID_Pedido | Fecha | Nombre_Marca | RUC_Vendedor | PVP_Total |
--   Costo_Mayorista | Comision_Vendedor | Comision_SOCIO
-- Lo demás se conserva detrás: hace falta para liquidar y para responder un
-- reclamo, y quitarlo no ahorra nada.

drop view if exists reporte_contable;
create view reporte_contable with (security_invoker = false) as
  select p.codigo                as pedido,
         p.creado_en             as fecha,
         m.nombre                as marca,
         s.ruc                   as ruc_vendedor,
         p.precio_publico        as precio_venta,
         p.precio_mayorista      as costo_mayorista,
         p.ganancia_socio        as comision_vendedor,
         p.comision_socio_app    as comision_plataforma,
         -- de aquí en adelante, lo que no pide la especificación pero hace
         -- falta para liquidar, facturar y defenderse de un reclamo
         round(p.comision_socio_app / 1.18, 2)        as comision_plataforma_sin_igv,
         round(p.comision_socio_app * 0.18 / 1.18, 2) as igv_comision_plataforma,
         p.entregado_en          as fecha_entrega,
         p.despachado_en         as fecha_despacho,
         p.estado,
         m.ruc                   as ruc_marca,
         s.nombre                as vendedor,
         s.nivel                 as nivel_vendedor,
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
