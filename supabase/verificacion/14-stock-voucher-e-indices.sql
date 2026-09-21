-- Los tres arreglos de la migración 20260921120000:
--
--   1 · el stock se descuenta al registrar el pedido, y vuelve si se cancela
--       (salvo que ya hubiera salido del almacén);
--   2 · la misma foto de voucher no paga dos pedidos;
--   3 · las claves foráneas por las que se consulta tienen índice.
--
-- Como en el resto de la suite, los bloques marcados "(debe: FALLAR)" tienen
-- que dar error: ahí el error es el resultado correcto.

set role postgres;
insert into administradores (id,nombre)
values ('aaaa1111-0000-0000-0000-000000000001','Jason (SOCIO)')
on conflict (id) do nothing;

insert into marcas (id,nombre,ruc,giro,ciudad_almacen,ciudad_punto,celular,clave_hash,nivel_fiabilidad)
values ('e2000000-0000-0000-0000-00000000000a','Marca Prueba 14','20555555554','alimentos','Trujillo','Trujillo','955500140','x','confiable');
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values ('e2000000-0000-0000-0000-00000000000b','Socio Prueba 14','55500140','955500141','x','Trujillo');
insert into productos (id,marca_id,nombre,estado,activo)
values ('e2000000-0000-0000-0000-00000000000c','e2000000-0000-0000-0000-00000000000a','Miel de prueba','aprobado',true);

-- La escasa, para ver el stock moverse unidad por unidad.
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen,stock_punto)
values ('e2000000-0000-0000-0000-00000000000d','e2000000-0000-0000-0000-00000000000c','Frasco 500 g',60.00,150.00,3,2);

-- La abundante, para las pruebas del voucher, que necesitan varios pedidos.
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen,stock_punto)
values ('e2000000-0000-0000-0000-00000000000f','e2000000-0000-0000-0000-00000000000c','Frasco 1 kg',80.00,200.00,50,50);
reset role;

set role authenticated;

\echo ''
\echo '--- 1 · El stock se reserva al registrar el pedido ---'

\echo ''
\echo '### 1 · Stock de partida  (debe: 3 en almacén, 2 en punto de venta)'
set role postgres;
select stock_almacen, stock_punto from presentaciones
 where id = 'e2000000-0000-0000-0000-00000000000d';
reset role;
set role authenticated;

\echo ''
\echo '### 2 · El SOCIO vende 2 desde almacén  (debe: pasar)'
set request.jwt.claim.sub = 'e2000000-0000-0000-0000-00000000000b';
select pedido_id as pid_a, codigo as cod_a
  from crear_pedido(
    '[{"presentacion_id":"e2000000-0000-0000-0000-00000000000d","cantidad":2}]'::jsonb,
    'Cliente Catorce','70000014','970000014','almacen','agencia','Olva Trujillo','olva',0) \gset

\echo ''
\echo '### 3 · Y el almacén ya tiene 2 menos  (debe: 1 en almacén)'
set role postgres;
select stock_almacen from presentaciones
 where id = 'e2000000-0000-0000-0000-00000000000d';
reset role;
set role authenticated;
set request.jwt.claim.sub = 'e2000000-0000-0000-0000-00000000000b';

\echo ''
\echo '### 4 · Pide 2 más de las que quedan  (debe: FALLAR — quedan 1)'
select codigo from crear_pedido(
    '[{"presentacion_id":"e2000000-0000-0000-0000-00000000000d","cantidad":2}]'::jsonb,
    'Cliente Catorce','70000014','970000014','almacen','agencia','Olva Trujillo','olva',0);

\echo ''
\echo '### 5 · El punto de venta no se tocó  (debe: 2 — se descuenta la columna del origen)'
set role postgres;
select stock_punto from presentaciones
 where id = 'e2000000-0000-0000-0000-00000000000d';
reset role;
set role authenticated;
set request.jwt.claim.sub = 'e2000000-0000-0000-0000-00000000000b';

\echo ''
\echo '### 6 · Vende 1 desde el punto de venta  (debe: pasar, y dejar 1)'
select pedido_id as pid_b, codigo as cod_b
  from crear_pedido(
    '[{"presentacion_id":"e2000000-0000-0000-0000-00000000000d","cantidad":1}]'::jsonb,
    'Cliente Catorce','70000014','970000014','punto_venta','domicilio','Av. España 123',null,0) \gset
set role postgres;
select stock_almacen, stock_punto from presentaciones
 where id = 'e2000000-0000-0000-0000-00000000000d';
reset role;
set role authenticated;

\echo ''
\echo '--- 2 · Cancelar devuelve la mercadería, salvo que ya haya salido ---'

\echo ''
\echo '### 7 · La MARCA cancela el pedido de 2  → vuelven al almacén  (debe: 3)'
set request.jwt.claim.sub = 'e2000000-0000-0000-0000-00000000000a';
update pedidos set estado = 'cancelado' where codigo = :'cod_a';
set role postgres;
select stock_almacen from presentaciones
 where id = 'e2000000-0000-0000-0000-00000000000d';
reset role;
set role authenticated;

\echo ''
\echo '### 8 · Un pedido nuevo, llevado hasta despachado por el camino legítimo'
set request.jwt.claim.sub = 'e2000000-0000-0000-0000-00000000000b';
select pedido_id as pid_c, codigo as cod_c, precio_socio as psocio_c
  from crear_pedido(
    '[{"presentacion_id":"e2000000-0000-0000-0000-00000000000d","cantidad":1}]'::jsonb,
    'Cliente Catorce','70000014','970000014','almacen','agencia','Olva Trujillo','olva',0) \gset
select monto_a_pagar(:'cod_c', :psocio_c) as monto_c \gset
select monto_esperado from declarar_pago(:'pid_c'::uuid, 'OP-STK-000001', :monto_c, 'yape', null, 'FOTO-C');
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select validar_pago((select id from pagos where numero_operacion='OP-STK-000001'), true, 'Cruzado con BCP');
set request.jwt.claim.sub = 'e2000000-0000-0000-0000-00000000000a';
update pedidos set estado='en_camino', numero_guia='G-14', guia_url='guias/prueba/g14.jpg',
       courier='olva', tracking='T-14' where codigo = :'cod_c';
select codigo, estado from pedidos_marca where codigo = :'cod_c';

\echo ''
\echo '### 9 · Cancelarlo ya despachado NO devuelve el stock  (debe: seguir en 2)'
update pedidos set estado='cancelado' where codigo = :'cod_c';
set role postgres;
select stock_almacen from presentaciones
 where id = 'e2000000-0000-0000-0000-00000000000d';
reset role;
set role authenticated;

\echo ''
\echo '--- 3 · La misma foto de voucher no paga dos pedidos ---'

\echo ''
\echo '### 10 · Dos pedidos nuevos, los dos pendientes de pago'
set request.jwt.claim.sub = 'e2000000-0000-0000-0000-00000000000b';
select pedido_id as pid_d, codigo as cod_d, precio_socio as psocio_d
  from crear_pedido(
    '[{"presentacion_id":"e2000000-0000-0000-0000-00000000000f","cantidad":1}]'::jsonb,
    'Cliente Catorce','70000014','970000014','almacen','agencia','Olva Trujillo','olva',0) \gset
select pedido_id as pid_e, codigo as cod_e, precio_socio as psocio_e
  from crear_pedido(
    '[{"presentacion_id":"e2000000-0000-0000-0000-00000000000f","cantidad":1}]'::jsonb,
    'Cliente Catorce','70000014','970000014','almacen','agencia','Olva Trujillo','olva',0) \gset
select monto_a_pagar(:'cod_d', :psocio_d) as monto_d \gset
select monto_a_pagar(:'cod_e', :psocio_e) as monto_e \gset

\echo ''
\echo '### 11 · El primero declara su pago con su foto  (debe: pasar)'
select pago_id is not null as declarado
  from declarar_pago(:'pid_d'::uuid, 'OP-VOU-000001', :monto_d, 'yape', null, 'FOTO-REUSADA');

\echo ''
\echo '### 12 · El segundo adjunta LA MISMA foto con otro número  (debe: FALLAR)'
select pago_id is not null as declarado
  from declarar_pago(:'pid_e'::uuid, 'OP-VOU-000002', :monto_e, 'yape', null, 'FOTO-REUSADA');

\echo ''
\echo '### 13 · Con su propia foto sí entra  (debe: pasar)'
select pago_id is not null as declarado
  from declarar_pago(:'pid_e'::uuid, 'OP-VOU-000003', :monto_e, 'yape', null, 'FOTO-PROPIA');

\echo ''
\echo '### 14 · Sin foto, varios pagos conviven  (debe: pasar los dos)'
select pedido_id as pid_f, codigo as cod_f, precio_socio as psocio_f
  from crear_pedido(
    '[{"presentacion_id":"e2000000-0000-0000-0000-00000000000f","cantidad":1}]'::jsonb,
    'Cliente Catorce','70000014','970000014','almacen','agencia','Olva Trujillo','olva',0) \gset
select pedido_id as pid_g, codigo as cod_g, precio_socio as psocio_g
  from crear_pedido(
    '[{"presentacion_id":"e2000000-0000-0000-0000-00000000000f","cantidad":1}]'::jsonb,
    'Cliente Catorce','70000014','970000014','almacen','agencia','Olva Trujillo','olva',0) \gset
select monto_a_pagar(:'cod_f', :psocio_f) as monto_f \gset
select monto_a_pagar(:'cod_g', :psocio_g) as monto_g \gset
select pago_id is not null as sin_foto_1 from declarar_pago(:'pid_f'::uuid, 'OP-VOU-000004', :monto_f, 'plin');
select pago_id is not null as sin_foto_2 from declarar_pago(:'pid_g'::uuid, 'OP-VOU-000005', :monto_g, 'plin');

\echo ''
\echo '--- 4 · Los índices ---'

\echo ''
\echo '### 15 · Las claves foráneas por las que se consulta tienen índice  (debe: 15)'
reset role;
select count(*) as indices_nuevos
  from pg_indexes
 where schemaname = 'public'
   and (indexname like 'idx_%' or indexname = 'pagos_hash_imagen_unico');

\echo ''
\echo '### 16 · Y ninguna de estas tablas se recorre entera por su clave foránea'
select tablename, indexname from pg_indexes
 where schemaname = 'public' and indexname like 'idx_%'
 order by tablename, indexname;
