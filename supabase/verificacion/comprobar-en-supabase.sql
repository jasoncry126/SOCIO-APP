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

-- =============================================================================
-- 5ª migración · Manual operativo (set-2026)
-- Todo debe salir en '✅'.
-- =============================================================================

select '1 · el producto tiene nombre para la boleta del cliente' as regla,
       case when exists (select 1 from information_schema.columns
                          where table_name='productos' and column_name='nombre_comprobante')
            then '✅' else '❌ falta' end as resultado
union all
select '1 · y el vendedor lo ve en el catálogo',
       case when exists (select 1 from information_schema.columns
                          where table_name='catalogo_publico' and column_name='nombre_comprobante')
            then '✅' else '❌ falta' end
union all
select '3 · la entrega local se puede despachar sin courier',
       case when pg_get_functiondef(p.oid) like '%modo_entrega = ''agencia''%'
            then '✅' else '❌ sigue exigiendo courier a todos' end
  from pg_proc p where p.proname = 'pedido_transicion_valida'
union all
select '4 · la liquidación se registra sola en cada hito',
       case when exists (select 1 from pg_trigger where tgname='trg_liquidar_hito')
            then '✅' else '❌ falta el trigger' end
union all
select '4 · el socio ve si su pedido ya se liquidó',
       case when exists (select 1 from pg_policies
                          where tablename='liberaciones_dinero'
                            and policyname='socio ve las liberaciones de sus pedidos')
            then '✅' else '❌ falta la política' end
union all
select '4.3 · el reporte trae el estado de la liquidación',
       case when (select count(*) from information_schema.columns
                   where table_name='reporte_contable'
                     and column_name in ('liberado_a_marca','pendiente_a_marca')) = 2
            then '✅' else '❌ faltan columnas' end;

-- =============================================================================
-- 6ª migración · Especificación técnica del flujo financiero (set-2026)
-- Todo debe salir en '✅'.
-- =============================================================================

select '§1 · el PVP es un dato propio del pedido' as regla,
       case when exists (select 1 from information_schema.columns
                          where table_name='pedidos' and column_name='precio_publico')
            then '✅' else '❌ falta' end as resultado
union all
select '§1 · y no se puede desfasar (es calculado)',
       case when (select is_generated from information_schema.columns
                   where table_name='pedidos' and column_name='precio_publico') = 'ALWAYS'
            then '✅' else '❌ se puede escribir a mano' end
union all
select 'FASE 3 · la foto de la guía es obligatoria para despachar',
       case when pg_get_functiondef(p.oid) like '%guia_url%'
            then '✅' else '❌ no se exige' end
  from pg_proc p where p.proname = 'pedido_transicion_valida'
union all
select 'FASE 3 · existen las reglas del cubo privado de guías',
       case when exists (select 1 from pg_policies
                          where schemaname='storage' and tablename='objects'
                            and policyname like '%guias%')
            then '✅' else '— (esto no es Supabase, o falta el cubo)' end
union all
select '§2 · la marca NO ve el precio final ni las comisiones',
       case when (select count(*) from information_schema.columns
                   where table_name='pedidos_marca'
                     and column_name in ('precio_publico','precio_socio','ganancia_socio','comision_socio_app')) = 0
            then '✅' else '❌ ve alguno' end
union all
select '§2 · el vendedor SÍ ve el PVP que pagó su cliente',
       case when exists (select 1 from information_schema.columns
                          where table_name='pedidos_socio' and column_name='precio_publico')
            then '✅' else '❌ falta' end
union all
select '§4 · las ocho columnas obligatorias van primero y en orden',
       case when (select string_agg(column_name, ',' order by ordinal_position)
                    from information_schema.columns
                   where table_name='reporte_contable' and ordinal_position <= 8)
                 = 'pedido,fecha,marca,ruc_vendedor,precio_venta,costo_mayorista,comision_vendedor,comision_plataforma'
            then '✅' else '❌ orden distinto' end;

-- =============================================================================
-- 7ª migración · Circuito de venta
-- Todo debe salir en '✅'.
-- =============================================================================

select 'El pedido lo crea la base, no el navegador' as regla,
       case when exists (select 1 from pg_proc where proname='crear_pedido' and prosecdef)
            then '✅' else '❌ falta' end as resultado
union all
select 'El pago lo registra la base, con su monto recalculado',
       case when exists (select 1 from pg_proc where proname='declarar_pago' and prosecdef)
            then '✅' else '❌ falta' end
union all
select 'Nadie puede insertar un pedido a mano (ni inventarse su comisión)',
       case when has_table_privilege('authenticated','pedidos','insert')
            then '❌ todavía puede' else '✅' end
union all
select 'Ni sus líneas',
       case when has_table_privilege('authenticated','pedido_items','insert')
            then '❌ todavía puede' else '✅' end
union all
select 'Ni un pago con el monto que quiera',
       case when has_table_privilege('authenticated','pagos','insert')
            then '❌ todavía puede' else '✅' end
union all
select 'El monto a pagar lleva céntimos únicos (docs/12 capa 2)',
       case when exists (select 1 from pg_proc where proname='monto_a_pagar')
            then '✅' else '❌ falta' end
union all
select 'Y nunca cobra de menos',
       case when (select count(*) from generate_series(1,200) g
                   where monto_a_pagar('SOC-'||g, 100 + g*0.37) < round((100 + g*0.37)::numeric,2)) = 0
            then '✅' else '❌ hay casos que cobran de menos' end;
