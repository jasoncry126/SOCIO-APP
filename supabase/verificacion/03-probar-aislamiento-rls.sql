-- Supabase concede por defecto privilegios a anon/authenticated; aquí lo replicamos
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;

-- Segundo socio y segunda marca, para probar el aislamiento
insert into marcas (id,nombre,ruc,giro,ciudad_almacen,celular,clave_hash)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','Otra Marca','20987654321','ropa','Arequipa','955555555','x');
insert into productos (marca_id,nombre,estado,activo)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','Polo en revision','revision',false);
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','Otro Socio','87654321','911111111','x','Lima');

\echo ''
\echo '=== Como SOCIO Demo (22222222...) ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
\echo '-- perfiles visibles (esperado: solo el suyo)'
select nombre from usuarios_socios;
\echo '-- pedidos visibles (esperado: solo sus 2)'
select codigo from pedidos order by codigo;
\echo '-- productos visibles (esperado: solo aprobado+activo, NO el de otra marca en revision)'
select nombre from productos order by nombre;

\echo ''
\echo '=== Como MARCA Demo (11111111...) ==='
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
\echo '-- pedidos visibles (esperado: sus 2 pedidos)'
select codigo from pedidos order by codigo;
\echo '-- su propio perfil de marca'
select nombre from marcas;

\echo ''
\echo '=== Como OTRA MARCA (aaaaaaaa...) ==='
set request.jwt.claim.sub = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
\echo '-- pedidos visibles (esperado: NINGUNO, no son suyos)'
select codigo from pedidos order by codigo;
\echo '-- productos visibles (esperado: el aprobado de la otra marca + su propio borrador)'
select nombre from productos order by nombre;

reset role;
