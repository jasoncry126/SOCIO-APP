-- Acceso de administración: qué puede hacer SOCIO y qué NO puede hacer nadie más.
-- Se ejecuta con ejecutar-local.sh.

-- Datos: un admin, una marca, un socio, un producto en revisión, un pedido con pago
insert into administradores (id,nombre) values ('aaaa1111-0000-0000-0000-000000000001','Jason (SOCIO)');
insert into marcas (id,nombre,ruc,giro,ciudad_almacen,celular,clave_hash)
 values ('11111111-1111-1111-1111-111111111111','Lab Péptidos','20123456789','Salud','Cusco','987654321','auth');
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
 values ('22222222-2222-2222-2222-222222222222','Socio Demo','12345678','912345678','auth','Cusco');
insert into productos (id,marca_id,nombre,categoria,estado,activo)
 values ('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111','BPC-157','Recuperación','revision',false);
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico)
 values ('44444444-4444-4444-4444-444444444444','33333333-3333-3333-3333-333333333333','Vial 5 mg',122.50,175);
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,comision_socio_app,
  destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,detalle_entrega)
 values ('55555555-5555-5555-5555-555555555555','SOC-0913-A1B2','22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',157.50,122.50,17.50,35,'Ana Pérez','70123456','923456789','almacen','agencia','Olva Cusco');
insert into pagos (id,pedido_id,numero_operacion,monto_esperado,monto_reportado,metodo)
 values ('66666666-6666-6666-6666-666666666666','55555555-5555-5555-5555-555555555555','OP-00987654',158.37,158.37,'yape');

set role authenticated;

\echo '### UN SOCIO CUALQUIERA intenta hacer de administrador'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
\echo '-- ¿es_admin() lo reconoce? (debe: f)'
select es_admin();
\echo '-- ¿puede validar su propio pago? (debe: fallar)'
select validar_pago('66666666-6666-6666-6666-666666666666', true);
set role authenticated;
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';   -- Jason, admin

\echo '### 1 · ¿es_admin() lo reconoce?  (debe: t)'
select es_admin();

\echo ''
\echo '### 2 · ¿ve TODO lo que necesita para arbitrar?'
select (select count(*) from usuarios_socios) socios,
       (select count(*) from marcas) marcas,
       (select count(*) from productos) productos,
       (select count(*) from pedidos) pedidos,
       (select count(*) from pagos) pagos;

\echo ''
\echo '### 3 · Valida el pago tras cruzarlo con el estado de cuenta'
select validar_pago('66666666-6666-6666-6666-666666666666', true, 'Cruzado con BCP 13/09');
select p.estado as pago, pe.estado as pedido
  from pagos p join pedidos pe on pe.id = p.pedido_id;

\echo ''
\echo '### 4 · ¿Se puede validar dos veces el mismo pago? (debe: fallar)'
select validar_pago('66666666-6666-6666-6666-666666666666', true);
set role authenticated;
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';

\echo '### 5 · Aprueba el producto que la marca envió a revisión'
select aprobar_producto('33333333-3333-3333-3333-333333333333', true);
select nombre, estado, activo from productos;

\echo ''
\echo '### 6 · Valida la identidad del socio'
select validar_socio('22222222-2222-2222-2222-222222222222', true);
select nombre, validado from usuarios_socios;

\echo ''
\echo '### 7 · La bitácora registró quién hizo qué'
select tabla, accion, actor_tipo, detalle from bitacora order by id;

\echo ''
\echo '### 8 · ¿El socio ya ve el producto aprobado en el catálogo público?'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select producto, presentacion, precio_publico from catalogo_publico;

\echo ''
\echo '### 9 · ¿El socio puede leer la bitácora? (debe: 0)'
select count(*) from bitacora;

\echo ''
\echo '### 10 · ¿El socio puede aprobarse productos? (debe: fallar)'
select aprobar_producto('33333333-3333-3333-3333-333333333333', true);
