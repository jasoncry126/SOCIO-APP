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

-- Resumen en una sola fila. Esperado: 10 / 7 / 1 / 1
select
  (select count(*) from pg_tables
     where schemaname = 'public')                      as tablas_creadas,
  (select count(*) from pg_policies
     where schemaname = 'public')                      as politicas,
  (select count(*) from pg_proc
     where proname = 'actualizar_nivel_socio')         as funcion_nivel,
  (select count(*) from pg_trigger
     where tgname = 'trg_nivel_socio')                 as trigger_nivel;
