-- ===========================================================================
-- Las fotos del catálogo
-- ===========================================================================
--
-- Hasta ahora la base no guardaba ninguna foto de producto. Las 64 que hay en
-- el repositorio (`app/imagenes/`) viven dentro de `app/vendedor.html`, escritas
-- a mano junto al catálogo, así que solo las ve esa pantalla y solo sirven para
-- esa marca. Cualquier otra app —la de React, el panel de la marca, lo que
-- venga— enseña un emoji donde debería ir la foto del producto.
--
-- Esto lo arregla en el sitio donde tiene que estar arreglado: la base. Una
-- columna por presentación, un cubo donde viven los archivos, y la vista que el
-- socio ya lee devolviendo también la foto.
--
-- Es genérico a propósito: cada marca sube las suyas a su propia carpeta. No hay
-- nada aquí que sepa de péptidos ni de Lab Péptidos.

begin;

-- ---------------------------------------------------------------------------
-- 1 · Dónde se apunta la foto
-- ---------------------------------------------------------------------------
--
-- Va en `presentaciones`, no en `productos`, porque es donde está el dato real:
-- el vial de 5 mg y el de 10 mg del mismo producto son dos fotos distintas. Una
-- marca que tenga una sola foto por producto la repite en sus presentaciones, y
-- la pantalla del catálogo toma la de la primera.
--
-- Guarda una RUTA dentro del cubo `catalogo` (`<marca_id>/archivo.webp`), no una
-- URL entera: la URL lleva dentro el identificador del proyecto Supabase, así
-- que guardarla ataría el catálogo a un proyecto concreto y habría que reescribir
-- 47 filas al migrar. La app arma la URL pública al pintar.
--
-- Se admite también una URL https completa, para la marca que ya tenga sus fotos
-- publicadas en su propia web y no quiera volver a subirlas.

alter table presentaciones
  add column if not exists imagen text;

comment on column presentaciones.imagen is
  'Ruta dentro del cubo `catalogo` (<marca_id>/archivo.webp), o una URL https completa si la marca aloja la foto fuera. Vacío = la pantalla enseña el emoji del producto.';

-- ---------------------------------------------------------------------------
-- 2 · El cubo donde viven los archivos
-- ---------------------------------------------------------------------------
--
-- PÚBLICO, a diferencia de `guias` y `vouchers`, que son privados. La razón es
-- que aquí no hay nada que proteger: es la foto del producto que la marca quiere
-- que se venda, y sale en la misma vista que ya está concedida a `anon`. Un
-- enlace firmado que caduca a los diez minutos obligaría a refirmar 47 fotos
-- cada vez que alguien abre el catálogo.
--
-- Si más adelante se decide que el catálogo solo se vea con cuenta (la decisión
-- pendiente sobre `catalogo_publico` y `anon`), este cubo tendría que volverse
-- privado a la vez. Las dos cosas van juntas o no sirve de nada.
--
-- Convención de ruta:  catalogo/<marca_id>/<archivo>
-- La primera carpeta es el id de la marca, igual que en `guias`, y en eso se
-- apoyan las reglas: una marca solo escribe dentro de su propia carpeta.
--
-- El bloque va condicionado a que exista el esquema 'storage', para que la
-- migración se pueda probar en un Postgres normal, donde no existe.

do $$
begin
  if to_regclass('storage.objects') is null then
    raise notice 'Sin esquema storage (esto no es Supabase): se omite el cubo del catálogo.';
    return;
  end if;

  insert into storage.buckets (id, name, public)
       values ('catalogo', 'catalogo', true)
  on conflict (id) do update set public = true;

  -- La marca sube las fotos de su catálogo dentro de su propia carpeta.
  execute $p$
    create policy "marca sube las fotos de su catalogo"
      on storage.objects for insert to authenticated
      with check (bucket_id = 'catalogo'
                  and (storage.foldername(name))[1] = auth.uid()::text)
  $p$;

  -- Y puede reemplazarlas: una foto del catálogo no es evidencia de nada, a
  -- diferencia de la guía de un despacho o de la captura de un depósito. Que la
  -- marca mejore la foto de su producto es justo lo que queremos que pase.
  execute $p$
    create policy "marca reemplaza las fotos de su catalogo"
      on storage.objects for update to authenticated
      using (bucket_id = 'catalogo'
             and (storage.foldername(name))[1] = auth.uid()::text)
      with check (bucket_id = 'catalogo'
                  and (storage.foldername(name))[1] = auth.uid()::text)
  $p$;

  execute $p$
    create policy "marca borra las fotos de su catalogo"
      on storage.objects for delete to authenticated
      using (bucket_id = 'catalogo'
             and (storage.foldername(name))[1] = auth.uid()::text)
  $p$;

  -- SOCIO entra a todas: es quien aprueba el producto antes de publicarlo, y
  -- para eso tiene que poder mirar la foto que la marca subió.
  execute $p$
    create policy "SOCIO ve todas las fotos del catalogo"
      on storage.objects for select to authenticated
      using (bucket_id = 'catalogo' and es_admin())
  $p$;
exception
  when duplicate_object then
    raise notice 'Las reglas del cubo del catálogo ya existían: se dejan como están.';
end $$;

-- ---------------------------------------------------------------------------
-- 3 · La vista del socio, con la foto
-- ---------------------------------------------------------------------------
--
-- Se parte de la última definición de `catalogo_publico`
-- (20260919120000_marca_en_el_catalogo.sql) y se le añade una columna al final.
-- Ojo: esta vista está definida en tres migraciones distintas y cada
-- `create or replace` la reescribe ENTERA. Copiar una versión vieja borraría en
-- silencio las columnas de la marca que añadió la última.
--
-- Lo que sigue sin entrar: el precio mayorista, que no tiene columna aquí y no
-- puede tenerla (regla 1 de CLAUDE.md).

create or replace view catalogo_publico as
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
         p.dias_despacho,
         pr.imagen
    from presentaciones pr
    join productos p on p.id = pr.producto_id
    join marcas    m on m.id = p.marca_id
   where p.estado = 'aprobado'
     and p.activo = true;

grant select on catalogo_publico to anon, authenticated;

commit;
