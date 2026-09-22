-- El último tramo del recorrido, el que antes no existía:
--
--   1 · SOCIO valida el pago y el pedido queda listo para despacho;
--   2 · la marca lo despacha con su guía, su foto y su tracking;
--   3 · EL SOCIO confirma que llegó — la marca ya no puede, porque ese mismo
--       paso le libera el resto de su dinero;
--   4 · con la entrega confirmada se suelta el 2º hito, sube la venta
--       entregada del socio y aparece su saldo para retirar.
--
-- Y la revisión trimestral de niveles: quien deja de vender pierde un escalón,
-- uno solo, y lo recupera cuando vuelve al ritmo.
--
-- Como en el resto de la suite, los bloques marcados "(debe: FALLAR)" tienen
-- que dar error: ahí el error es el resultado correcto.

set role postgres;
insert into administradores (id,nombre)
values ('aaaa1111-0000-0000-0000-000000000001','Jason (SOCIO)')
on conflict (id) do nothing;

insert into marcas (id,nombre,ruc,giro,ciudad_almacen,ciudad_punto,celular,clave_hash,nivel_fiabilidad)
values ('e6000000-0000-0000-0000-00000000000a','Marca Prueba 16','20555555560','alimentos','Cusco','Cusco','955500200','x','confiable');
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values ('e6000000-0000-0000-0000-00000000000b','Socio Prueba 16','55500200','955500201','x','Cusco');
-- Un segundo socio, para comprobar que no puede confirmar entregas ajenas.
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values ('e6000000-0000-0000-0000-00000000000e','Socio Ajeno 16','55500202','955500203','x','Lima');
insert into productos (id,marca_id,nombre,emoji,estado,activo)
values ('e6000000-0000-0000-0000-00000000000c','e6000000-0000-0000-0000-00000000000a','Café de altura','☕','aprobado',true);
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen,stock_punto)
values ('e6000000-0000-0000-0000-00000000000d','e6000000-0000-0000-0000-00000000000c','Bolsa 500 g',50.00,120.00,40,40);
reset role;

set role authenticated;

\echo ''
\echo '--- 1 · Hasta la puerta de la marca ---'

\echo ''
\echo '### 1 · El socio registra y declara su depósito  (debe: pasar)'
set request.jwt.claim.sub = 'e6000000-0000-0000-0000-00000000000b';
select pedido_id as pid, codigo as cod
  from crear_pedido(
    '[{"presentacion_id":"e6000000-0000-0000-0000-00000000000d","cantidad":2}]'::jsonb,
    'Cliente Dieciséis','70000160','970000160','almacen','agencia','Shalom Cusco','shalom',10.00) \gset
select monto_a_pagar as monto from pedidos_socio where codigo = :'cod' \gset
select pago_id is not null as declarado
  from declarar_pago(:'pid'::uuid, 'OP-ENT-000001', :monto, 'transferencia',
                     'e6000000-0000-0000-0000-00000000000b/P16.jpg', 'HUELLA-16');

\echo ''
\echo '### 2 · SOCIO cruza el depósito y lo valida  (debe: quedar en validado)'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select validar_pago((select id from pagos where numero_operacion='OP-ENT-000001'), true, 'Cruzado con BCP');
select estado from pedidos_admin where codigo = :'cod';

\echo ''
\echo '--- 2 · La marca empaca y despacha ---'

\echo ''
\echo '### 3 · La marca ve QUÉ tiene que empacar  (debe: Café de altura · Bolsa 500 g · 2)'
set request.jwt.claim.sub = 'e6000000-0000-0000-0000-00000000000a';
select producto, presentacion, cantidad, precio_unit_mayorista
  from pedido_items_marca where pedido_id = :'pid'::uuid;

\echo ''
\echo '### 4 · Y NO ve lo que el socio pagó por ellos  (debe: FALLAR)'
select precio_unit_socio from pedido_items_marca where pedido_id = :'pid'::uuid;

\echo ''
\echo '### 5 · Despacha sin la foto de la guía  (debe: FALLAR)'
update pedidos set estado='en_camino', numero_guia='G-16', courier='shalom', tracking='T-16'
 where id = :'pid'::uuid;

\echo ''
\echo '### 6 · Despacha con todo lo que pide el contador  (debe: pasar)'
update pedidos set estado='en_camino', numero_guia='G-16', guia_url='e6000000-0000-0000-0000-00000000000a/G-16.jpg',
       courier='shalom', tracking='T-16'
 where id = :'pid'::uuid;
select estado, numero_guia, despachado_en is not null as con_fecha
  from pedidos_marca where id = :'pid'::uuid;

\echo ''
\echo '### 7 · Se le liberó su primer hito, el 70% de confiable  (debe: guia_registrada 70.00)'
select hito, monto from liberaciones_dinero where pedido_id = :'pid'::uuid order by liberado_en;

\echo ''
\echo '--- 3 · Quién da el paquete por recibido ---'

\echo ''
\echo '### 8 · LA MARCA se da por entregada sola  (debe: FALLAR — es el hallazgo de la auditoría)'
update pedidos set estado='entregado' where id = :'pid'::uuid;

\echo ''
\echo '### 9 · Y tampoco por la función  (debe: FALLAR)'
select confirmar_entrega(:'pid'::uuid);

\echo ''
\echo '### 10 · Un socio ajeno confirma la entrega de otro  (debe: FALLAR)'
set request.jwt.claim.sub = 'e6000000-0000-0000-0000-00000000000e';
select confirmar_entrega(:'pid'::uuid);

\echo ''
\echo '### 11 · El socio que vendió confirma que llegó  (debe: pasar)'
set request.jwt.claim.sub = 'e6000000-0000-0000-0000-00000000000b';
select codigo, estado, entregado_en is not null as con_fecha from confirmar_entrega(:'pid'::uuid);

\echo ''
\echo '### 12 · Confirmar dos veces  (debe: FALLAR)'
select confirmar_entrega(:'pid'::uuid);

\echo ''
\echo '### 13 · Con la entrega se soltó el resto del mayorista  (debe: sumar 100.00 en dos hitos)'
set role postgres;
select count(*) as hitos, sum(monto) as total_marca
  from liberaciones_dinero where pedido_id = :'pid'::uuid;
set role authenticated;

\echo ''
\echo '### 14 · Y el socio suma su venta entregada y ve su saldo  (debe: 1 venta, saldo = su ganancia)'
set request.jwt.claim.sub = 'e6000000-0000-0000-0000-00000000000b';
select (select ventas_entregadas from usuarios_socios
           where id = 'e6000000-0000-0000-0000-00000000000b') as ventas,
       saldo_disponible() = (select ganancia_socio from pedidos_socio where id = :'pid'::uuid) as saldo_cuadra;

\echo ''
\echo '### 15 · SOCIO también puede confirmar, cuando el socio no aparece  (debe: pasar)'
set request.jwt.claim.sub = 'e6000000-0000-0000-0000-00000000000b';
select pedido_id as pid2, codigo as cod2
  from crear_pedido(
    '[{"presentacion_id":"e6000000-0000-0000-0000-00000000000d","cantidad":1}]'::jsonb,
    'Cliente Dieciséis B','70000161','970000161','almacen','domicilio','Av. El Sol 200',null,0) \gset
select monto_a_pagar as monto2 from pedidos_socio where codigo = :'cod2' \gset
select pago_id is not null from declarar_pago(:'pid2'::uuid, 'OP-ENT-000002', :monto2, 'yape',
                     'e6000000-0000-0000-0000-00000000000b/P16B.jpg', 'HUELLA-16B');
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select validar_pago((select id from pagos where numero_operacion='OP-ENT-000002'), true, 'Cruzado');
set request.jwt.claim.sub = 'e6000000-0000-0000-0000-00000000000a';
update pedidos set estado='en_camino', numero_guia='G-16B',
       guia_url='e6000000-0000-0000-0000-00000000000a/G-16B.jpg' where id = :'pid2'::uuid;
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select codigo, estado from confirmar_entrega(:'pid2'::uuid);

\echo ''
\echo '--- 4 · El nivel baja si baja el ritmo (docs/09) ---'

\echo ''
\echo '### 16 · Un socio con 50 entregas históricas y ninguna este trimestre'
set role postgres;
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad,nivel,ventas_entregadas,creado_en)
values ('e6000000-0000-0000-0000-00000000000f','Socio Dormido','55500204','955500204','x','Lima',
        'diamante',50, now() - interval '400 days');
-- Y otro que sí sostiene el ritmo: 13 entregas en el trimestre.
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad,nivel,ventas_entregadas,creado_en)
values ('e6000000-0000-0000-0000-000000000010','Socia Activa','55500205','955500205','x','Lima',
        'diamante',50, now() - interval '400 days');
insert into pedidos (codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,
  detalle_entrega,estado,entregado_en)
select 'SOC-RIT-' || g, 'e6000000-0000-0000-0000-000000000010',
       'e6000000-0000-0000-0000-00000000000a', 100,50,30,20,'Cliente','70000000','970000000',
       'almacen','domicilio','Av. Siempre Viva 100','entregado', now() - interval '10 days'
  from generate_series(1,13) g;
-- Y uno recién registrado: no se revisa todavía.
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad,nivel,ventas_entregadas,creado_en)
values ('e6000000-0000-0000-0000-000000000011','Socio Nuevo','55500206','955500206','x','Lima',
        'plata',10, now() - interval '5 days');
reset role;

\echo ''
\echo '### 17 · Un socio cualquiera lanza la revisión  (debe: FALLAR)'
set role authenticated;
set request.jwt.claim.sub = 'e6000000-0000-0000-0000-00000000000b';
select revisar_niveles_trimestrales();

\echo ''
\echo '### 18 · SOCIO la lanza  (debe: bajar a Socio Dormido de diamante a oro, y a nadie más)'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select nombre, nivel_antes, nivel_despues, entregas_trimestre, ritmo_pedido
  from revisar_niveles_trimestrales();

\echo ''
\echo '### 19 · La misma revisión otra vez el mismo día  (debe: no devolver a nadie — nadie baja dos veces)'
select count(*) as cambios from revisar_niveles_trimestrales();

\echo ''
\echo '### 20 · Y el mérito no se borró: sigue con sus 50 ventas  (debe: oro · 50 · 1 descenso)'
set role postgres;
select nivel, ventas_entregadas, descensos
  from usuarios_socios where id = 'e6000000-0000-0000-0000-00000000000f';

\echo ''
\echo '### 21 · Vuelve a vender y recupera su escalón  (debe: oro → diamante)'
insert into pedidos (codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,
  detalle_entrega,estado,entregado_en)
select 'SOC-VUE-' || g, 'e6000000-0000-0000-0000-00000000000f',
       'e6000000-0000-0000-0000-00000000000a', 100,50,30,20,'Cliente','70000000','970000000',
       'almacen','domicilio','Av. Siempre Viva 200','entregado', now() - interval '3 days'
  from generate_series(1,13) g;
-- Se adelanta el reloj: pasó un trimestre desde la revisión anterior.
update usuarios_socios set nivel_revisado_en = now() - interval '95 days'
 where id = 'e6000000-0000-0000-0000-00000000000f';
set role authenticated;
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select nombre, nivel_antes, nivel_despues from revisar_niveles_trimestrales();

\echo ''
\echo '### 22 · Una venta nueva ya no lo devuelve solo a diamante por el total histórico'
\echo '         (se comprueba con el socio dormido ya recuperado: nivel diamante, 0 descensos)'
set role postgres;
select nivel, descensos from usuarios_socios where id = 'e6000000-0000-0000-0000-00000000000f';
reset role;
