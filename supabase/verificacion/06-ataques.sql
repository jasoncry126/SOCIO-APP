-- Un segundo socio y una segunda marca, para probar el aislamiento
-- (el arranque siembra un 2º socio y una 2ª marca saltándose RLS, como haría el servidor)
set role postgres;
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values ('99999999-9999-9999-9999-999999999999','Socio Intruso','87654321','911111111','x','Lima');
insert into marcas (id,nombre,ruc,giro,ciudad_almacen,celular,clave_hash)
values ('88888888-8888-8888-8888-888888888888','Marca Rival','20987654321','ropa','Arequipa','955555555','x');

set role authenticated;
set request.jwt.claim.sub = '99999999-9999-9999-9999-999999999999';   -- el intruso

\echo '### A · ¿ve la ficha de otro socio?          (debe: 1 = solo la suya)'
select count(*) from usuarios_socios;

\echo '### B · ¿lee el PRECIO MAYORISTA?            (debe: 0 filas)'
select count(*) from presentaciones;

\echo '### C · ¿ve el catálogo público?             (debe: 1, sin mayorista)'
select count(*) from catalogo_publico;

\echo '### D · ¿ve pedidos ajenos?                  (debe: 0)'
select count(*) from pedidos;

\echo '### E · ¿ve el voucher de otro socio?        (debe: 0)'
select count(*) from pagos;

\echo '### F · ¿puede crear un pedido A NOMBRE DE OTRO socio?  (debe: fallar)'
insert into pedidos (codigo,socio_id,marca_id,precio_socio,precio_mayorista,ganancia_socio,
  comision_socio_app,destinatario,doc_destinatario,celular_destinatario,origen,modo_entrega,detalle_entrega)
values ('SOC-FALSO-1','22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',
  1,0.5,0.5,0,'X','1','9','almacen','agencia','x');

\echo '### G · ¿puede validarse su propio pago?     (debe: 0 filas tocadas)'
update pagos set estado='validado';

\echo '### H · ¿puede regalarse dinero?             (debe: fallar)'
insert into liberaciones_dinero (pedido_id,marca_id,hito,monto)
values ('55555555-5555-5555-5555-555555555555','88888888-8888-8888-8888-888888888888','entrega_confirmada',9999);

\echo '### I · ¿puede borrar la bitácora?           (debe: fallar)'
delete from bitacora;

\echo '### J · ¿puede subirse de nivel a mano?      (debe: fallar)'
update usuarios_socios set nivel='diamante', ventas_entregadas=999;
select nombre, nivel from usuarios_socios where id='22222222-2222-2222-2222-222222222222';

\echo '### K · una MARCA RIVAL, ¿puede despachar pedidos ajenos? (debe: 0)'
set request.jwt.claim.sub = '88888888-8888-8888-8888-888888888888';
update pedidos set estado='cancelado';

\echo '### L · una MARCA, ¿puede ascenderse a "aliada" y cobrar 100% adelantado?'
set request.jwt.claim.sub = '88888888-8888-8888-8888-888888888888';
update marcas set nivel_fiabilidad='aliada', entregas_ok=500 where id='88888888-8888-8888-8888-888888888888';

\echo '### M · ¿puede al menos corregir su nombre y su almacén? (debe: sí)'
update marcas set nombre='Marca Rival SAC', ciudad_almacen='Trujillo' where id='88888888-8888-8888-8888-888888888888';
select nombre, ciudad_almacen, nivel_fiabilidad from marcas where id='88888888-8888-8888-8888-888888888888';
