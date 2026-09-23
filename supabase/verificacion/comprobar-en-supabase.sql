-- =============================================================================
-- ¿Quedó bien aplicada la migración?
--
-- Esto NO cambia nada: solo mira y reporta. Pégalo en el SQL Editor de Supabase
-- y pulsa Run. Se puede correr las veces que quieras, sin riesgo.
--
-- LO PRIMERO que sale es la lista de las 15 migraciones, diciendo cuáles están
-- aplicadas y cuál toca. Si ahí falta alguna, todo lo que venga después va a
-- salir en ❌ por esa razón y no por otra: aplica lo que falte y vuelve a correr
-- esto antes de mirar nada más.
--
-- Después, el detalle. Lo que debes ver: 10 filas, todas en 'creada'.
--   · Las 4 primeras (marcas, pedidos, productos, usuarios_socios) con
--     permisos_rls = true y con políticas.
--   · Las otras 6 con permisos_rls = false y 0 políticas — así está el diseño
--     de docs/13 hoy (es una de las brechas anotadas, no un fallo de la carga).
--
-- Con la base todavía VACÍA del todo (ni siquiera la 1ª migración), la primera
-- tabla se lee igual, pero varias consultas de más abajo van a cortarse porque
-- preguntan por permisos de tablas que aún no existen. Es lo esperado: aplica
-- la 1ª migración y vuelve.
-- =============================================================================

-- =============================================================================
-- LO PRIMERO: ¿qué migraciones están aplicadas, y cuál es la siguiente?
-- -----------------------------------------------------------------------------
-- Las migraciones se aplican EN ORDEN y cada una se apoya en la anterior. Esta
-- tabla busca, de cada una, una pieza que solo ella crea. La primera que salga
-- ❌ es por donde hay que seguir; de ahí para abajo, todas.
--
-- Solo mira catálogos del sistema, así que se puede correr con la base a medias
-- sin que falle.
-- =============================================================================

with migraciones(orden, archivo, pieza, hay) as (
  values
  ( 1, '20260912000000_modelo_de_datos_inicial',            'tabla usuarios_socios',
       to_regclass('public.usuarios_socios')                         is not null),
  ( 2, '20260912100000_permisos_para_operar',               'vista catalogo_publico',
       to_regclass('public.catalogo_publico')                        is not null),
  ( 3, '20260913120000_administradores',                    'tabla administradores',
       to_regclass('public.administradores')                         is not null),
  ( 4, '20260913180000_estructura_fiscal',                  'pedidos.comprobante_tipo',
       exists (select 1 from information_schema.columns
                where table_name='pedidos' and column_name='comprobante_tipo')),
  ( 5, '20260915100000_manual_operativo',                   'productos.nombre_comprobante',
       exists (select 1 from information_schema.columns
                where table_name='productos' and column_name='nombre_comprobante')),
  ( 6, '20260915180000_especificacion_tecnica',             'pedidos.precio_publico',
       exists (select 1 from information_schema.columns
                where table_name='pedidos' and column_name='precio_publico')),
  ( 7, '20260917100000_circuito_de_venta',                  'función monto_a_pagar()',
       to_regprocedure('monto_a_pagar(text,numeric)')                is not null),
  ( 8, '20260919120000_marca_en_el_catalogo',               'catalogo_publico.marca',
       exists (select 1 from information_schema.columns
                where table_name='catalogo_publico' and column_name='marca')),
  ( 9, '20260920120000_quien_mueve_el_pedido',              'vista liquidaciones_socio',
       to_regclass('public.liquidaciones_socio')                     is not null),
  (10, '20260920140000_los_otros_cuatro_huecos',            'regla retiros_un_solo_dueno',
       exists (select 1 from pg_constraint
                where conname='retiros_un_solo_dueno')),
  (11, '20260921120000_stock_voucher_e_indices',            'índice pagos_hash_imagen_unico',
       to_regclass('public.pagos_hash_imagen_unico')                 is not null),
  (12, '20260921140000_el_deposito_y_su_captura',           'pagos.motivo_rechazo',
       exists (select 1 from information_schema.columns
                where table_name='pagos' and column_name='motivo_rechazo')),
  (13, '20260921160000_la_marca_despacha_y_el_socio_confirma', 'función confirmar_entrega()',
       to_regprocedure('confirmar_entrega(uuid)')                    is not null),
  (14, '20260921170000_el_nivel_baja_si_baja_el_ritmo',     'usuarios_socios.descensos',
       exists (select 1 from information_schema.columns
                where table_name='usuarios_socios' and column_name='descensos')),
  (15, '20260921180000_las_fotos_del_catalogo',             'presentaciones.imagen',
       exists (select 1 from information_schema.columns
                where table_name='presentaciones' and column_name='imagen'))
)
select orden,
       archivo,
       case when hay then '✅ aplicada' else '❌ falta' end as estado,
       pieza                                               as se_reconoce_por
  from migraciones
 order by orden;

-- Y en una línea: por dónde seguir.
select case
         when (select count(*) from (
                 select 1 from information_schema.columns
                  where table_name='presentaciones' and column_name='imagen') x) = 1
              and to_regprocedure('monto_a_pagar(text,numeric)') is not null
         then 'Todo aplicado. Sigue con la cuenta de administrador.'
         else 'Faltan migraciones: aplica, en orden, todas las que salgan ❌ arriba.'
       end as siguiente_paso;


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
select '4 · el socio ve si su pedido ya se liquidó (sin el monto)',
       case when exists (select 1 from information_schema.views
                          where table_name='liquidaciones_socio')
            then '✅' else '❌ falta la vista' end
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
       case when to_regprocedure('monto_a_pagar(text,numeric)') is not null
            then '✅' else '❌ falta — aplica la 7ª migración (20260917100000)' end
union all
-- Aquí NO se llama a monto_a_pagar(): se lee su código, como en el resto del
-- archivo. Postgres resuelve las funciones al planificar la consulta, así que
-- una llamada directa hace fallar el informe ENTERO —y deja de decir nada—
-- justo cuando la función falta, que es cuando más falta hace leerlo.
-- La comprobación numérica de verdad, con 200 montos, está en
-- verificacion/11-circuito-de-venta.sql, que corre contra un Postgres de prueba.
select 'Y nunca cobra de menos',
       case when coalesce((select prosrc from pg_proc
                            where proname='monto_a_pagar'), '')
                 like '%floor(p_total) + 1%'
            then '✅' else '❌ falta, o se perdió el redondeo hacia arriba' end;

-- =============================================================================
-- 8ª migración · La marca, dentro del catálogo
-- =============================================================================

select 'El socio ve de qué marca es cada producto' as regla,
       case when (select count(*) from information_schema.columns
                   where table_name='catalogo_publico'
                     and column_name in ('marca','marca_giro','marca_ciudad_almacen','marca_ciudad_punto')) = 4
            then '✅' else '❌ faltan columnas' end as resultado
union all
select '...sin que se le revele el RUC ni el historial del proveedor',
       case when (select count(*) from information_schema.columns
                   where table_name='catalogo_publico'
                     and column_name in ('ruc','nivel_fiabilidad','entregas_ok','celular')) = 0
            then '✅' else '❌ se filtra algo' end
union all
select '...y el precio mayorista sigue sin aparecer',
       case when (select count(*) from information_schema.columns
                   where table_name='catalogo_publico' and column_name like '%mayorista%') = 0
            then '✅' else '❌ se filtra' end;

-- =============================================================================
-- Migración 20260920 · Quién mueve el pedido
-- Todo debe salir en '✅'.
-- =============================================================================

select 'Solo SOCIO puede validar un pedido para despacho' as regla,
       case when (select prosrc from pg_proc where proname='pedido_transicion_valida')
                 like '%es_admin()%'
            then '✅' else '❌ la marca puede validarse sola' end as resultado
union all
select 'Un pedido no pasa a "pagado" sin un pago declarado',
       case when (select prosrc from pg_proc where proname='pedido_transicion_valida')
                 like '%from pagos pg where pg.pedido_id = new.id%'
            then '✅' else '❌ la marca puede darse por pagada' end
union all
select 'El candado de estados corre con permisos propios',
       case when exists (select 1 from pg_proc
                          where proname='pedido_transicion_valida' and prosecdef)
            then '✅' else '❌ falta security definer' end
union all
select 'El socio ya no lee los montos de la liquidación',
       case when exists (select 1 from pg_policies
                          where tablename='liberaciones_dinero'
                            and policyname='socio ve las liberaciones de sus pedidos')
            then '❌ la política sigue puesta' else '✅' end
union all
select 'Pero sí sabe si su pedido se liquidó, y cuándo',
       case when exists (select 1 from information_schema.views
                          where table_name='liquidaciones_socio')
            then '✅' else '❌ falta la vista liquidaciones_socio' end
union all
select 'Y esa vista no trae el monto',
       case when exists (select 1 from information_schema.columns
                          where table_name='liquidaciones_socio' and column_name='monto')
            then '❌ trae el monto' else '✅' end;

-- =============================================================================
-- Migración 20260920140000 · Los otros cuatro huecos
-- Todo debe salir en '✅'.
-- =============================================================================

select 'La marca ya no lee el monto que paga el socio' as regla,
       case when exists (select 1 from pg_policies
                          where tablename='pagos'
                            and policyname='marca ve el pago de sus pedidos')
            then '❌ la política sigue puesta' else '✅' end as resultado
union all
select 'Pero sí ve si le pagaron, por su vista',
       case when exists (select 1 from information_schema.views where table_name='pagos_marca')
            then '✅' else '❌ falta la vista pagos_marca' end
union all
select '...y esa vista no trae importes',
       case when (select count(*) from information_schema.columns
                   where table_name='pagos_marca'
                     and column_name in ('monto_esperado','monto_reportado','numero_operacion','imagen_voucher_url')) = 0
            then '✅' else '❌ se filtra algo' end
union all
select 'Una marca no puede aprobar su propio producto',
       case when has_column_privilege('authenticated','productos','estado','update')
            then '❌ todavía puede' else '✅' end
union all
select '...ni colarlo ya aprobado al crearlo',
       case when exists (select 1 from pg_trigger where tgname='trg_producto_lo_aprueba_socio')
            then '✅' else '❌ falta el trigger' end
union all
select '...pero sí puede pausarlo y editar su ficha',
       case when has_column_privilege('authenticated','productos','activo','update')
             and has_column_privilege('authenticated','productos','descripcion','update')
            then '✅' else '❌ se le cerró de más' end
union all
select 'Un retiro es de una marca o de un socio, nunca de los dos',
       case when exists (select 1 from pg_constraint where conname='retiros_un_solo_dueno')
            then '✅' else '❌ falta la restricción' end
union all
select 'El monto del retiro lo comprueba la base',
       case when exists (select 1 from pg_proc where proname='solicitar_retiro' and prosecdef)
            then '✅' else '❌ falta solicitar_retiro()' end
union all
select '...y nadie inserta un retiro a mano',
       case when has_table_privilege('authenticated','retiros','insert')
            then '❌ todavía puede' else '✅' end
union all
select 'En la bitácora cada quien firma con su nombre',
       case when exists (select 1 from pg_policies
                          where tablename='bitacora'
                            and policyname='cada quien deja constancia con su nombre')
            then '✅' else '❌ falta la política' end
union all
select '...y sigue sin poder editarse ni borrarse',
       case when has_table_privilege('authenticated','bitacora','update')
              or has_table_privilege('authenticated','bitacora','delete')
            then '❌ todavía puede' else '✅' end;


-- =============================================================================
-- Migración 20260921 · Stock, voucher e índices
-- Todo debe salir en '✅'.
-- =============================================================================

select 'El stock se reserva al registrar el pedido' as regla,
       case when (select prosrc from pg_proc where proname='crear_pedido')
                 like '%set stock_almacen = stock_almacen - it.cant%'
            then '✅' else '❌ el stock no se descuenta' end as resultado
union all
select '...y la reserva es el mismo update que comprueba',
       case when (select prosrc from pg_proc where proname='crear_pedido')
                 like '%and stock_almacen >= it.cant%'
            then '✅' else '❌ vuelve a comprobar por separado' end
union all
select 'Cancelar un pedido devuelve la mercadería',
       case when exists (select 1 from pg_trigger where tgname='trg_devolver_stock')
            then '✅' else '❌ falta el trigger' end
union all
select '...salvo si ya había salido del almacén',
       case when (select prosrc from pg_proc where proname='devolver_stock_al_cancelar')
                 like '%old.estado = ''en_camino''%'
            then '✅' else '❌ devolvería stock que va camino al cliente' end
union all
select 'La misma foto de voucher no paga dos pedidos',
       case when exists (select 1 from pg_indexes
                          where indexname='pagos_hash_imagen_unico')
            then '✅' else '❌ falta el índice único' end
union all
select '...y el socio lee una explicación, no un error de base',
       case when (select prosrc from pg_proc where proname='declarar_pago')
                 like '%ya se usó para pagar otro pedido%'
            then '✅' else '❌ falta el aviso' end
union all
select 'Las claves foráneas por las que se consulta tienen índice',
       case when (select count(*) from pg_indexes
                   where schemaname='public' and indexname like 'idx_%') >= 14
            then '✅' else '❌ faltan índices' end;


-- =============================================================================
-- Migración 20260921140000 · El depósito y su captura
-- Todo debe salir en '✅'.
-- =============================================================================

-- El cubo se consulta con query_to_xml y no con un 'select' normal a propósito:
-- Postgres resuelve los nombres de tabla al leer la consulta, antes de ejecutar
-- nada, así que un 'select ... from storage.buckets' haría fallar este archivo
-- entero en un Postgres sin Supabase. Con query_to_xml el nombre se resuelve al
-- ejecutarse, que es cuando el CASE ya decidió no entrar ahí.

select 'Hay dónde guardar la captura del depósito' as regla,
       case when to_regclass('storage.buckets') is null then '— (esto no es Supabase)'
            when (xpath('/row/c/text()',
                        query_to_xml('select count(*) as c from storage.buckets where id = ''vouchers''',
                                     false, true, '')))[1]::text::int > 0
            then '✅' else '❌ falta el cubo vouchers' end as resultado
union all
select '...y solo el socio dueño y SOCIO la pueden mirar',
       case when to_regclass('storage.objects') is null then '— (esto no es Supabase)'
            when (select count(*) from pg_policies
                   where tablename = 'objects' and schemaname = 'storage'
                     and (coalesce(qual,'') like '%vouchers%'
                          or coalesce(with_check,'') like '%vouchers%')) >= 3
            then '✅' else '❌ faltan reglas del cubo' end
union all
select 'Un pago rechazado devuelve el pedido a la cola',
       case when (select prosrc from pg_proc where proname='validar_pago')
                 like '%estado = ''pendiente_pago''%'
            then '✅' else '❌ el pedido se queda muerto en "pagado"' end
union all
select '...y el socio lee por qué se lo rechazaron',
       case when exists (select 1 from information_schema.columns
                          where table_name='pagos' and column_name='motivo_rechazo')
            then '✅' else '❌ falta la columna' end
union all
select '...pero solo si SOCIO lo rechazó de verdad',
       case when (select prosrc from pg_proc where proname='pedido_transicion_valida')
                 like '%no está rechazado%'
            then '✅' else '❌ la marca puede desandar un pago bueno' end
union all
select 'Y el trigger conserva los controles de despacho',
       case when (select prosrc from pg_proc where proname='pedido_transicion_valida')
                 like '%Falta la foto de la guía%'
            then '✅' else '❌ se perdieron al reescribir la función' end
union all
select 'El socio ve cuánto depositar aunque cierre la app',
       case when exists (select 1 from information_schema.columns
                          where table_name='pedidos_socio' and column_name='monto_a_pagar')
            then '✅' else '❌ falta en la vista' end
union all
select '...y nada del pago que no sea suyo',
       case when not exists (select 1 from information_schema.columns
                              where table_name='pedidos_socio'
                                and column_name in ('validado_por','validado_en','hash_imagen'))
            then '✅' else '❌ se le escapó una columna de SOCIO' end
union all
select 'SOCIO tiene su cola de validación',
       case when to_regclass('cola_de_validacion') is not null
            then '✅' else '❌ falta la vista' end
union all
select 'Un pedido sin pagar se puede cancelar y devuelve el stock',
       case when exists (select 1 from pg_proc where proname='cancelar_pedido_sin_pagar')
            then '✅' else '❌ falta la función' end
union all
select 'La entrega la confirma el socio, no la marca',
       case when (select prosrc from pg_proc where proname='pedido_transicion_valida')
                 like '%La entrega la confirma el socio%'
            then '✅' else '❌ la marca se da por entregada sola y cobra' end
union all
select '...y tiene su botón',
       case when exists (select 1 from pg_proc where proname='confirmar_entrega')
            then '✅' else '❌ falta la función' end
union all
select 'La marca ve qué empacar en cada pedido',
       case when exists (select 1 from information_schema.columns
                          where table_name='pedido_items_marca' and column_name='producto')
            then '✅' else '❌ solo ve ids de presentación' end
union all
select '...y sigue sin ver lo que paga el socio',
       case when not exists (select 1 from information_schema.columns
                              where table_name='pedido_items_marca'
                                and column_name='precio_unit_socio')
            then '✅' else '❌ se le escapó el precio del socio' end
union all
select 'El nivel del socio también puede bajar',
       case when exists (select 1 from information_schema.columns
                          where table_name='usuarios_socios' and column_name='descensos')
            then '✅' else '❌ falta la columna' end
union all
select '...y SOCIO tiene la revisión del trimestre',
       case when exists (select 1 from pg_proc where proname='revisar_niveles_trimestrales')
            then '✅' else '❌ falta la función' end;
