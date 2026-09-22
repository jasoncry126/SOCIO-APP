-- Los dos huecos que cerró la migración 20260920_quien_mueve_el_pedido,
-- uno por uno:
--
--   1 · una marca podía recorrer sola la máquina de estados y cobrar su
--       liquidación sin que existiera ningún pago ni ninguna validación;
--   2 · el socio podía leer el monto de las liquidaciones de sus pedidos, y
--       con eso deducir el precio mayorista de la marca y la comisión de SOCIO.
--
-- Se comprueban las dos cosas: que el atajo ya no existe, y que el camino
-- legítimo sigue funcionando de punta a punta.

set role postgres;
insert into administradores (id,nombre)
values ('aaaa1111-0000-0000-0000-000000000001','Jason (SOCIO)')
on conflict (id) do nothing;

insert into marcas (id,nombre,ruc,giro,ciudad_almacen,celular,clave_hash,nivel_fiabilidad)
values ('c0000000-0000-0000-0000-00000000000a','Marca Prueba 12','20555555551','cosmetica','Cusco','955500012','x','confiable');
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values ('c0000000-0000-0000-0000-00000000000b','Socio Prueba 12','55500012','955500013','x','Cusco');
insert into productos (id,marca_id,nombre,estado,activo)
values ('c0000000-0000-0000-0000-00000000000c','c0000000-0000-0000-0000-00000000000a','Crema de prueba','aprobado',true);
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen,stock_punto)
values ('c0000000-0000-0000-0000-00000000000d','c0000000-0000-0000-0000-00000000000c','Frasco 50 ml',100.00,200.00,50,50);
reset role;

\set MARCA '''c0000000-0000-0000-0000-00000000000a'''
\set SOCIO '''c0000000-0000-0000-0000-00000000000b'''
\set ADMIN '''aaaa1111-0000-0000-0000-000000000001'''

set role authenticated;

\echo ''
\echo '### 1 · El SOCIO registra su pedido (mayorista real: S/ 100.00)'
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000b';
select pedido_id as pid, codigo as cod, precio_socio, ganancia_socio
  from crear_pedido(
    '[{"presentacion_id":"c0000000-0000-0000-0000-00000000000d","cantidad":1}]'::jsonb,
    'Cliente Final','70000012','970000012','almacen','agencia','Olva Cusco','olva',0) \gset
select codigo, estado from pedidos_socio where codigo = :'cod';

\echo ''
\echo '### 2 · La MARCA se da por pagada sola  (debe: FALLAR — no hay pago declarado)'
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000a';
update pedidos set estado='pagado' where codigo = :'cod';

\echo ''
\echo '### 3 · La MARCA salta directo a validado  (debe: FALLAR — no es el orden)'
update pedidos set estado='validado' where codigo = :'cod';

\echo ''
\echo '### 4 · El SOCIO declara su pago  → el pedido pasa solo a "pagado"'
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000b';
select monto_a_pagar(:'cod', 180.00) as esperado \gset
select pago_id is not null as pago_declarado, monto_esperado, cuadra
  from declarar_pago(:'pid'::uuid, 'OP-RLS-000012', :esperado, 'yape');
select codigo, estado from pedidos_socio where codigo = :'cod';

\echo ''
\echo '### 5 · La MARCA se valida el pago ella misma  (debe: FALLAR — es el hueco)'
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000a';
update pedidos set estado='validado' where codigo = :'cod';

\echo ''
\echo '### 6 · La MARCA despacha sin que nadie validara  (debe: FALLAR — no es el orden)'
update pedidos set estado='en_camino', numero_guia='G-12', guia_url='guias/prueba/g.jpg',
       courier='olva', tracking='T-12' where codigo = :'cod';

\echo ''
\echo '### 7 · Hasta aquí la marca NO ha cobrado nada  (debe: 0)'
set role postgres;
select count(*) as liquidaciones from liberaciones_dinero l
  join pedidos p on p.id = l.pedido_id where p.codigo = :'cod';
reset role;
set role authenticated;

\echo ''
\echo '### 8 · SOCIO cruza el voucher con el estado de cuenta y valida  (debe: pasar)'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select validar_pago((select id from pagos where numero_operacion='OP-RLS-000012'), true, 'Cruzado con BCP 20/09');
select codigo, estado from pedidos_admin where codigo = :'cod';

\echo ''
\echo '### 9 · Ahora SÍ la marca despacha, y el socio confirma la entrega  (debe: pasar)'
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000a';
update pedidos set estado='en_camino', numero_guia='G-12', guia_url='guias/prueba/g.jpg',
       courier='olva', tracking='T-12' where codigo = :'cod';
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000b';
select confirmar_entrega((select id from pedidos_socio where codigo = :'cod'));
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000a';
select codigo, estado from pedidos_marca where codigo = :'cod';

\echo ''
\echo '### 10 · Y cobra su mayorista íntegro, esta vez con un pago validado detrás'
set role postgres;
select l.hito, l.monto from liberaciones_dinero l
  join pedidos p on p.id = l.pedido_id where p.codigo = :'cod' order by l.liberado_en;
reset role;
set role authenticated;

\echo ''
\echo '--- Hueco 2: lo que el socio puede leer del dinero de la marca ---'

\echo ''
\echo '### 11 · El SOCIO lee los montos de la liquidación  (debe: 0 filas)'
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000b';
select count(*) as montos_visibles from liberaciones_dinero;

\echo ''
\echo '### 12 · Pero sigue sabiendo si su pedido se liquidó, y cuándo  (debe: 2 hitos)'
select codigo, hito, liberado_en is not null as con_fecha
  from liquidaciones_socio where codigo = :'cod' order by hito;

\echo ''
\echo '### 13 · La vista del socio no tiene columna de monto  (debe: FALLAR)'
select monto from liquidaciones_socio where codigo = :'cod';

\echo ''
\echo '### 14 · SOCIO (el administrador) sí ve los montos  (debe: 2 filas)'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select hito, monto from liberaciones_dinero l
  join pedidos p on p.id = l.pedido_id where p.codigo = :'cod' order by l.liberado_en;

\echo ''
\echo '### 15 · La MARCA sigue viendo su propio dinero liberado  (debe: 2 filas)'
set request.jwt.claim.sub = 'c0000000-0000-0000-0000-00000000000a';
select hito, monto from liberaciones_dinero l
  join pedidos p on p.id = l.pedido_id where p.codigo = :'cod' order by l.liberado_en;

reset role;
