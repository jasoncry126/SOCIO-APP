-- Las fotos del catálogo (migración 20260921160000), comprobadas por sus dos
-- caras: que la marca puede poner la foto de SU producto, que no puede tocar la
-- del vecino, y que la vista del socio la devuelve sin devolver de paso nada
-- que no le toque.

set role postgres;
insert into marcas (id,nombre,ruc,giro,ciudad_almacen,ciudad_punto,celular,clave_hash,nivel_fiabilidad)
values ('f0000000-0000-0000-0000-00000000000a','Marca Foto','20555555561','ropa','Arequipa','Trujillo','955500140','x','confiable'),
       ('f0000000-0000-0000-0000-00000000000e','Marca Vecina','20555555562','ropa','Lima','Lima','955500141','x','nueva');
insert into usuarios_socios (id,nombre,dni,celular,clave_hash,ciudad)
values ('f0000000-0000-0000-0000-00000000000b','Socio Foto','55500140','955500142','x','Lima');
insert into productos (id,marca_id,nombre,estado,activo,emoji)
values ('f0000000-0000-0000-0000-00000000000c','f0000000-0000-0000-0000-00000000000a','Polo con foto','aprobado',true,'👕');
insert into presentaciones (id,producto_id,nombre,precio_mayorista,precio_publico,stock_almacen,stock_punto)
values ('f0000000-0000-0000-0000-00000000000d','f0000000-0000-0000-0000-00000000000c','Talla M',60.00,150.00,10,5);
reset role;

\echo ''
\echo '### 1 · La columna existe y admite vacío  (debe: is_nullable = YES)'
select column_name, data_type, is_nullable
  from information_schema.columns
 where table_name = 'presentaciones' and column_name = 'imagen';

\echo ''
\echo '### 2 · Una presentación sin foto no estorba  (debe: imagen nula)'
select imagen is null as sin_foto
  from presentaciones where id = 'f0000000-0000-0000-0000-00000000000d';

set role authenticated;

\echo ''
\echo '### 3 · La MARCA pone la foto de su producto  (debe: 1 fila)'
set request.jwt.claim.sub = 'f0000000-0000-0000-0000-00000000000a';
update presentaciones
   set imagen = 'f0000000-0000-0000-0000-00000000000a/polo-m.webp'
 where id = 'f0000000-0000-0000-0000-00000000000d'
returning imagen;

\echo ''
\echo '### 4 · La marca VECINA intenta cambiarle la foto  (debe: 0 filas)'
set request.jwt.claim.sub = 'f0000000-0000-0000-0000-00000000000e';
update presentaciones
   set imagen = 'f0000000-0000-0000-0000-00000000000e/foto-robada.webp'
 where id = 'f0000000-0000-0000-0000-00000000000d'
returning imagen;

\echo ''
\echo '### 5 · El SOCIO ve la foto en su vista  (debe: la ruta de la marca dueña)'
set request.jwt.claim.sub = 'f0000000-0000-0000-0000-00000000000b';
select producto, presentacion, imagen
  from catalogo_publico
 where id = 'f0000000-0000-0000-0000-00000000000d';

\echo ''
\echo '### 6 · Y sigue sin ver el precio mayorista  (debe: FALLAR)'
select precio_mayorista from catalogo_publico
 where id = 'f0000000-0000-0000-0000-00000000000d';

\echo ''
\echo '### 7 · La vista conserva las columnas de la marca  (debe: las cuatro en TRUE)'
-- Esta vista está definida en varias migraciones y cada create-or-replace la
-- reescribe entera. Si alguien vuelve a partir de una versión vieja, esto salta.
select
  count(*) filter (where column_name = 'marca')                as tiene_marca,
  count(*) filter (where column_name = 'marca_giro')           as tiene_giro,
  count(*) filter (where column_name = 'marca_ciudad_almacen') as tiene_almacen,
  count(*) filter (where column_name = 'marca_ciudad_punto')   as tiene_punto
  from information_schema.columns
 where table_name = 'catalogo_publico';

reset role;
