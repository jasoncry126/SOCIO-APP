set role authenticated;
-- "Otro Socio", que no tiene ningun pedido ni pago propio
set request.jwt.claim.sub = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

\echo '-- pedidos que puede ver (esperado 0, RLS activo):'
select count(*) from pedidos;

\echo '-- pagos de OTROS que puede leer (con la 2ª migración debe ser 0 filas):'
select numero_operacion, monto_esperado, estado from pagos;

\echo '-- precios MAYORISTAS que puede leer (con la 2ª migración: 0 filas):'
select nombre, precio_mayorista, precio_publico from presentaciones;

\echo '-- puede escribir en bitacora? (sí: es un buzón de una sola dirección)'
insert into bitacora (tabla,registro_id,accion,actor_tipo)
values ('pedidos','55555555-5555-5555-5555-555555555555','falsificado','sistema');
\echo '-- puede BORRAR de bitacora? (con la 2ª migración: permiso denegado)'
delete from bitacora where accion='falsificado';
reset role;
