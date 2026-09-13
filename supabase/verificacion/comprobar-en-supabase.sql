-- =============================================================================
-- ¿Quedó bien aplicada la migración?
--
-- Esto NO cambia nada: solo mira y reporta. Pégalo en el SQL Editor de Supabase
-- y pulsa Run. Se puede correr las veces que quieras, sin riesgo.
--
-- Lo que debes ver: 10 filas, todas en 'creada'.
--   · Las 4 primeras (marcas, pedidos, productos, usuarios_socios) con
--     permisos_rls = true y con políticas.
--   · Las otras 6 con permisos_rls = false y 0 políticas — así está el diseño
--     de docs/13 hoy (es una de las brechas anotadas, no un fallo de la carga).
-- =============================================================================

with esperado(tabla) as (
  values ('usuarios_socios'),('marcas'),('productos'),('presentaciones'),
         ('pedidos'),('pedido_items'),('pagos'),('liberaciones_dinero'),
         ('retiros'),('bitacora')
)
select
  e.tabla,
  case when t.tablename is null then '❌ FALTA' else '✅ creada' end as estado,
  coalesce(t.rowsecurity, false)                                    as permisos_rls,
  (select count(*) from pg_policies p
    where p.schemaname = 'public' and p.tablename = e.tabla)        as politicas
from esperado e
left join pg_tables t
  on t.schemaname = 'public' and t.tablename = e.tabla
order by e.tabla;

-- Resumen en una sola fila.
--   Solo la 1ª migración .............. 10 / 4 /  7 / 0 / 1 / 0
--   Con la 2ª (permisos para operar) .. 10 / 10 / 22 / 1 / 1 / 1
select
  (select count(*) from pg_tables
     where schemaname = 'public')                      as tablas,
  (select count(*) from pg_tables
     where schemaname = 'public' and rowsecurity)      as con_permisos,
  (select count(*) from pg_policies
     where schemaname = 'public')                      as politicas,
  (select count(*) from pg_views
     where schemaname = 'public'
       and viewname = 'catalogo_publico')              as vista_catalogo,
  (select count(*) from pg_trigger
     where tgname = 'trg_nivel_socio')                 as trigger_nivel,
  (select count(*) from pg_proc
     where proname = 'actualizar_nivel_socio'
       and prosecdef)                                  as trigger_con_permiso;

-- =============================================================================
-- 4ª migración · Estructura fiscal (informe del contador, sección 4)
-- Todo debe salir en '✅'.
-- =============================================================================

select 'A · el socio no puede leer el precio mayorista del pedido' as regla,
       case when has_column_privilege('authenticated','pedidos','precio_mayorista','select')
            then '❌ lo ve' else '✅' end as resultado
union all
select 'A · nadie (salvo SOCIO) lee la comisión de la plataforma',
       case when has_column_privilege('authenticated','pedidos','comision_socio_app','select')
            then '❌ la ve' else '✅' end
union all
select 'A · el socio no ve el mayorista de cada línea del pedido',
       case when has_column_privilege('authenticated','pedido_items','precio_unit_mayorista','select')
            then '❌ lo ve' else '✅' end
union all
select 'A · la marca no puede reescribir los importes de un pedido',
       case when has_column_privilege('authenticated','pedidos','precio_mayorista','update')
            then '❌ puede' else '✅' end
union all
select 'A · existen las vistas por rol',
       case when (select count(*) from pg_views where schemaname='public'
                   and viewname in ('pedidos_socio','pedidos_marca','pedidos_admin',
                                    'pedido_items_socio','pedido_items_marca')) = 5
            then '✅' else '❌ faltan' end
union all
select 'B · el socio tiene dónde poner su RUC de emisor',
       case when (select count(*) from information_schema.columns
                   where table_name='usuarios_socios'
                     and column_name in ('ruc','razon_social','direccion_fiscal','emite_comprobante')) = 4
            then '✅' else '❌ faltan columnas' end
union all
select 'B · existe registrar_comprobante()',
       case when exists (select 1 from pg_proc where proname='registrar_comprobante')
            then '✅' else '❌ falta' end
union all
select 'C · el pedido tiene el estado "validado"',
       case when (select pg_get_constraintdef(oid) from pg_constraint
                   where conname='pedidos_estado_check') like '%validado%'
            then '✅' else '❌ falta' end
union all
select 'C · hay dónde guardar guía, courier y tracking',
       case when (select count(*) from information_schema.columns
                   where table_name='pedidos'
                     and column_name in ('courier','tracking','guia_url')) = 3
            then '✅' else '❌ faltan columnas' end
union all
select 'C · el despacho sin evidencia queda bloqueado por la base',
       case when exists (select 1 from pg_trigger where tgname='trg_pedido_transicion')
            then '✅' else '❌ falta el trigger' end
union all
select 'C · registrar el pago mueve el pedido solo',
       case when exists (select 1 from pg_trigger where tgname='trg_pago_registrado')
            then '✅' else '❌ falta el trigger' end
union all
select 'D · existe el reporte contable',
       case when exists (select 1 from pg_views where schemaname='public'
                          and viewname='reporte_contable')
            then '✅' else '❌ falta' end;
