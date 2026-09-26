-- =============================================================================
-- ⚠️  BORRA LAS 10 TABLAS Y TODO LO QUE TENGAN DENTRO
--
-- Úsalo SOLO si la carga quedó a medias y quieres volver a empezar limpio,
-- y SOLO mientras la base esté vacía (sin socios, marcas ni pedidos reales).
-- No se puede deshacer.
--
-- Después de correr esto, vuelve a pegar y ejecutar
-- migrations/20260912000000_modelo_de_datos_inicial.sql
-- =============================================================================

begin;

-- 'cascade' se lleva por delante las políticas RLS, los índices y las claves
-- foráneas que dependan de cada tabla, así no hay que borrarlos uno por uno.
drop table if exists bitacora            cascade;
drop table if exists retiros             cascade;
drop table if exists liberaciones_dinero cascade;
drop table if exists pagos               cascade;
drop table if exists pedido_items        cascade;
drop table if exists pedidos             cascade;
drop table if exists presentaciones      cascade;
drop table if exists productos           cascade;
drop table if exists marcas              cascade;
drop table if exists usuarios_socios     cascade;

-- La 11ª tabla, que llegó después de que se escribiera este archivo: la de los
-- administradores de SOCIO (3ª migración). Faltaba aquí, y era la única razón
-- por la que reinstalar de cero fallaba: la 3ª migración crea la tabla sin
-- 'if not exists', así que al reaplicarla se encontraba con la vieja y cortaba.
-- Se pierde la fila que dice quién es administrador, no la cuenta: esa vive en
-- Authentication y sigue ahí. Después de reinstalar, vuelve a correr el
-- 'insert into administradores' con tu User UID.
drop table if exists administradores     cascade;

drop function if exists actualizar_nivel_socio() cascade;

-- Lo que NO se borra, a propósito: los cubos de archivos (guias, vouchers,
-- catalogo) con sus reglas y sus ficheros dentro, y las cuentas de
-- Authentication. Las migraciones saben reencontrárselos, y borrarlos se
-- llevaría por delante fotos y comprobantes que no estorban.

commit;
