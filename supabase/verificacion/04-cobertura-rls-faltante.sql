set role authenticated;
-- "Otro Socio", que no tiene ningun pedido ni pago propio
set request.jwt.claim.sub = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

\echo '-- pedidos que puede ver (esperado 0, RLS activo):'
select count(*) from pedidos;

\echo '-- pagos de OTROS que puede leer (tabla sin RLS declarado en docs/13):'
select numero_operacion, monto_esperado, estado from pagos;

\echo '-- precios MAYORISTAS que puede leer (presentaciones, sin RLS declarado):'
select nombre, precio_mayorista, precio_publico from presentaciones;

\echo '-- puede escribir en bitacora? (sin RLS ni revoke activo):'
insert into bitacora (tabla,registro_id,accion,actor_tipo)
values ('pedidos','55555555-5555-5555-5555-555555555555','falsificado','sistema');
\echo '-- puede BORRAR de bitacora?'
delete from bitacora where accion='falsificado';
reset role;
