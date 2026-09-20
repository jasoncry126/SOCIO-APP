-- =============================================================================
-- SOCIO · El nombre de la marca, dentro del catálogo
--
-- Al conectar la app del socio salió un hueco: la pantalla le muestra de qué
-- marca es cada producto, pero los permisos NO le dejan leer la tabla 'marcas'
-- — y con razón, porque ahí están el RUC, el nivel de fiabilidad y el historial
-- de entregas de cada proveedor, que no son asunto suyo.
--
-- La salida no es abrirle la tabla, sino añadir al catálogo los cuatro datos de
-- marca que el socio sí necesita para vender: cómo se llama, a qué se dedica y
-- desde dónde despacha. La vista ya es la superficie de "lo que el socio puede
-- ver"; esto la completa sin ensancharla.
--
-- De paso, las ciudades de despacho dejan de estar escritas a mano en la
-- pantalla: cada marca trae las suyas. Es el primer paso de lo que CLAUDE.md
-- marca como pendiente — ORIGENES fijo a Cusco/Lima para toda la plataforma.
-- =============================================================================

begin;

drop view if exists catalogo_publico;

create view catalogo_publico as
  select pr.id,
         pr.producto_id,
         pr.nombre           as presentacion,
         pr.precio_publico,
         pr.stock_almacen,
         pr.stock_punto,
         p.marca_id,
         m.nombre            as marca,
         m.giro              as marca_giro,
         m.ciudad_almacen    as marca_ciudad_almacen,
         m.ciudad_punto      as marca_ciudad_punto,
         p.nombre            as producto,
         p.nombre_comprobante,
         p.categoria,
         p.emoji,
         p.descripcion,
         p.recomendaciones,
         p.tiempo_prep,
         p.cobertura,
         p.corte_nacional,
         p.corte_local,
         p.dias_despacho
    from presentaciones pr
    join productos p on p.id = pr.producto_id
    join marcas    m on m.id = p.marca_id
   where p.estado = 'aprobado'
     and p.activo = true;

-- Lo que NO entra: ruc, nivel_fiabilidad, entregas_ok, entregas_incidencia,
-- celular. El socio vende los productos de la marca, no audita a la marca.

grant select on catalogo_publico to anon, authenticated;

commit;
