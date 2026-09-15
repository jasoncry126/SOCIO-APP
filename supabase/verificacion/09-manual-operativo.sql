-- Manual operativo del contador (set-2026), comprobado paso por paso.
-- Se ejecuta después de 08 y usa datos propios para no pisar nada.

set role postgres;

-- Cuatro marcas, una por nivel de fiabilidad, para ver el reparto de los hitos.
insert into marcas (id,nombre,ruc,giro,ciudad_almacen,ciudad_punto,celular,clave_hash,nivel_fiabilidad) values
 ('b0000000-0000-0000-0000-00000000000a','Marca Nueva'     ,'20000000001','varios','Lima','Lima','940000001','x','nueva'),
 ('b0000000-0000-0000-0000-00000000000b','Marca Confiable' ,'20000000002','varios','Lima','Lima','940000002','x','confiable'),
 ('b0000000-0000-0000-0000-00000000000c','Marca Preferente','20000000003','varios','Lima','Lima','940000003','x','preferente'),
 ('b0000000-0000-0000-0000-00000000000d','Marca Aliada'    ,'20000000004','varios','Lima','Lima','940000004','x','aliada');

insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad,ruc)
 values ('c0000000-0000-0000-0000-00000000000a','Vendedor Manual','55667788','940000009','x','Lima','10556677889');

-- Un pedido por marca, en 'validado', listo para despachar. Precio mayorista
-- 129.67 y público 175.00: el ejemplo exacto del manual.
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,agencia,detalle_entrega,estado)
select ('d0000000-0000-0000-0000-00000000000' || sufijo)::uuid,
       'SOC-MAN-' || upper(sufijo),
       'c0000000-0000-0000-0000-00000000000a',
       ('b0000000-0000-0000-0000-00000000000' || sufijo)::uuid,
       157.50, 129.67, 17.50, 27.83,
       'Cliente Final','70000009','940000008','almacen','agencia','olva','Olva Lima','validado'
  from unnest(array['a','b','c','d']) as sufijo;

set role authenticated;

\echo '=================== 2 · EL REPARTO DEL MANUAL ==================='
\echo '### El ejemplo del manual: 175.00 = 129.67 marca + 17.50 vendedor + 27.83 SOCIO'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select precio_mayorista + ganancia_socio + comision_socio_app as suma,
       precio_socio + ganancia_socio                          as precio_venta,
       (precio_mayorista + ganancia_socio + comision_socio_app
         = precio_socio + ganancia_socio)                     as cuadra
  from pedidos_admin where codigo = 'SOC-MAN-A';

\echo ''
\echo '=================== PASO 3 · CANDADO LOGÍSTICO ==================='

\echo '### 3a · Envío por agencia SIN courier ni tracking (debe: fallar)'
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000a';
update pedidos set estado='en_camino', numero_guia='T001-900'
 where id='d0000000-0000-0000-0000-00000000000a';

\echo '### 3b · Envío por agencia SIN guía de remisión (debe: fallar)'
update pedidos set estado='en_camino', courier='olva', tracking='OLV-1'
 where id='d0000000-0000-0000-0000-00000000000a';

\echo '### 3c · Entrega LOCAL a domicilio: basta la guía, no hay courier'
set role postgres;
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,detalle_entrega,estado)
values ('d0000000-0000-0000-0000-0000000000ee','SOC-MAN-LOCAL','c0000000-0000-0000-0000-00000000000a',
  'b0000000-0000-0000-0000-00000000000b',157.50,129.67,17.50,27.83,'Cliente Lima','70000010','940000007',
  'punto_venta','domicilio','Av. Arequipa 1234, San Isidro','validado');
set role authenticated;
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000b';
update pedidos set estado='en_camino', numero_guia='T002-0001'
 where id='d0000000-0000-0000-0000-0000000000ee';
select codigo, estado, numero_guia, courier from pedidos_marca where codigo='SOC-MAN-LOCAL';

\echo '### 3d · ...pero la entrega local TAMPOCO se despacha sin guía (debe: fallar)'
set role postgres;
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,detalle_entrega,estado)
values ('d0000000-0000-0000-0000-0000000000ef','SOC-MAN-LOCAL2','c0000000-0000-0000-0000-00000000000a',
  'b0000000-0000-0000-0000-00000000000b',157.50,129.67,17.50,27.83,'Cliente Lima 2','70000011','940000006',
  'punto_venta','domicilio','Av. Larco 500, Miraflores','validado');
set role authenticated;
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000b';
update pedidos set estado='en_camino' where id='d0000000-0000-0000-0000-0000000000ef';

\echo ''
\echo '=================== PASO 4 · LIQUIDACIÓN AUTOMÁTICA ==================='

\echo '### 4a · Las cuatro marcas despachan (envío nacional, con las tres evidencias)'
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000a';
update pedidos set estado='en_camino', numero_guia='G-A', courier='olva', tracking='T-A'
 where id='d0000000-0000-0000-0000-00000000000a';
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000b';
update pedidos set estado='en_camino', numero_guia='G-B', courier='olva', tracking='T-B'
 where id='d0000000-0000-0000-0000-00000000000b';
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000c';
update pedidos set estado='en_camino', numero_guia='G-C', courier='olva', tracking='T-C'
 where id='d0000000-0000-0000-0000-00000000000c';
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000d';
update pedidos set estado='en_camino', numero_guia='G-D', courier='olva', tracking='T-D'
 where id='d0000000-0000-0000-0000-00000000000d';

\echo '### 4b · Lo liberado al registrar la guía, según el nivel de fiabilidad'
\echo '--   esperado: nueva 0.00 · confiable 90.77 (70%) · preferente 116.70 (90%) · aliada 129.67 (100%)'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select m.nivel_fiabilidad, p.codigo, l.hito, l.monto
  from liberaciones_dinero l
  join pedidos_admin p on p.id = l.pedido_id
  join marcas  m on m.id = l.marca_id
 where p.codigo like 'SOC-MAN-_'
 order by m.nivel_fiabilidad, l.hito;

\echo '### 4c · Se confirman las cuatro entregas'
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000a';
update pedidos set estado='entregado' where id='d0000000-0000-0000-0000-00000000000a';
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000b';
update pedidos set estado='entregado' where id='d0000000-0000-0000-0000-00000000000b';
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000c';
update pedidos set estado='entregado' where id='d0000000-0000-0000-0000-00000000000c';
set request.jwt.claim.sub = 'b0000000-0000-0000-0000-00000000000d';
update pedidos set estado='entregado' where id='d0000000-0000-0000-0000-00000000000d';

\echo '### 4d · LA REGLA DE ORO: cada marca cobró su mayorista exacto, sea cual sea su nivel'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select m.nivel_fiabilidad,
       sum(l.monto)                      as cobrado,
       max(p.precio_mayorista)           as mayorista,
       sum(l.monto) = max(p.precio_mayorista) as cuadra,
       count(*)                          as hitos
  from liberaciones_dinero l
  join pedidos_admin p on p.id = l.pedido_id
  join marcas  m on m.id = l.marca_id
 where p.codigo like 'SOC-MAN-_'
 group by m.nivel_fiabilidad
 order by m.nivel_fiabilidad;

\echo '### 4e · A una marca Aliada no se le abre un segundo hito por 0.00'
select count(*) as hitos_de_la_aliada
  from liberaciones_dinero l join pedidos_admin p on p.id = l.pedido_id
 where p.codigo = 'SOC-MAN-D';

\echo '### 4f · Se contaron las entregas de cada marca (para su nivel de fiabilidad)'
select nombre, entregas_ok, nivel_fiabilidad from marcas
 where nombre like 'Marca %' order by nombre;

\echo '### 4g · ...pero ninguna se ascendió sola: promover es decisión de SOCIO'
select count(*) as marcas_que_cambiaron_de_nivel from marcas
 where nombre = 'Marca Nueva' and nivel_fiabilidad <> 'nueva';

\echo ''
\echo '=================== PASO 1 · DESCRIPCIÓN DEL COMPROBANTE ==================='

set role postgres;
insert into productos (id,marca_id,nombre,nombre_comprobante,categoria,estado,activo)
 values ('e0000000-0000-0000-0000-00000000000a','b0000000-0000-0000-0000-00000000000b',
         'GHK-Cu Vial 50 mg','Kit de Optimización Biológica','Cuidado','aprobado',true);
insert into presentaciones (producto_id,nombre,precio_mayorista,precio_publico)
 values ('e0000000-0000-0000-0000-00000000000a','Vial 50 mg',129.67,175.00);
set role authenticated;

\echo '### 1a · El vendedor ve la descripción genérica que debe poner en la boleta'
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000a';
select producto, nombre_comprobante, precio_publico from catalogo_publico
 where producto = 'GHK-Cu Vial 50 mg';

\echo '### 1b · ...y sigue sin ver el precio mayorista por ninguna parte'
select count(*) as columnas_con_mayorista from information_schema.columns
 where table_name = 'catalogo_publico' and column_name like '%mayorista%';

\echo ''
\echo '=================== 4.3 · REPORTE CONTABLE ==================='

\echo '### R1 · Las columnas que pide el manual, más el estado de la liquidación'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select pedido, marca, vendedor, precio_venta, comision_vendedor, comision_plataforma,
       liberado_a_marca, pendiente_a_marca
  from reporte_contable where pedido like 'SOC-MAN-%' order by pedido;

\echo '### R2 · Un pedido entregado no deja nada pendiente con la marca'
select count(*) as entregados_con_saldo_pendiente
  from reporte_contable
 where pedido like 'SOC-MAN-_' and estado = 'entregado' and pendiente_a_marca <> 0;
