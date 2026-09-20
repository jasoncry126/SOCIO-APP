-- El circuito completo de una venta, con la máquina de estados que pide el
-- informe del contador (sección 3): el cliente paga al vendedor, el vendedor
-- registra el pago, SOCIO lo valida, y la marca solo entonces puede despachar
-- — y únicamente con guía de remisión, courier y tracking.

set role postgres;
insert into administradores (id,nombre) values ('aaaa1111-0000-0000-0000-000000000001','Jason (SOCIO)');

set role authenticated;
\set MARCA '''11111111-1111-1111-1111-111111111111'''
\set SOCIO '''22222222-2222-2222-2222-222222222222'''
\set ADMIN '''aaaa1111-0000-0000-0000-000000000001'''

\echo '### 1. La MARCA se registra desde proveedor.html'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into marcas (id,nombre,ruc,giro,ciudad_almacen,ciudad_punto,celular,clave_hash)
values (:MARCA,'Lab Péptidos Perú','20123456789','Salud','Cusco','Lima','987654321','auth');

\echo '### 2. La MARCA sube un producto con su presentación (entra EN REVISIÓN)'
insert into productos (id,marca_id,nombre,categoria,emoji,descripcion,activo)
values ('33333333-3333-3333-3333-333333333333',:MARCA,'BPC-157','Recuperación','🧪','Reparación de tejidos',true);
select nombre, estado from productos where id='33333333-3333-3333-3333-333333333333';

\echo '### 2b. Y SOCIO lo aprueba: publicar no lo decide la marca'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select aprobar_producto('33333333-3333-3333-3333-333333333333', true, 'Ficha completa');
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen,stock_punto)
values ('44444444-4444-4444-4444-444444444444','33333333-3333-3333-3333-333333333333','Vial 5 mg',122.50,175.00,20,5);

\echo '### 3. El SOCIO se registra y declara su RUC de emisor'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values (:SOCIO,'Socio Demo','12345678','912345678','auth','Cusco');
update usuarios_socios set ruc='10123456781', razon_social='Socio Demo', emite_comprobante=true
 where id = :SOCIO;
select nombre, ruc, emite_comprobante from usuarios_socios;

\echo '### 4. El SOCIO ve el catálogo — y NO el precio mayorista'
select producto, presentacion, precio_publico, stock_almacen from catalogo_publico;

-- El pedido y el pago se siembran como el servidor, con el rol postgres: desde
-- la 7ª migración nadie los inserta a mano, y quien los crea de verdad son
-- crear_pedido() y declarar_pago(), que prueba 11-circuito-de-venta.sql. Aquí
-- son el punto de partida de lo que esta prueba sí mira: la máquina de estados
-- y quién ve qué.
\echo '### 5. El pedido de partida  (estado: pendiente_pago)'
set role postgres;
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,agencia,detalle_entrega)
values ('55555555-5555-5555-5555-555555555555','SOC-0912-A1B2',:SOCIO,:MARCA,
  157.50,122.50,17.50,35.00,'Ana Pérez','70123456','923456789','almacen','agencia','olva','Olva Cusco centro');
insert into pedido_items (pedido_id,presentacion_id,cantidad,precio_unit_socio,precio_unit_mayorista)
values ('55555555-5555-5555-5555-555555555555','44444444-4444-4444-4444-444444444444',1,157.50,122.50);
reset role;
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select codigo, estado from pedidos_socio;

\echo '### 6. Se declara el pago  → el pedido pasa solo a "pagado"'
set role postgres;
insert into pagos (pedido_id,numero_operacion,monto_esperado,monto_reportado,metodo)
values ('55555555-5555-5555-5555-555555555555','OP-00987654',158.37,158.37,'yape');
reset role;
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select codigo, estado from pedidos_socio;

\echo '### 7. La MARCA todavía NO puede despachar: el pago no está validado (debe: fallar)'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update pedidos set estado='en_camino', numero_guia='G-1', courier='olva', tracking='T-1'
 where id='55555555-5555-5555-5555-555555555555';

\echo '### 8. SOCIO cruza el voucher con el estado de cuenta y lo valida'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select validar_pago((select id from pagos), true, 'Cruzado con BCP 13/09');
select codigo, estado from pedidos_admin;

\echo '### 9. La MARCA intenta despachar SIN evidencia  (debe: fallar)'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update pedidos set estado='en_camino' where id='55555555-5555-5555-5555-555555555555';

\echo '### 10. La MARCA despacha CON guía, foto, courier y tracking  (debe: pasar)'
update pedidos set estado='en_camino', numero_guia='T001-0004512', courier='olva', tracking='OLVA-99123',
       guia_url='guias/prueba/guia.jpg'
 where id='55555555-5555-5555-5555-555555555555';
select codigo, estado, numero_guia, courier, tracking, despachado_en is not null as fecha_puesta
  from pedidos_marca;

\echo '### 11. El SOCIO registra la boleta que le emitió al cliente'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select registrar_comprobante('55555555-5555-5555-5555-555555555555','boleta','B001','0000123');
select codigo, comprobante_tipo, comprobante_serie, comprobante_numero from pedidos_socio;

\echo '### 12. La MARCA confirma la entrega (dispara el trigger de nivel)'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update pedidos set estado='entregado' where id='55555555-5555-5555-5555-555555555555';

\echo '### 13. El SOCIO: ¿le subió el contador de ventas entregadas?'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select nombre, nivel, ventas_entregadas from usuarios_socios;

\echo '### 14. Un pedido entregado ya no se puede reabrir  (debe: fallar)'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update pedidos set estado='en_camino' where id='55555555-5555-5555-5555-555555555555';

\echo '### 15. La marca deja constancia en la bitácora'
insert into bitacora (tabla,registro_id,accion,actor_id,actor_tipo)
values ('pedidos','55555555-5555-5555-5555-555555555555','entregado',:MARCA,'marca');
