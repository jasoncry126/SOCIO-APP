\set ON_ERROR_STOP off
\echo '### Datos de prueba'
insert into marcas (id,nombre,ruc,giro,ciudad_almacen,celular,clave_hash)
values ('11111111-1111-1111-1111-111111111111','Marca Demo','20123456789','cosmetica','Lima','987654321','x');
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad,ventas_entregadas)
values ('22222222-2222-2222-2222-222222222222','Socio Demo','12345678','912345678','x','Cusco',9);
insert into productos (id,marca_id,nombre,estado,activo)
values ('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111','Crema','aprobado',true);

\echo ''
\echo '### REGLA: precio_publico > precio_mayorista (debe FALLAR)'
insert into presentaciones (producto_id,nombre,precio_mayorista,precio_publico)
values ('33333333-3333-3333-3333-333333333333','Frasco 50ml',100.00,80.00);

\echo '### La misma con margen positivo (debe PASAR)'
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico)
values ('44444444-4444-4444-4444-444444444444','33333333-3333-3333-3333-333333333333','Frasco 50ml',100.00,150.00);

\echo ''
\echo '### Pedido + pago'
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,comision_socio_app,
  destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,detalle_entrega)
values ('55555555-5555-5555-5555-555555555555','SOC-0825-K4T9','22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',135.00,100.00,15.00,20.00,'Ana Perez','70123456','923456789',
  'almacen','agencia','Olva Cusco centro');
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,comision_socio_app,
  destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,detalle_entrega)
values ('66666666-6666-6666-6666-666666666666','SOC-0825-K5T0','22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',135.00,100.00,15.00,20.00,'Luis Rojas','70123457','923456780',
  'almacen','agencia','Olva Lima centro');

insert into pagos (pedido_id,numero_operacion,monto_esperado,monto_reportado,metodo)
values ('55555555-5555-5555-5555-555555555555','OP-00987654',158.37,158.37,'yape');

\echo ''
\echo '### REGLA: el mismo numero_operacion NO puede pagar otro pedido (debe FALLAR)'
insert into pagos (pedido_id,numero_operacion,monto_esperado,monto_reportado,metodo)
values ('66666666-6666-6666-6666-666666666666','OP-00987654',158.37,158.37,'yape');

\echo ''
\echo '### REGLA: un solo pago por pedido (debe FALLAR)'
insert into pagos (pedido_id,numero_operacion,monto_esperado,monto_reportado,metodo)
values ('55555555-5555-5555-5555-555555555555','OP-99999999',158.37,158.37,'plin');

\echo ''
\echo '### TRIGGER de nivel: socio en 9 ventas / bronce -> pedido entregado'
select nivel, ventas_entregadas from usuarios_socios where id='22222222-2222-2222-2222-222222222222';
update pedidos set estado='entregado' where id='55555555-5555-5555-5555-555555555555';
\echo '--> esperado: 10 ventas, nivel plata'
select nivel, ventas_entregadas from usuarios_socios where id='22222222-2222-2222-2222-222222222222';

\echo ''
\echo '### El trigger no re-cuenta si ya estaba entregado'
update pedidos set estado='entregado' where id='55555555-5555-5555-5555-555555555555';
select nivel, ventas_entregadas from usuarios_socios where id='22222222-2222-2222-2222-222222222222';

\echo ''
\echo '### Hitos de liberacion de dinero (70/30)'
insert into liberaciones_dinero (pedido_id,marca_id,hito,monto) values
 ('55555555-5555-5555-5555-555555555555','11111111-1111-1111-1111-111111111111','guia_registrada',70.00),
 ('55555555-5555-5555-5555-555555555555','11111111-1111-1111-1111-111111111111','entrega_confirmada',30.00);
select hito, monto from liberaciones_dinero order by hito;
