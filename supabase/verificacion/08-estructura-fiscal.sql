-- Sección 4 del informe del contador, comprobada regla por regla.
-- Se ejecuta sobre los datos que dejó 05-circuito-de-venta.

set role postgres;
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
 values ('77777777-7777-7777-7777-777777777777','Socio Curioso','11223344','900000001','x','Lima');

set role authenticated;

\echo '=================== A · PRIVACIDAD DE LOS IMPORTES ==================='

\echo '### A1 · El SOCIO lee su pedido: ¿aparece el precio mayorista? (debe: fallar)'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select precio_mayorista from pedidos;

\echo '### A2 · ¿y la comisión de la plataforma? (debe: fallar)'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select comision_socio_app from pedidos;

\echo '### A3 · Lo que SÍ ve el socio, por su vista'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select codigo, precio_socio, ganancia_socio, estado, marca from pedidos_socio;

\echo '### A4 · Columnas de pedidos_socio: no debe figurar ni mayorista ni comisión'
select string_agg(column_name, ', ' order by ordinal_position)
  from information_schema.columns where table_name='pedidos_socio';

\echo '### A5 · La MARCA lee su pedido: ¿aparece lo que paga el socio? (debe: fallar)'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select precio_socio from pedidos;

\echo '### A6 · Lo que SÍ ve la marca: su mayorista íntegro'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select codigo, precio_mayorista, estado from pedidos_marca;

\echo '### A7 · Columnas de pedidos_marca: no debe figurar precio_socio, ganancia_socio ni comision_socio_app'
select string_agg(column_name, ', ' order by ordinal_position)
  from information_schema.columns where table_name='pedidos_marca';

\echo '### A8 · Un socio ajeno, ¿ve algo por las vistas? (debe: 0, 0, 0)'
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
select (select count(*) from pedidos_socio) mios,
       (select count(*) from pedidos_marca) de_marca,
       (select count(*) from pedidos_admin) de_admin;

\echo '### A9 · Los items: ¿el socio ve el precio unitario mayorista? (debe: fallar)'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select precio_unit_mayorista from pedido_items;

\echo '### A10 · El socio ve el suyo; la marca ve el suyo'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select cantidad, precio_unit_socio from pedido_items_socio;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select cantidad, precio_unit_mayorista from pedido_items_marca;

\echo ''
\echo '=================== A(bis) · LA MARCA NO REESCRIBE IMPORTES ==================='

\echo '### A11 · ¿La marca puede subirse el mayorista de un pedido cerrado? (debe: fallar)'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update pedidos set precio_mayorista = 900 where id='55555555-5555-5555-5555-555555555555';

\echo '### A12 · ¿Puede recortarle la comisión al socio? (debe: fallar)'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update pedidos set ganancia_socio = 0 where id='55555555-5555-5555-5555-555555555555';

\echo ''
\echo '=================== B · COMPROBANTE DEL VENDEDOR ==================='

\echo '### B1 · ¿Un socio ajeno puede registrar el comprobante de un pedido que no es suyo? (debe: fallar)'
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
select registrar_comprobante('55555555-5555-5555-5555-555555555555','boleta','B999','1');

\echo '### B2 · ¿Vale cualquier tipo de comprobante? (debe: fallar)'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select registrar_comprobante('55555555-5555-5555-5555-555555555555','recibo','B001','2');

\echo '### B3 · ¿Sin serie ni número? (debe: fallar)'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select registrar_comprobante('55555555-5555-5555-5555-555555555555','boleta','','');

\echo '### B4 · ¿Puede un socio ponerse un RUC y quitarse el suyo? Sí, es suyo'
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
update usuarios_socios set ruc='10112233445', emite_comprobante=true where id='77777777-7777-7777-7777-777777777777';
select nombre, ruc, emite_comprobante from usuarios_socios;

\echo '### B5 · Pero seguir sin poder subirse de nivel (debe: fallar)'
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
update usuarios_socios set nivel='diamante' where id='77777777-7777-7777-7777-777777777777';

\echo '### B6 · ni marcarse como validado por SOCIO (debe: fallar)'
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
update usuarios_socios set validado=true where id='77777777-7777-7777-7777-777777777777';

\echo ''
\echo '=================== C · MÁQUINA DE ESTADOS ==================='

set role postgres;
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,detalle_entrega)
values ('66666666-0000-0000-0000-000000000002','SOC-0913-C001','22222222-2222-2222-2222-222222222222',
 '11111111-1111-1111-1111-111111111111',157.50,122.50,17.50,35,'Beto','70000001','900000002','almacen','agencia','Olva Lima');
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

\echo '### C1 · pendiente_pago → en_camino, saltándose todo (debe: fallar)'
update pedidos set estado='en_camino', numero_guia='G',courier='c',tracking='t'
 where id='66666666-0000-0000-0000-000000000002';

\echo '### C2 · pendiente_pago → entregado, el atajo más goloso (debe: fallar)'
update pedidos set estado='entregado' where id='66666666-0000-0000-0000-000000000002';

\echo '### C3 · pendiente_pago → cancelado (debe: pasar)'
update pedidos set estado='cancelado' where id='66666666-0000-0000-0000-000000000002';
select codigo, estado from pedidos_marca where codigo='SOC-0913-C001';

\echo '### C4 · un pedido cancelado no revive (debe: fallar)'
update pedidos set estado='pagado' where id='66666666-0000-0000-0000-000000000002';

\echo '### C5 · guía en blanco no cuenta como evidencia (debe: fallar)'
set role postgres;
insert into pedidos (id,codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,detalle_entrega,estado)
values ('66666666-0000-0000-0000-000000000003','SOC-0913-C002','22222222-2222-2222-2222-222222222222',
 '11111111-1111-1111-1111-111111111111',157.50,122.50,17.50,35,'Ceci','70000002','900000003','almacen','agencia','Olva Lima','validado');
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
update pedidos set estado='en_camino', numero_guia='   ', courier='olva', tracking='X'
 where id='66666666-0000-0000-0000-000000000003';

\echo '### C6 · sin tracking tampoco (debe: fallar)'
update pedidos set estado='en_camino', numero_guia='T001-1', courier='olva'
 where id='66666666-0000-0000-0000-000000000003';

\echo '### C7 · con las tres evidencias, pasa'
update pedidos set estado='en_camino', numero_guia='T001-1', courier='olva', tracking='OLV-777'
 where id='66666666-0000-0000-0000-000000000003';
select codigo, estado, despachado_en is not null as se_puso_la_fecha from pedidos_marca where codigo='SOC-0913-C002';

\echo ''
\echo '=================== D · REPORTE CONTABLE ==================='

\echo '### D1 · ¿Lo puede leer un socio? (debe: 0 filas)'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select count(*) from reporte_contable;

\echo '### D2 · ¿Y una marca? (debe: 0 filas)'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select count(*) from reporte_contable;

\echo '### D3 · SOCIO sí, con las columnas que pidió el contador'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select pedido, marca, vendedor, ruc_vendedor, precio_venta, comision_vendedor,
       comision_plataforma, comision_plataforma_sin_igv, igv_comision_plataforma
  from reporte_contable order by pedido;

\echo '### D4 · Las cuentas cuadran: mayorista + comisión vendedor + comisión plataforma = precio de venta'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select pedido,
       costo_mayorista + comision_vendedor + comision_plataforma as suma,
       precio_venta,
       (costo_mayorista + comision_vendedor + comision_plataforma = precio_venta) as cuadra
  from reporte_contable order by pedido;

\echo '### D5 · Y el IGV desglosado suma la comisión completa'
set request.jwt.claim.sub = 'aaaa1111-0000-0000-0000-000000000001';
select pedido, comision_plataforma,
       abs((comision_plataforma_sin_igv + igv_comision_plataforma) - comision_plataforma) <= 0.01 as cuadra
  from reporte_contable order by pedido;
