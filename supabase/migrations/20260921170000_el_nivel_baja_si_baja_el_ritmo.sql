-- =============================================================================
-- SOCIO · El nivel del socio también baja
--
-- La pantalla del socio le promete desde el primer día lo que dice docs/09:
--
--   «El nivel se revisa cada trimestre. Si el socio baja su ritmo, desciende un
--    escalón (nunca dos de golpe).»
--
-- La base solo sabía subir. Un socio que vendió 50 en enero y nada desde
-- entonces seguía siendo Diamante —con su 20% de descuento— para siempre.
--
-- El problema de fondo es que el nivel se calculaba cada vez desde el total
-- histórico de ventas entregadas, que solo crece. Bajarle el nivel a mano no
-- servía de nada: a la siguiente venta el trigger lo recalculaba desde el
-- total y lo devolvía a Diamante.
--
-- La solución es separar las dos cosas:
--
--   · ventas_entregadas  · el total histórico. Solo sube. Dice qué escalón
--                          llegó a abrir.
--   · descensos          · cuántos escalones ha perdido por bajar el ritmo.
--
--   nivel = escalón_por_volumen(ventas_entregadas) − descensos, con piso en
--   Bronce.
--
-- Así el mérito no se borra y el descuento sí se apaga: quien vuelve a vender
-- recupera su escalón en la revisión siguiente, sin tener que rehacer las 50
-- ventas.
--
-- QUÉ RITMO SE PIDE PARA CONSERVAR EL NIVEL (decisión de esta migración, no de
-- docs/09, que dice «baja el ritmo» sin poner número):
--
--   🥈 Plata     ·  3 entregas en el trimestre
--   🥇 Oro       ·  7 entregas en el trimestre
--   💎 Diamante  · 13 entregas en el trimestre
--
-- Es la cuarta parte de lo que costó abrir el escalón —quien llegó a Plata con
-- 10 entregas conserva Plata entregando 3 cada trimestre—. Si a Jason le
-- parece mucho o poco, se cambia ahí abajo, en ritmo_del_nivel(), y nada más.
--
-- Bronce no baja de ningún sitio: es el escalón de entrada.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · Dos columnas nuevas
-- ---------------------------------------------------------------------------

alter table usuarios_socios add column if not exists descensos int not null default 0;
alter table usuarios_socios add column if not exists nivel_revisado_en timestamptz;

comment on column usuarios_socios.descensos is
  'Escalones perdidos por bajar el ritmo. El nivel es el que abrió su volumen histórico menos esto, con piso en bronce.';
comment on column usuarios_socios.nivel_revisado_en is
  'Cuándo se le revisó el nivel por última vez. Vacío = nunca; se revisa en la primera pasada que le toque.';

-- Las columnas nuevas NO entran en el permiso de escritura del socio: la lista
-- de columnas que puede tocar se fijó en 20260913180000 y sigue igual. El nivel
-- es de la base, no del navegador.

-- ---------------------------------------------------------------------------
-- 2 · El escalón que abre el volumen, y el que queda tras los descensos
-- ---------------------------------------------------------------------------

create or replace function escalon_por_ventas(p_ventas int)
returns int
language sql
immutable
as $$
  select case
           when coalesce(p_ventas, 0) >= 50 then 4   -- diamante
           when coalesce(p_ventas, 0) >= 25 then 3   -- oro
           when coalesce(p_ventas, 0) >= 10 then 2   -- plata
           else 1                                    -- bronce
         end;
$$;

create or replace function nombre_del_escalon(p_escalon int)
returns text
language sql
immutable
as $$
  select case greatest(1, least(4, coalesce(p_escalon, 1)))
           when 4 then 'diamante'
           when 3 then 'oro'
           when 2 then 'plata'
           else        'bronce'
         end;
$$;

create or replace function nivel_que_le_toca(p_ventas int, p_descensos int)
returns text
language sql
immutable
as $$
  select nombre_del_escalon(escalon_por_ventas(p_ventas) - greatest(0, coalesce(p_descensos, 0)));
$$;

comment on function nivel_que_le_toca(int, int) is
  'El nivel de un socio: el escalón que abrió su volumen histórico, menos los que perdió por bajar el ritmo, con piso en bronce.';

-- El ritmo trimestral que pide cada escalón para conservarse.
create or replace function ritmo_del_nivel(p_nivel text)
returns int
language sql
immutable
as $$
  select case p_nivel
           when 'diamante' then 13
           when 'oro'      then 7
           when 'plata'    then 3
           else 0                    -- bronce no baja
         end;
$$;

-- ---------------------------------------------------------------------------
-- 3 · El trigger de siempre, ahora respetando los descensos
-- ---------------------------------------------------------------------------
--
-- Se reescribe entera la de 20260912100000 (la última). Conserva lo suyo: es
-- la base quien sube el nivel, con 'security definer', porque quien hace el
-- update del pedido es la marca o SOCIO, no el socio.

create or replace function actualizar_nivel_socio()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado = 'entregado' and old.estado != 'entregado' then
    update usuarios_socios
       set ventas_entregadas = ventas_entregadas + 1,
           nivel = nivel_que_le_toca(ventas_entregadas + 1, descensos)
     where id = new.socio_id;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4 · La revisión del trimestre
-- ---------------------------------------------------------------------------
--
-- La lanza SOCIO desde su panel. No hay tarea programada en este proyecto y no
-- hace falta: la revisión es idempotente por socio —solo entra quien lleva un
-- trimestre sin revisar— así que pulsarla dos veces el mismo día no baja a
-- nadie dos veces.
--
-- Quien se registró hace menos de un trimestre no se revisa: todavía no ha
-- tenido un trimestre entero para vender.
--
-- Si Jason prefiere que corra sola, en Supabase se agenda con pg_cron:
--   select cron.schedule('niveles', '0 6 1 1,4,7,10 *', 'select revisar_niveles_trimestrales()');

create or replace function revisar_niveles_trimestrales()
returns table (
  socio_id           uuid,
  nombre             text,
  nivel_antes        text,
  nivel_despues      text,
  entregas_trimestre int,
  ritmo_pedido       int
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not es_admin() then
    raise exception 'Solo un administrador de SOCIO revisa los niveles del trimestre.';
  end if;

  return query
  with a_revisar as (
    select s.id,
           s.nombre,
           s.nivel,
           s.ventas_entregadas,
           s.descensos,
           (select count(*)
              from pedidos p
             where p.socio_id = s.id
               and p.estado = 'entregado'
               and p.entregado_en >= now() - interval '90 days')::int as entregas
      from usuarios_socios s
     where s.creado_en <= now() - interval '90 days'
       and (s.nivel_revisado_en is null
            or s.nivel_revisado_en <= now() - interval '85 days')
  ),
  decidido as (
    select r.*,
           ritmo_del_nivel(r.nivel) as ritmo,
           case
             -- Bajó el ritmo: pierde un escalón, nunca dos.
             when ritmo_del_nivel(r.nivel) > 0 and r.entregas < ritmo_del_nivel(r.nivel)
               then r.descensos + 1
             -- Lo mantuvo y arrastraba un descenso: recupera uno.
             when r.descensos > 0 and r.entregas >= ritmo_del_nivel(r.nivel)
               then r.descensos - 1
             else r.descensos
           end as descensos_nuevos
      from a_revisar r
  ),
  aplicado as (
    update usuarios_socios s
       set descensos = d.descensos_nuevos,
           nivel = nivel_que_le_toca(s.ventas_entregadas, d.descensos_nuevos),
           nivel_revisado_en = now()
      from decidido d
     where s.id = d.id
    returning s.id, s.nombre, d.nivel as antes, s.nivel as despues,
              d.entregas, d.ritmo
  )
  select a.id, a.nombre, a.antes, a.despues, a.entregas, a.ritmo
    from aplicado a
   where a.antes is distinct from a.despues
   order by a.nombre;
end;
$$;

revoke execute on function revisar_niveles_trimestrales() from anon;

comment on function revisar_niveles_trimestrales() is
  'La revisión trimestral de docs/09: baja un escalón a quien no sostuvo el ritmo de su nivel y devuelve uno a quien lo recuperó. Devuelve solo a los socios cuyo nivel cambió.';

commit;
