-- Especificación técnica del flujo financiero (contador, set-2026).
-- Se ejecuta después de 09.

set role postgres;
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,agencia,detalle_entrega,estado)
values ('f0000000-0000-0000-0000-00000000000a','SOC-ESP-001','c0000000-0000-0000-0000-00000000000a',
 'b0000000-0000-0000-0000-00000000000b',157.50,129.67,17.50,27.83,'Cliente Spec','70000020','940000020',
 'almacen','agencia','olva','Olva Lima','validado'),
 ('f0000000-0000-0000-0000-00000000000b','SOC-ESP-002','c0000000-0000-0000-0000-00000000000a',
 'b0000000-0000-0000-0000-00000000000b',157.50,129.67,17.50,27.83,'Cliente Local','70000021','940000021',
 'punto_venta','domicilio',null,'Av. Pardo 100','validado');
set role authenticated;

\echo '=================== §1 · DICCIONARIO DE MONTOS ==================='

\echo '### 1a · Los cuatro montos existen por separado en el pedido'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select precio_publico as pvp, precio_mayorista as costo_mayorista,
       ganancia_socio as comision_vendedor, comision_socio_app as comision_socio
  from pedidos_admin where codigo = 'SOC-ESP-001';

\echo '### 1b · El PVP cuadra: 129.67 + 17.50 + 27.83 = 175.00'
select precio_publico,
       precio_mayorista + ganancia_socio + comision_socio_app as suma_de_las_partes,
       precio_publico = precio_mayorista + ganancia_socio + comision_socio_app as cuadra
  from pedidos_admin where codigo = 'SOC-ESP-001';

\echo '### 1c · El PVP no se puede desfasar: es calculado, no se escribe a mano (debe: fallar)'
set role postgres;
update pedidos set precio_publico = 999 where codigo = 'SOC-ESP-001';
set role authenticated;

\echo ''
\echo '=================== §2 · PRIVACIDAD POR PANTALLA ==================='

\echo '### 2a · El VENDEDOR ve el PVP, lo que paga y lo que gana'
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000a';
select codigo, precio_publico, precio_socio, ganancia_socio from pedidos_socio
 where codigo = 'SOC-ESP-001';

\echo '### 2b · ...y sigue sin ver el mayorista ni la comisión de SOCIO'
select string_agg(column_name, ', ') as columnas_prohibidas_en_su_vista
  from information_schema.columns
 where table_name = 'pedidos_socio'
   and column_name in ('precio_mayorista','comision_socio_app');

\echo '### 2c · La MARCA ve su mayorista, pero NO el precio final ni las comisiones'
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000b';
select codigo, precio_mayorista from pedidos_marca where codigo = 'SOC-ESP-001';
select string_agg(column_name, ', ') as columnas_prohibidas_en_su_vista
  from information_schema.columns
 where table_name = 'pedidos_marca'
   and column_name in ('precio_publico','precio_socio','ganancia_socio','comision_socio_app');

\echo ''
\echo '=================== FASE 3 · CANDADO LOGÍSTICO CON FOTO ==================='

\echo '### 3a · Con número de guía y tracking, pero SIN FOTO (debe: fallar)'
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000b';
update pedidos set estado='en_camino', numero_guia='T001-5000', courier='olva', tracking='OLV-5000'
 where codigo = 'SOC-ESP-001';

\echo '### 3b · Con foto pero sin número de guía (debe: fallar)'
update pedidos set estado='en_camino', guia_url='guias/b0000000-0000-0000-0000-00000000000b/SOC-ESP-001.jpg',
       courier='olva', tracking='OLV-5000'
 where codigo = 'SOC-ESP-001';

\echo '### 3c · Con foto y guía pero sin tracking, siendo envío por agencia (debe: fallar)'
update pedidos set estado='en_camino', numero_guia='T001-5000',
       guia_url='guias/b0000000-0000-0000-0000-00000000000b/SOC-ESP-001.jpg'
 where codigo = 'SOC-ESP-001';

\echo '### 3d · Con los cuatro datos: pasa'
update pedidos set estado='en_camino', numero_guia='T001-5000', courier='olva', tracking='OLV-5000',
       guia_url='guias/b0000000-0000-0000-0000-00000000000b/SOC-ESP-001.jpg'
 where codigo = 'SOC-ESP-001';
select codigo, estado, numero_guia, courier, tracking, guia_url is not null as tiene_foto
  from pedidos_marca where codigo = 'SOC-ESP-001';

\echo '### 3e · Entrega local: sin courier, pero la foto de la guía SIGUE siendo obligatoria (debe: fallar)'
update pedidos set estado='en_camino', numero_guia='T002-5001' where codigo = 'SOC-ESP-002';

\echo '### 3f · Entrega local con guía y foto: pasa'
update pedidos set estado='en_camino', numero_guia='T002-5001',
       guia_url='guias/b0000000-0000-0000-0000-00000000000b/SOC-ESP-002.jpg'
 where codigo = 'SOC-ESP-002';
select codigo, estado, courier, tracking, guia_url is not null as tiene_foto
  from pedidos_marca where codigo = 'SOC-ESP-002';

\echo ''
\echo '=================== §4 · REPORTE CONTABLE ==================='

\echo '### 4a · Las ocho columnas obligatorias, primero y en su orden'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select string_agg(column_name, ' | ' order by ordinal_position) as las_ocho_primeras
  from information_schema.columns
 where table_name = 'reporte_contable' and ordinal_position <= 8;

\echo '### 4b · Y traen los datos del ejemplo del contador'
select pedido, marca, ruc_vendedor, precio_venta, costo_mayorista,
       comision_vendedor, comision_plataforma
  from reporte_contable where pedido = 'SOC-ESP-001';

\echo '### 4c · Se puede agrupar por periodo, que es como se factura'
select to_char(date_trunc('month', fecha), 'YYYY-MM') as periodo,
       count(*) as pedidos,
       sum(precio_venta)        as vendido,
       sum(comision_plataforma) as comision_socio
  from reporte_contable
 group by 1 order by 1;
