-- El circuito del depósito, de punta a punta:
--
--   1 · el socio registra su pedido y la base le dice el monto exacto;
--   2 · deposita por fuera y declara el pago con su captura;
--   3 · SOCIO lo ve en la cola de validación, con la captura y el número de
--       operación, y nadie más la ve;
--   4 · si lo rechaza, el pedido vuelve al socio con el motivo y él puede
--       declarar otra vez; si lo valida, el pedido queda listo para despacho;
--   5 · un pedido registrado y nunca pagado se puede cancelar, y la
--       mercadería vuelve al catálogo.
--
-- Como en el resto de la suite, los bloques marcados "(debe: FALLAR)" tienen
-- que dar error: ahí el error es el resultado correcto.

set role postgres;
insert into administradores (id,nombre)
values ('aaaa1111-0000-0000-0000-000000000001','Jason (SOCIO)')
on conflict (id) do nothing;

insert into marcas (id,nombre,ruc,giro,ciudad_almacen,ciudad_punto,celular,clave_hash,nivel_fiabilidad)
values ('e3000000-0000-0000-0000-00000000000a','Marca Prueba 15','20555555559','cosmetica','Arequipa','Arequipa','955500160','x','confiable');
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values ('e3000000-0000-0000-0000-00000000000b','Socio Prueba 15','55500160','955500161','x','Arequipa');
-- Un segundo socio, para comprobar que no ve la cola de validación ni los
-- pedidos ajenos.
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values ('e3000000-0000-0000-0000-00000000000e','Socio Ajeno 15','55500162','955500163','x','Lima');
insert into productos (id,marca_id,nombre,estado,activo)
values ('e3000000-0000-0000-0000-00000000000c','e3000000-0000-0000-0000-00000000000a','Sérum de prueba','aprobado',true);
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen,stock_punto)
values ('e3000000-0000-0000-0000-00000000000d','e3000000-0000-0000-0000-00000000000c','Frasco 30 ml',40.00,100.00,20,20);
reset role;

set role authenticated;

\echo ''
\echo '--- 1 · El socio registra y la base le dice cuánto depositar ---'

\echo ''
\echo '### 1 · Registra su pedido  (debe: pasar, y quedar pendiente de pago)'
set request.jwt.claim.sub = 'e3000000-0000-0000-0000-00000000000b';
select pedido_id as pid_a, codigo as cod_a
  from crear_pedido(
    '[{"presentacion_id":"e3000000-0000-0000-0000-00000000000d","cantidad":2}]'::jsonb,
    'Cliente Quince','70000016','970000016','almacen','agencia','Shalom Arequipa','shalom',12.00) \gset

\echo ''
\echo '### 2 · Su pedido le dice el monto con céntimos y que aún no hay pago'
\echo '        (debe: estado pendiente_pago, monto_a_pagar con céntimos, pago_estado vacío)'
select estado, monto_a_pagar, pago_estado is null as sin_pago_todavia
  from pedidos_socio where codigo = :'cod_a';

\echo ''
\echo '### 3 · Y el monto coincide con lo que calcula monto_a_pagar()  (debe: t)'
select monto_a_pagar = monto_a_pagar(codigo, round(precio_socio + costo_envio, 2)) as coincide
  from pedidos_socio where codigo = :'cod_a';

\echo ''
\echo '--- 2 · Declara su depósito con la captura ---'

select monto_a_pagar as monto_a from pedidos_socio where codigo = :'cod_a' \gset

\echo ''
\echo '### 4 · Declara el pago con su captura  (debe: pasar y cuadrar)'
select monto_esperado, cuadra
  from declarar_pago(:'pid_a'::uuid, 'OP-DEP-000001', :monto_a, 'transferencia',
                     'e3000000-0000-0000-0000-00000000000b/PRUEBA-A.jpg', 'HUELLA-A');

\echo ''
\echo '### 5 · El pedido avanzó solo a "pagado"  (debe: pagado / pendiente)'
select estado, pago_estado from pedidos_socio where codigo = :'cod_a';

\echo ''
\echo '### 6 · Otro pedido con LA MISMA captura  (debe: FALLAR)'
select pedido_id as pid_b, codigo as cod_b
  from crear_pedido(
    '[{"presentacion_id":"e3000000-0000-0000-0000-00000000000d","cantidad":1}]'::jsonb,
    'Cliente Quince','70000016','970000016','almacen','agencia','Shalom Arequipa','shalom',0) \gset
select monto_a_pagar as monto_b from pedidos_socio where codigo = :'cod_b' \gset
select pago_id is not null from declarar_pago(:'pid_b'::uuid, 'OP-DEP-000002', :monto_b,
                                              'yape', null, 'HUELLA-A');

\echo ''
\echo '--- 3 · La cola de validación es solo de SOCIO ---'

\echo ''
\echo '### 7 · El socio dueño del pedido NO ve la cola  (debe: 0 filas)'
select count(*) as filas_para_el_socio from cola_de_validacion;

\echo ''
\echo '### 8 · Otro socio tampoco ve nada suyo ni ajeno  (debe: 0 y 0)'
set request.jwt.claim.sub = 'e3000000-0000-0000-0000-00000000000e';
select (select count(*) from cola_de_validacion) as cola,
       (select count(*) from pedidos_socio)      as pedidos_ajenos;

\echo ''
\echo '### 9 · SOCIO sí la ve, con todo lo que necesita para cruzar'
\echo '        (debe: 1 fila, con captura, operación y si cuadra)'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select pedido, socio, marca, numero_operacion, cuadra, captura, pago_estado
  from cola_de_validacion where pedido = :'cod_a';

\echo ''
\echo '--- 4 · Rechazar devuelve el pedido al socio; validar lo libera ---'

\echo ''
\echo '### 10 · Rechazar sin decir por qué  (debe: FALLAR)'
select validar_pago((select pago_id from cola_de_validacion where pedido = :'cod_a'), false, null);

\echo ''
\echo '### 11 · Rechazar con motivo  (debe: pasar)'
select validar_pago((select pago_id from cola_de_validacion where pedido = :'cod_a'),
                    false, 'El abono no aparece en la cuenta');

\echo ''
\echo '### 12 · El socio lo ve rechazado, con el motivo, y otra vez pendiente de pago'
\echo '         (debe: pendiente_pago / rechazado / el motivo)'
set request.jwt.claim.sub = 'e3000000-0000-0000-0000-00000000000b';
select estado, pago_estado, pago_motivo from pedidos_socio where codigo = :'cod_a';

\echo ''
\echo '### 13 · Y puede declarar otra vez, con otra captura  (debe: pasar)'
select monto_esperado, cuadra
  from declarar_pago(:'pid_a'::uuid, 'OP-DEP-000003', :monto_a, 'yape',
                     'e3000000-0000-0000-0000-00000000000b/PRUEBA-A2.jpg', 'HUELLA-A2');

\echo ''
\echo '### 14 · El pedido volvió a "pagado" y el pago a "pendiente"  (debe: pagado / pendiente)'
select estado, pago_estado, pago_motivo is null as sin_motivo
  from pedidos_socio where codigo = :'cod_a';

\echo ''
\echo '### 15 · SOCIO lo valida  (debe: pasar, y dejar el pedido en "validado")'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select validar_pago((select pago_id from cola_de_validacion where pedido = :'cod_a'),
                    true, 'Cruzado con el extracto del BCP');
select codigo, estado from pedidos_admin where codigo = :'cod_a';

\echo ''
\echo '### 16 · Y el socio lo ve validado  (debe: validado / validado)'
set request.jwt.claim.sub = 'e3000000-0000-0000-0000-00000000000b';
select estado, pago_estado from pedidos_socio where codigo = :'cod_a';

\echo ''
\echo '--- 5 · La marca no puede desandar un pago bueno ---'

\echo ''
\echo '### 17 · Un pedido nuevo, pagado y sin resolver'
select pedido_id as pid_c, codigo as cod_c
  from crear_pedido(
    '[{"presentacion_id":"e3000000-0000-0000-0000-00000000000d","cantidad":1}]'::jsonb,
    'Cliente Quince','70000016','970000016','almacen','agencia','Shalom Arequipa','shalom',0) \gset
select monto_a_pagar as monto_c from pedidos_socio where codigo = :'cod_c' \gset
select pago_id is not null as declarado
  from declarar_pago(:'pid_c'::uuid, 'OP-DEP-000004', :monto_c, 'plin', null, 'HUELLA-C');

\echo ''
\echo '### 18 · La MARCA intenta devolverlo a pendiente de pago  (debe: FALLAR)'
set request.jwt.claim.sub = 'e3000000-0000-0000-0000-00000000000a';
update pedidos set estado = 'pendiente_pago' where codigo = :'cod_c';

\echo ''
\echo '### 19 · Y tampoco puede saltarse la validación de SOCIO  (debe: FALLAR)'
update pedidos set estado = 'en_camino', numero_guia='G-15', courier='shalom', tracking='T-15'
 where codigo = :'cod_c';

\echo ''
\echo '--- 6 · Un pedido que nunca se pagó se puede cancelar ---'

\echo ''
\echo '### 20 · Stock antes de cancelar  (debe: 20 − 2 − 1 − 1 = 16)'
set role postgres;
select stock_almacen from presentaciones where id = 'e3000000-0000-0000-0000-00000000000d';
reset role;
set role authenticated;

\echo ''
\echo '### 21 · El socio cancela el pedido que dejó sin pagar  (debe: pasar)'
set request.jwt.claim.sub = 'e3000000-0000-0000-0000-00000000000b';
select cancelar_pedido_sin_pagar(:'pid_b'::uuid);

\echo ''
\echo '### 22 · La mercadería volvió al catálogo  (debe: 17)'
set role postgres;
select stock_almacen from presentaciones where id = 'e3000000-0000-0000-0000-00000000000d';
reset role;
set role authenticated;
set request.jwt.claim.sub = 'e3000000-0000-0000-0000-00000000000b';

\echo ''
\echo '### 23 · Cancelar uno que ya está pagado  (debe: FALLAR)'
select cancelar_pedido_sin_pagar(:'pid_c'::uuid);

\echo ''
\echo '### 24 · Cancelar un pedido ajeno  (debe: FALLAR)'
set request.jwt.claim.sub = 'e3000000-0000-0000-0000-00000000000e';
select cancelar_pedido_sin_pagar(:'pid_a'::uuid);

\echo ''
\echo '--- 7 · Lo que el socio NO ve de su propio pago ---'

\echo ''
\echo '### 25 · Su vista no trae quién validó ni cuándo  (debe: 0 columnas)'
reset role;
select count(*) as columnas_de_mas
  from information_schema.columns
 where table_name = 'pedidos_socio'
   and column_name in ('validado_por','validado_en','hash_imagen',
                       'precio_mayorista','comision_socio_app');

\echo ''
\echo '### 26 · Y la cola de validación no la puede leer nadie sin cuenta  (debe: FALLAR)'
set role anon;
select count(*) from cola_de_validacion;
reset role;
