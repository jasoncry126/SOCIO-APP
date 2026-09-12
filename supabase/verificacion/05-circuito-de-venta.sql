set role authenticated;
\set MARCA '''11111111-1111-1111-1111-111111111111'''
\set SOCIO '''22222222-2222-2222-2222-222222222222'''

\echo '### 1. La MARCA se registra desde proveedor.html'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into marcas (id,nombre,ruc,giro,ciudad_almacen,ciudad_punto,celular,clave_hash)
values (:MARCA,'Lab Péptidos Perú','20123456789','Salud','Cusco','Lima','987654321','auth');

\echo '### 2. La MARCA sube un producto con su presentación'
insert into productos (id,marca_id,nombre,categoria,emoji,descripcion,estado,activo)
values ('33333333-3333-3333-3333-333333333333',:MARCA,'BPC-157','Recuperación','🧪','Reparación de tejidos','aprobado',true);
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen,stock_punto)
values ('44444444-4444-4444-4444-444444444444','33333333-3333-3333-3333-333333333333','Vial 5 mg',122.50,175.00,20,5);

\echo '### 3. El SOCIO se registra desde vendedor.html'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values (:SOCIO,'Socio Demo','12345678','912345678','auth','Cusco');

\echo '### 4. El SOCIO ve el catálogo — y NO el precio mayorista'
select producto, presentacion, precio_publico, stock_almacen from catalogo_publico;

\echo '### 5. El SOCIO registra el pedido'
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,agencia,detalle_entrega)
values ('55555555-5555-5555-5555-555555555555','SOC-0912-A1B2',:SOCIO,:MARCA,
  157.50,122.50,17.50,35.00,'Ana Pérez','70123456','923456789','almacen','agencia','olva','Olva Cusco centro');
insert into pedido_items (pedido_id,presentacion_id,cantidad,precio_unit_socio,precio_unit_mayorista)
values ('55555555-5555-5555-5555-555555555555','44444444-4444-4444-4444-444444444444',1,157.50,122.50);

\echo '### 6. El SOCIO declara su pago con el número de operación'
insert into pagos (pedido_id,numero_operacion,monto_esperado,monto_reportado,metodo)
values ('55555555-5555-5555-5555-555555555555','OP-00987654',158.37,158.37,'yape');

\echo '### 7. La MARCA ve el pedido y que está pagado, y despacha'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select codigo, estado, destinatario from pedidos;
select numero_operacion, estado from pagos;
update pedidos set estado='en_camino', numero_guia='OLVA-99123', despachado_en=now()
 where id='55555555-5555-5555-5555-555555555555';

\echo '### 8. La MARCA confirma la entrega (dispara el trigger de nivel)'
update pedidos set estado='entregado', entregado_en=now()
 where id='55555555-5555-5555-5555-555555555555';

\echo '### 9. El SOCIO: ¿le subió el contador de ventas entregadas?'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select nombre, nivel, ventas_entregadas from usuarios_socios;

\echo '### 10. La marca deja constancia en la bitácora'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into bitacora (tabla,registro_id,accion,actor_id,actor_tipo)
values ('pedidos','55555555-5555-5555-5555-555555555555','entregado',:MARCA,'marca');
