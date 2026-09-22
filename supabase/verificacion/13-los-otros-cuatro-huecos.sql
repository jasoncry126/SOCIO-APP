-- Los cuatro huecos que cerró la migración 20260920140000, uno por uno.
-- De cada uno se comprueban las dos caras: que el atajo ya no existe, y que lo
-- que sí era legítimo se sigue pudiendo hacer.

set role postgres;
insert into administradores (id,nombre)
values ('aaaa1111-0000-0000-0000-000000000001','Jason (SOCIO)')
on conflict (id) do nothing;

insert into marcas (id,nombre,ruc,giro,ciudad_almacen,celular,clave_hash,nivel_fiabilidad)
values ('d1000000-0000-0000-0000-00000000000a','Marca Prueba 13','20555555552','ropa','Lima','955500130','x','confiable'),
       ('d1000000-0000-0000-0000-00000000000e','Marca Rival 13','20555555553','ropa','Lima','955500131','x','nueva');
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values ('d1000000-0000-0000-0000-00000000000b','Socio Prueba 13','55500130','955500132','x','Lima');
insert into productos (id,marca_id,nombre,estado,activo)
values ('d1000000-0000-0000-0000-00000000000c','d1000000-0000-0000-0000-00000000000a','Polo de prueba','aprobado',true);
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen,stock_punto)
values ('d1000000-0000-0000-0000-00000000000d','d1000000-0000-0000-0000-00000000000c','Talla M',60.00,150.00,50,50);
reset role;

set role authenticated;

\echo ''
\echo '--- Hueco 3: lo que la marca puede leer del pago del socio ---'

\echo ''
\echo '### 1 · El SOCIO registra un pedido y declara su pago'
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000b';
select pedido_id as pid13, codigo as cod13, precio_socio as psocio13
  from crear_pedido(
    '[{"presentacion_id":"d1000000-0000-0000-0000-00000000000d","cantidad":1}]'::jsonb,
    'Cliente Trece','70000013','970000013','almacen','agencia','Olva Lima','olva',0) \gset
select monto_a_pagar(:'cod13', :psocio13) as esperado13 \gset
select monto_esperado from declarar_pago(:'pid13'::uuid, 'OP-RLS-000013', :esperado13, 'yape');

\echo ''
\echo '### 2 · La MARCA lee la tabla de pagos  (debe: 0 filas)'
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000a';
select count(*) as pagos_que_ve_la_marca from pagos;

\echo ''
\echo '### 3 · Pero sí ve si le pagaron, por su vista  (debe: 1 fila, sin monto)'
select codigo, estado from pagos_marca where codigo = :'cod13';

\echo ''
\echo '### 4 · Esa vista no trae el monto ni el voucher  (debe: FALLAR)'
select monto_esperado from pagos_marca where codigo = :'cod13';

\echo ''
\echo '### 5 · El SOCIO sigue viendo su propio pago entero  (debe: 1 fila con monto)'
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000b';
select numero_operacion, monto_esperado, estado from pagos;

\echo ''
\echo '--- Hueco 4: quién publica un producto ---'

\echo ''
\echo '### 6 · La MARCA crea un producto pidiéndolo ya aprobado  (debe: entrar EN REVISIÓN)'
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000a';
insert into productos (id,marca_id,nombre,estado,activo)
values ('d1000000-0000-0000-0000-0000000000ff','d1000000-0000-0000-0000-00000000000a','Polo colado','aprobado',true);
select nombre, estado, activo from productos where id='d1000000-0000-0000-0000-0000000000ff';

\echo ''
\echo '### 7 · Y lo intenta aprobar ella misma  (debe: FALLAR)'
update productos set estado='aprobado' where id='d1000000-0000-0000-0000-0000000000ff';

\echo ''
\echo '### 8 · Ni por permiso de columna  (debe: FALLAR)'
update productos set estado='aprobado', activo=true
 where id='d1000000-0000-0000-0000-0000000000ff';

\echo ''
\echo '### 9 · Pero sí puede editar su ficha y pausarlo  (debe: pasar)'
update productos set descripcion='Algodón pima', categoria='Polos', activo=false
 where id='d1000000-0000-0000-0000-0000000000ff';
select nombre, categoria, descripcion, estado, activo
  from productos where id='d1000000-0000-0000-0000-0000000000ff';

\echo ''
\echo '### 10 · Y SOCIO sí lo aprueba  (debe: pasar)'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select aprobar_producto('d1000000-0000-0000-0000-0000000000ff', true, 'Revisado');
select nombre, estado, activo from productos where id='d1000000-0000-0000-0000-0000000000ff';

\echo ''
\echo '--- Hueco 5: los retiros ---'

\echo ''
\echo '### 11 · El pedido llega a entregado, para que haya saldo de verdad'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select validar_pago((select id from pagos where numero_operacion='OP-RLS-000013'), true, 'Cruzado');
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000a';
update pedidos set estado='en_camino', numero_guia='G-13', guia_url='guias/prueba/g13.jpg',
       courier='olva', tracking='T-13' where codigo = :'cod13';
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000b';
select confirmar_entrega((select id from pedidos_socio where codigo = :'cod13'));

\echo ''
\echo '### 12 · Saldo de la MARCA (su mayorista: 60.00) y del SOCIO (su ganancia: 15.00)'
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000a';
select saldo_disponible() as saldo_de_la_marca;
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000b';
select saldo_disponible() as saldo_del_socio;

\echo ''
\echo '### 13 · El SOCIO inserta un retiro a mano de S/ 999999  (debe: FALLAR)'
insert into retiros (socio_id, monto) values ('d1000000-0000-0000-0000-00000000000b', 999999);

\echo ''
\echo '### 14 · Y colgándoselo a una marca ajena  (debe: FALLAR)'
insert into retiros (socio_id, marca_id, monto)
values ('d1000000-0000-0000-0000-00000000000b','d1000000-0000-0000-0000-00000000000e', 999999);

\echo ''
\echo '### 15 · Pide por la puerta buena más de lo que tiene  (debe: FALLAR)'
select * from solicitar_retiro(999999);

\echo ''
\echo '### 16 · Pide lo que sí tiene  (debe: pasar, y dejar saldo 5.00)'
select monto, saldo_restante from solicitar_retiro(10.00);

\echo ''
\echo '### 17 · Y ya no puede pedir dos veces lo mismo  (debe: FALLAR)'
select * from solicitar_retiro(10.00);

\echo ''
\echo '### 18 · El retiro quedó a su nombre, sin marca  (debe: 1 fila, marca vacía)'
select monto, estado, marca_id is null as sin_marca from retiros;

\echo ''
\echo '### 19 · La marca ajena no ve nada de eso  (debe: 0)'
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000e';
select count(*) as retiros_que_ve_la_rival from retiros;

\echo ''
\echo '--- Hueco 6: quién firma la bitácora ---'

\echo ''
\echo '### 20 · El SOCIO deja constancia firmando como admin  (debe: FALLAR)'
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000b';
insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo)
values ('pagos','d1000000-0000-0000-0000-00000000000d','pago_validado',
        'aaaa1111-0000-0000-0000-000000000001','admin');

\echo ''
\echo '### 21 · Firmando con su propio id pero diciéndose admin  (debe: FALLAR)'
insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo)
values ('pagos','d1000000-0000-0000-0000-00000000000d','pago_validado',
        'd1000000-0000-0000-0000-00000000000b','admin');

\echo ''
\echo '### 22 · Firmando como la marca  (debe: FALLAR)'
insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo)
values ('pedidos','d1000000-0000-0000-0000-00000000000d','entregado',
        'd1000000-0000-0000-0000-00000000000a','marca');

\echo ''
\echo '### 23 · Firmando como quien es  (debe: pasar)'
insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo)
values ('pedidos','d1000000-0000-0000-0000-00000000000d','nota_del_socio',
        'd1000000-0000-0000-0000-00000000000b','socio');

\echo ''
\echo '### 24 · Y la marca, como marca  (debe: pasar)'
set request.jwt.claim.sub = 'd1000000-0000-0000-0000-00000000000a';
insert into bitacora (tabla, registro_id, accion, actor_id, actor_tipo)
values ('pedidos','d1000000-0000-0000-0000-00000000000d','nota_de_la_marca',
        'd1000000-0000-0000-0000-00000000000a','marca');

\echo ''
\echo '### 25 · Sigue sin poder leerla ni borrarla  (debe: 0 filas, y fallar)'
select count(*) as bitacora_que_ve_la_marca from bitacora;
delete from bitacora;

\echo ''
\echo '### 26 · Las funciones de la plataforma siguen dejando constancia'
set role postgres;
select actor_tipo, accion from bitacora
 where accion in ('creado','pago_declarado','pago_validado','producto_aprobado','retiro_solicitado')
 order by accion;
reset role;
