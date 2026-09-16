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

drop function if exists actualizar_nivel_socio() cascade;

commit;
