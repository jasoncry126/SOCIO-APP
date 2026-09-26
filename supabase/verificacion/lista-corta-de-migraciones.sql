-- =============================================================================
-- ¿Qué migraciones tiene puestas la base? — versión corta
--
-- Es UNA sola consulta. No cambia nada: solo mira y reporta, y se puede correr
-- las veces que quieras. Pégala entera en el SQL Editor de Supabase y pulsa Run.
--
-- Existe porque el comprobador largo (`00-EMPIEZA-AQUI-que-falta.sql`) son 600
-- líneas y, si al pegarlo se queda un trozo fuera o se ejecuta solo lo que está
-- seleccionado, Postgres se queja de un error de sintaxis que no es del archivo.
-- Esto cabe de un vistazo, así que eso no puede pasar.
--
-- Devuelve 16 filas: las 15 migraciones, y al final por dónde seguir.
-- =============================================================================

with migraciones(orden, archivo, hay) as (
  values
  ( 1, '20260912000000_modelo_de_datos_inicial',
       to_regclass('public.usuarios_socios')                is not null),
  ( 2, '20260912100000_permisos_para_operar',
       to_regclass('public.catalogo_publico')               is not null),
  ( 3, '20260913120000_administradores',
       to_regclass('public.administradores')                is not null),
  ( 4, '20260913180000_estructura_fiscal',
       exists (select 1 from information_schema.columns
                where table_name='pedidos' and column_name='comprobante_tipo')),
  ( 5, '20260915100000_manual_operativo',
       exists (select 1 from information_schema.columns
                where table_name='productos' and column_name='nombre_comprobante')),
  ( 6, '20260915180000_especificacion_tecnica',
       exists (select 1 from information_schema.columns
                where table_name='pedidos' and column_name='precio_publico')),
  ( 7, '20260917100000_circuito_de_venta',
       to_regprocedure('monto_a_pagar(text,numeric)')       is not null),
  ( 8, '20260919120000_marca_en_el_catalogo',
       exists (select 1 from information_schema.columns
                where table_name='catalogo_publico' and column_name='marca')),
  ( 9, '20260920120000_quien_mueve_el_pedido',
       to_regclass('public.liquidaciones_socio')            is not null),
  (10, '20260920140000_los_otros_cuatro_huecos',
       exists (select 1 from pg_constraint
                where conname='retiros_un_solo_dueno')),
  (11, '20260921120000_stock_voucher_e_indices',
       to_regclass('public.pagos_hash_imagen_unico')        is not null),
  (12, '20260921140000_el_deposito_y_su_captura',
       exists (select 1 from information_schema.columns
                where table_name='pagos' and column_name='motivo_rechazo')),
  (13, '20260921160000_la_marca_despacha_y_el_socio_confirma',
       to_regprocedure('confirmar_entrega(uuid)')           is not null),
  (14, '20260921170000_el_nivel_baja_si_baja_el_ritmo',
       exists (select 1 from information_schema.columns
                where table_name='usuarios_socios' and column_name='descensos')),
  (15, '20260921180000_las_fotos_del_catalogo',
       exists (select 1 from information_schema.columns
                where table_name='presentaciones' and column_name='imagen'))
),
cuentas as (
  select min(orden) filter (where not hay) as primera_que_falta,
         max(orden) filter (where hay)     as ultima_aplicada,
         count(*)   filter (where not hay) as cuantas_faltan
    from migraciones
)
select n, migracion, estado from (
  select orden as sort, orden::text as n, archivo as migracion,
         case when hay then '✅ aplicada' else '❌ falta' end as estado
    from migraciones
  union all
  -- El caso feo es el HUECO: una sin aplicar con otras posteriores ya puestas.
  -- Pasa sin que nadie se entere, porque aplicar la 13ª sobre una base a la que
  -- le falta la 12ª no da ningún error. Y tiene trampa al repararlo: varias
  -- migraciones reescriben enteras las mismas funciones, así que aplicar ahora
  -- la que faltaba PISA la versión buena que dejó una posterior.
  select 99, '→', 'SIGUIENTE PASO',
         case
           when cuantas_faltan = 0
             then 'Todo aplicado. Sigue con la cuenta de administrador.'
           when ultima_aplicada > primera_que_falta
             then 'HUECO: falta la ' || primera_que_falta || 'ª pero la ' ||
                  ultima_aplicada || 'ª ya está puesta. Vuelve a correr ' ||
                  'REINSTALAR-TODO-DE-CERO.sql, que las pone las quince en orden.'
           else 'Faltan ' || cuantas_faltan || ': corre REINSTALAR-TODO-DE-CERO.sql.'
         end
    from cuentas
) t
 order by sort;
