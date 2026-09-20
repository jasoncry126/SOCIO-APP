-- El circuito de venta: el socio registra un pedido y declara su pago.
-- Se ejecuta después de 10.

set role postgres;
insert into marcas (id,nombre,ruc,giro,ciudad_almacen,ciudad_punto,celular,clave_hash,nivel_fiabilidad)
 values ('a1000000-0000-0000-0000-000000000001','Marca Circuito','20777666555','varios','Cusco','Lima','930000001','x','confiable');
insert into productos (id,marca_id,nombre,categoria,estado,activo)
 values ('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','GHK-Cu','Piel','aprobado',true),
        ('a2000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','En revisión','Piel','revision',false);
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen,stock_punto)
 values ('a3000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','Vial 50 mg',129.67,175.00,10,3),
        ('a3000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000001','Vial 100 mg',210.00,300.00,5,0),
        ('a3000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000002','Oculto',50,100,99,99);
-- Una segunda marca, para probar que no se pueden mezclar
insert into marcas (id,nombre,ruc,giro,ciudad_almacen,celular,clave_hash)
 values ('a1000000-0000-0000-0000-000000000002','Otra Marca','20777666556','varios','Lima','930000002','x');
insert into productos (id,marca_id,nombre,estado,activo)
 values ('a2000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000002','Café','aprobado',true);
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen)
 values ('a3000000-0000-0000-0000-000000000004','a2000000-0000-0000-0000-000000000003','Bolsa 1kg',40,60,20);

insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad,nivel)
 values ('a4000000-0000-0000-0000-000000000001','Socio Bronce','30000001','931000001','x','Cusco','bronce'),
        ('a4000000-0000-0000-0000-000000000002','Socio Diamante','30000002','931000002','x','Lima','diamante');

set role authenticated;
set request.jwt.claim.sub = 'a4000000-0000-0000-0000-000000000001';

\echo '=================== LA PUERTA DE ATRÁS, CERRADA ==================='

\echo '### 0a · ¿Puede el socio insertar un pedido a mano, inventándose su comisión? (debe: fallar)'
insert into pedidos (codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,detalle_entrega)
values ('SOC-HACK-1','a4000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',
  5,0,170,0,'Yo','1','9','almacen','agencia','x');

\echo '### 0b · ¿Puede insertar un pago a mano con el monto que quiera? (debe: fallar)'
insert into pagos (pedido_id,numero_operacion,monto_esperado,monto_reportado,metodo)
values ('55555555-5555-5555-5555-555555555555','OP-HACK',1,1,'yape');

\echo ''
\echo '=================== EL PEDIDO, CALCULADO POR LA BASE ==================='

\echo '### 1 · Socio BRONCE compra 1 vial de 175 (mayorista 129.67)'
\echo '--   esperado: paga 157.50 · gana 17.50 · PVP 175.00'
select codigo, precio_socio, ganancia_socio, precio_publico, monto_esperado
  from crear_pedido(
    '[{"presentacion_id":"a3000000-0000-0000-0000-000000000001","cantidad":1}]'::jsonb,
    'Ana Circuito','70111222','912345678','almacen','agencia','Olva Cusco centro','olva',0);

\echo '### 2 · El navegador no mandó ningún precio, y aun así los cuatro montos cuadran'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select codigo, precio_mayorista, ganancia_socio, comision_socio_app, precio_publico,
       precio_mayorista + ganancia_socio + comision_socio_app = precio_publico as cuadra
  from pedidos_admin where codigo like 'SOC-%' and destinatario = 'Ana Circuito';

\echo '### 3 · Socio DIAMANTE, mismo producto: gana más, y sale del bolsillo de SOCIO'
set request.jwt.claim.sub = 'a4000000-0000-0000-0000-000000000002';
select precio_socio, ganancia_socio from crear_pedido(
    '[{"presentacion_id":"a3000000-0000-0000-0000-000000000001","cantidad":1}]'::jsonb,
    'Beto Circuito','70111333','912345679','almacen','agencia','Olva Lima','olva',0);

set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select s.nivel, p.ganancia_socio, p.comision_socio_app, p.precio_mayorista
  from pedidos_admin p join usuarios_socios s on s.id = p.socio_id
 where p.destinatario in ('Ana Circuito','Beto Circuito') order by s.nivel;

\echo ''
\echo '=================== LO QUE NO SE PUEDE PEDIR ==================='

set request.jwt.claim.sub = 'a4000000-0000-0000-0000-000000000001';

\echo '### 4 · Un producto que sigue en revisión (debe: fallar)'
select crear_pedido('[{"presentacion_id":"a3000000-0000-0000-0000-000000000003","cantidad":1}]'::jsonb,
  'X','1','9','almacen','agencia','x','olva',0);

\echo '### 5 · Mezclar dos marcas en un pedido (debe: fallar)'
select crear_pedido('[{"presentacion_id":"a3000000-0000-0000-0000-000000000001","cantidad":1},
                      {"presentacion_id":"a3000000-0000-0000-0000-000000000004","cantidad":1}]'::jsonb,
  'X','1','9','almacen','agencia','x','olva',0);

\echo '### 6 · Más unidades de las que hay en stock (debe: fallar)'
select crear_pedido('[{"presentacion_id":"a3000000-0000-0000-0000-000000000002","cantidad":99}]'::jsonb,
  'X','1','9','almacen','agencia','x','olva',0);

\echo '### 7 · Del punto de venta, que tiene menos stock que el almacén (debe: fallar)'
select crear_pedido('[{"presentacion_id":"a3000000-0000-0000-0000-000000000002","cantidad":2}]'::jsonb,
  'X','1','9','punto_venta','domicilio','Av. Lima 100',null,0);

\echo '### 8 · Sin datos de quien recibe (debe: fallar)'
select crear_pedido('[{"presentacion_id":"a3000000-0000-0000-0000-000000000001","cantidad":1}]'::jsonb,
  '','','','almacen','agencia','x','olva',0);

\echo '### 9 · Cantidad negativa (debe: fallar)'
select crear_pedido('[{"presentacion_id":"a3000000-0000-0000-0000-000000000001","cantidad":-3}]'::jsonb,
  'X','1','9','almacen','agencia','x','olva',0);

\echo ''
\echo '=================== EL MONTO CON CÉNTIMOS ÚNICOS (docs/12) ==================='

\echo '### 10 · Los céntimos salen del código: el mismo pedido pide siempre lo mismo'
select monto_a_pagar('SOC-0917-AB12', 157.50) as primera,
       monto_a_pagar('SOC-0917-AB12', 157.50) as segunda,
       monto_a_pagar('SOC-0917-AB12', 157.50) = monto_a_pagar('SOC-0917-AB12', 157.50) as estable;

\echo '### 11 · Nunca se cobra de menos, y nunca más de un sol de diferencia'
select count(*) filter (where m < t)         as cobra_de_menos,
       count(*) filter (where m - t >= 1.00) as cobra_mas_de_un_sol,
       count(*)                              as casos
  from (select monto_a_pagar('SOC-' || g, 100 + g * 0.37) as m,
               round((100 + g * 0.37)::numeric, 2)        as t
          from generate_series(1, 300) g) x;

\echo '### 12 · Cuántos montos distintos salen para el MISMO total (99 céntimos posibles)'
\echo '--   Con 20 pedidos idénticos en un día se repite algún monto: es inevitable y'
\echo '--   está asumido. Lo que identifica el depósito sin ambigüedad es el número'
\echo '--   de operación (docs/12 capa 1); los céntimos solo ayudan a la vista.'
select n_pedidos,
       montos_distintos,
       n_pedidos - montos_distintos as repetidos
  from (select 20 as n_pedidos,
               (select count(distinct monto_a_pagar('SOC-0917-' || g, 157.50))
                  from generate_series(1, 20) g) as montos_distintos) x;

\echo ''
\echo '=================== DECLARAR EL PAGO ==================='

set request.jwt.claim.sub = 'a4000000-0000-0000-0000-000000000001';

\echo '### 13 · El socio paga exactamente lo que la base le pidió: cuadra'
select pago_id is not null as se_creo, monto_esperado, cuadra
  from declarar_pago(
    (select id from pedidos_socio where destinatario='Ana Circuito'),
    'OP-55512345',
    (select monto_a_pagar(codigo, round(precio_socio + costo_envio, 2))
       from pedidos_socio where destinatario='Ana Circuito'),
    'yape');

\echo '### 14 · El pedido pasó solo a "pagado"'
select codigo, estado from pedidos_socio where destinatario = 'Ana Circuito';

\echo '### 15 · Declarar dos veces el mismo pedido (debe: fallar)'
select declarar_pago((select id from pedidos where destinatario='Ana Circuito'),
                     'OP-99999999', 157.87, 'yape');

\echo '### 16 · Reusar el número de operación en otro pedido (debe: fallar)'
set request.jwt.claim.sub = 'a4000000-0000-0000-0000-000000000002';
select declarar_pago((select id from pedidos where destinatario='Beto Circuito'),
                     'OP-55512345', 140.00, 'yape');

\echo '### 17 · Declarar el pago de un pedido ajeno (debe: fallar)'
select declarar_pago((select id from pedidos where destinatario='Ana Circuito'),
                     'OP-77777777', 157.87, 'yape');

\echo '### 18 · Sin número de operación (debe: fallar)'
select declarar_pago((select id from pedidos where destinatario='Beto Circuito'),
                     '   ', 140.00, 'yape');

\echo '### 19 · Un monto que no cuadra se registra igual, pero marcado'
select monto_esperado, cuadra from declarar_pago(
  (select id from pedidos where destinatario='Beto Circuito'), 'OP-88888888', 10.00, 'yape');

\echo ''
\echo '### 20 · Todo quedó en la bitácora'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select tabla, accion, actor_tipo from bitacora
 where accion in ('creado','pago_declarado') order by id;

\echo ''
\echo '=================== EL CATÁLOGO TRAE LA MARCA ==================='

\echo '### 21 · El socio ve de qué marca es cada producto y desde dónde despacha'
set request.jwt.claim.sub = 'a4000000-0000-0000-0000-000000000001';
select distinct marca, marca_giro, marca_ciudad_almacen, marca_ciudad_punto
  from catalogo_publico where marca = 'Marca Circuito';

\echo '### 22 · ...pero sigue sin poder leer la tabla de marcas (debe: 0 filas)'
select count(*) as marcas_que_ve from marcas;

\echo '### 23 · Y el catálogo NO revela el RUC ni el nivel de fiabilidad'
select string_agg(column_name, ', ') as columnas_prohibidas
  from information_schema.columns
 where table_name = 'catalogo_publico'
   and column_name in ('ruc','nivel_fiabilidad','entregas_ok','entregas_incidencia','celular');
