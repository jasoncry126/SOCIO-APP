-- ===========================================================================
-- SOCIO · Catálogo de prueba para poder generar ventas
-- ---------------------------------------------------------------------------
-- QUÉ HACE
--   Le cuelga a una marca que TÚ ya registraste un catálogo pequeño, ya
--   aprobado y con stock, para que un socio pueda entrar y comprar sin esperar
--   a que nadie cargue nada a mano. Seis productos, tres categorías, doce
--   presentaciones, stock en almacén y en punto de venta.
--
--   Los productos son de un rubro cualquiera a propósito: SOCIO es multi-marca
--   y esto sirve para probar el mecanismo, no para vender péptidos. Todos
--   llevan «(prueba)» en el nombre para que se distingan de un vistazo del
--   catálogo de verdad, y al final de este archivo está el borrado.
--
-- CÓMO SE USA
--   1. Registra una marca desde el panel de la marca (proveedor.html). Anota
--      el celular con el que la registraste.
--   2. Pega ESTE archivo entero en el SQL Editor de tu Supabase.
--   3. Cambia el celular de la línea marcada más abajo por el tuyo.
--   4. Run.
--
--   Si sale «no encontré ninguna marca con ese celular», es que aún no la
--   registraste o el número no coincide: son 9 dígitos, sin espacios.
--
-- ANTES DE ESTO tienen que estar aplicadas las 15 migraciones de
-- supabase/migrations. Si no, fallará porque faltan columnas.
-- ===========================================================================

do $$
declare
  -- ⬇⬇⬇ LO ÚNICO QUE HAY QUE CAMBIAR ⬇⬇⬇
  v_celular_marca varchar(9) := '987654321';
  -- ⬆⬆⬆ el celular con el que registraste tu marca de prueba ⬆⬆⬆

  v_marca uuid;
  v_prod  uuid;
begin
  select id into v_marca from marcas where celular = v_celular_marca;

  if v_marca is null then
    raise exception
      'No encontré ninguna marca con el celular %. Regístrala primero desde el panel de la marca.',
      v_celular_marca;
  end if;

  -- Si ya corriste esto antes, se limpia primero para no duplicar.
  delete from presentaciones
   where producto_id in (select id from productos
                          where marca_id = v_marca and nombre like '%(prueba)');
  delete from productos
   where marca_id = v_marca and nombre like '%(prueba)';

  -- -------------------------------------------------------------------------
  -- Categoría 1 · Cuidado personal
  -- -------------------------------------------------------------------------
  insert into productos (marca_id, nombre, nombre_comprobante, categoria, emoji,
                         descripcion, recomendaciones, tiempo_prep, cobertura,
                         corte_nacional, corte_local, dias_despacho, estado, activo)
       values (v_marca, 'Sérum facial de vitamina C (prueba)', 'Serum facial 30ml',
               'Cuidado personal', '🧴',
               'Producto de prueba para ver el recorrido completo de venta. No es un producto real.',
               'Guardar en lugar fresco y sin sol directo.',
               '24 horas', 'Nacional', '15:00', '18:00', 'Lunes a sábado', 'aprobado', true)
    returning id into v_prod;
  insert into presentaciones (producto_id, nombre, precio_mayorista, precio_publico, stock_almacen, stock_punto) values
    (v_prod, 'Frasco 30 ml',  45.00,  89.00, 40, 12),
    (v_prod, 'Frasco 50 ml',  68.00, 129.00, 25,  8);

  insert into productos (marca_id, nombre, nombre_comprobante, categoria, emoji,
                         descripcion, recomendaciones, tiempo_prep, cobertura,
                         corte_nacional, corte_local, dias_despacho, estado, activo)
       values (v_marca, 'Protector solar SPF 50 (prueba)', 'Protector solar 60ml',
               'Cuidado personal', '☀️',
               'Producto de prueba para ver el recorrido completo de venta. No es un producto real.',
               'No exponer el envase al calor durante el traslado.',
               'Mismo día', 'Nacional', '15:00', '18:00', 'Lunes a sábado', 'aprobado', true)
    returning id into v_prod;
  insert into presentaciones (producto_id, nombre, precio_mayorista, precio_publico, stock_almacen, stock_punto) values
    (v_prod, 'Tubo 60 ml',   32.00,  69.00, 60, 20),
    (v_prod, 'Pack x2',      58.00, 125.00, 18,  6);

  -- -------------------------------------------------------------------------
  -- Categoría 2 · Accesorios
  -- -------------------------------------------------------------------------
  insert into productos (marca_id, nombre, nombre_comprobante, categoria, emoji,
                         descripcion, recomendaciones, tiempo_prep, cobertura,
                         corte_nacional, corte_local, dias_despacho, estado, activo)
       values (v_marca, 'Termo de acero 750 ml (prueba)', 'Termo acero 750ml',
               'Accesorios', '🥤',
               'Producto de prueba para ver el recorrido completo de venta. No es un producto real.',
               'Embalar con burbuja: el acabado se raya.',
               '24 horas', 'Nacional', '14:00', '18:00', 'Lunes a viernes', 'aprobado', true)
    returning id into v_prod;
  insert into presentaciones (producto_id, nombre, precio_mayorista, precio_publico, stock_almacen, stock_punto) values
    (v_prod, 'Negro',  55.00, 110.00, 30, 10),
    (v_prod, 'Blanco', 55.00, 110.00, 22,  7);

  insert into productos (marca_id, nombre, nombre_comprobante, categoria, emoji,
                         descripcion, recomendaciones, tiempo_prep, cobertura,
                         corte_nacional, corte_local, dias_despacho, estado, activo)
       values (v_marca, 'Mochila urbana 20 L (prueba)', 'Mochila urbana 20L',
               'Accesorios', '🎒',
               'Producto de prueba para ver el recorrido completo de venta. No es un producto real.',
               'Sin recomendaciones especiales de traslado.',
               '48 horas', 'Nacional', '14:00', '18:00', 'Lunes a viernes', 'aprobado', true)
    returning id into v_prod;
  insert into presentaciones (producto_id, nombre, precio_mayorista, precio_publico, stock_almacen, stock_punto) values
    (v_prod, 'Talla única gris',  98.00, 189.00, 14, 4),
    (v_prod, 'Talla única negro', 98.00, 189.00, 11, 3);

  -- -------------------------------------------------------------------------
  -- Categoría 3 · Hogar
  -- -------------------------------------------------------------------------
  insert into productos (marca_id, nombre, nombre_comprobante, categoria, emoji,
                         descripcion, recomendaciones, tiempo_prep, cobertura,
                         corte_nacional, corte_local, dias_despacho, estado, activo)
       values (v_marca, 'Difusor de aromas (prueba)', 'Difusor de aromas',
               'Hogar', '🕯️',
               'Producto de prueba para ver el recorrido completo de venta. No es un producto real.',
               'Frágil: va en caja rígida.',
               '24 horas', 'Nacional', '15:00', '18:00', 'Lunes a sábado', 'aprobado', true)
    returning id into v_prod;
  insert into presentaciones (producto_id, nombre, precio_mayorista, precio_publico, stock_almacen, stock_punto) values
    (v_prod, 'Modelo mesa',  72.00, 149.00, 16, 5),
    (v_prod, 'Modelo pared', 85.00, 169.00,  9, 3);

  insert into productos (marca_id, nombre, nombre_comprobante, categoria, emoji,
                         descripcion, recomendaciones, tiempo_prep, cobertura,
                         corte_nacional, corte_local, dias_despacho, estado, activo)
       values (v_marca, 'Juego de toallas (prueba)', 'Juego de toallas x3',
               'Hogar', '🧺',
               'Producto de prueba para ver el recorrido completo de venta. No es un producto real.',
               'Sin recomendaciones especiales de traslado.',
               'Mismo día', 'Nacional', '15:00', '18:00', 'Lunes a sábado', 'aprobado', true)
    returning id into v_prod;
  insert into presentaciones (producto_id, nombre, precio_mayorista, precio_publico, stock_almacen, stock_punto) values
    (v_prod, 'Juego x3 beige', 60.00, 119.00, 20, 6),
    (v_prod, 'Juego x3 gris',  60.00, 119.00, 20, 6);

  raise notice 'Listo: 6 productos de prueba con 12 presentaciones colgados de la marca %.', v_marca;
end $$;

-- ---------------------------------------------------------------------------
-- Comprobar que quedó
-- ---------------------------------------------------------------------------
select p.categoria, p.nombre, pr.nombre as presentacion,
       pr.precio_publico, pr.stock_almacen, pr.stock_punto
  from productos p
  join presentaciones pr on pr.producto_id = p.id
 where p.nombre like '%(prueba)'
 order by p.categoria, p.nombre, pr.nombre;


-- ===========================================================================
-- PARA BORRARLO TODO cuando ya no lo necesites
-- ---------------------------------------------------------------------------
-- Quita los dos guiones del principio de estas líneas y pulsa Run.
--
-- Ojo: si ya hay pedidos hechos contra estos productos, el borrado va a fallar
-- porque un pedido entregado no puede quedarse sin su presentación. En ese caso
-- basta con despublicarlos, que es la segunda opción.
-- ===========================================================================

-- delete from presentaciones
--  where producto_id in (select id from productos where nombre like '%(prueba)');
-- delete from productos where nombre like '%(prueba)';

-- Despublicar en vez de borrar (deja el histórico intacto):
-- update productos set activo = false where nombre like '%(prueba)';
