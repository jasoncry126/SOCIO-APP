-- =============================================================================
-- SOCIO · Permisos para que la app pueda operar
--
-- docs/13 define quién puede LEER cada tabla, pero no quién puede ESCRIBIR.
-- En Supabase, con RLS activo, lo que no está permitido queda prohibido: sin
-- estas reglas una marca no puede registrarse, un socio no puede registrarse
-- ni crear un pedido, y despachar no hace nada (0 filas, sin error).
--
-- Esta migración añade únicamente los permisos de escritura que el circuito de
-- venta necesita, y de paso cierra las tres brechas anotadas en el README:
--   · las 6 tablas que quedaban sin RLS,
--   · el precio mayorista visible para el socio (CLAUDE.md regla nº 1),
--   · la bitácora, que cualquiera podía borrar.
--
-- Principio: cada quien escribe solo lo suyo. Nada aquí amplía lo que alguien
-- puede ver más allá de lo que docs/13 ya permitía.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · Cuentas: cada quien crea y edita su propia ficha
-- ---------------------------------------------------------------------------

-- El id de la fila debe ser el id de la cuenta en Supabase Auth: así nadie
-- puede registrarse haciéndose pasar por otro.
create policy "socio crea su propio perfil"
  on usuarios_socios for insert
  with check (auth.uid() = id);

create policy "marca crea su propio perfil"
  on marcas for insert
  with check (auth.uid() = id);

create policy "marca edita su propio perfil"
  on marcas for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Editar "su propio perfil" no puede incluir su propia calificación.
--
-- Los permisos por fila dicen QUÉ FILA se puede tocar, no qué columnas. Sin lo
-- de abajo, un socio podría ponerse nivel 'diamante' y cobrar 20% en vez de
-- 10%, y una marca podría ponerse 'aliada' y cobrar el 100% por adelantado en
-- vez de 70/30. Ambas cosas se probaron y funcionaban.
--
-- CLAUDE.md regla nº 5: el nivel sube por ventas entregadas, no a mano. Quien
-- lo sube es el trigger de la sección 7, que corre con permisos propios.
--
-- Postgres no deja quitar columnas de un permiso dado sobre la tabla entera:
-- hay que retirar el permiso de actualizar y volver a darlo solo sobre las
-- columnas que sí son del dueño.

revoke update on usuarios_socios from anon, authenticated;
grant update (nombre, ciudad) on usuarios_socios to authenticated;

revoke update on marcas from anon, authenticated;
grant update (nombre, giro, ciudad_almacen, ciudad_punto) on marcas to authenticated;

-- ---------------------------------------------------------------------------
-- 2 · Catálogo: la marca gestiona el suyo; el socio ve precios de venta
-- ---------------------------------------------------------------------------

alter table presentaciones enable row level security;

-- Solo la marca dueña toca sus presentaciones. Incluye el precio mayorista,
-- que es suyo.
create policy "marca gestiona las presentaciones de su catálogo"
  on presentaciones for all
  using (exists (select 1 from productos p
                  where p.id = producto_id and p.marca_id = auth.uid()))
  with check (exists (select 1 from productos p
                       where p.id = producto_id and p.marca_id = auth.uid()));

-- CLAUDE.md regla nº 1: el socio NUNCA ve el precio mayorista. Hasta ahora eso
-- lo cuidaba la pantalla; aquí lo cuida la base. El socio no lee la tabla:
-- lee esta vista, que sencillamente no tiene esa columna.
create view catalogo_publico as
  select pr.id,
         pr.producto_id,
         pr.nombre           as presentacion,
         pr.precio_publico,
         pr.stock_almacen,
         pr.stock_punto,
         p.marca_id,
         p.nombre            as producto,
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
   where p.estado = 'aprobado'
     and p.activo = true;

grant select on catalogo_publico to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3 · Pedidos: el socio los crea, la marca los despacha
-- ---------------------------------------------------------------------------

create policy "socio registra sus pedidos"
  on pedidos for insert
  with check (socio_id = auth.uid());

-- La marca puede mover el estado y poner la guía de sus propios pedidos.
create policy "marca actualiza los pedidos de su catálogo"
  on pedidos for update
  using (marca_id = auth.uid())
  with check (marca_id = auth.uid());

alter table pedido_items enable row level security;

create policy "ver los items de un pedido que ya puedo ver"
  on pedido_items for select
  using (exists (select 1 from pedidos p
                  where p.id = pedido_id
                    and (p.socio_id = auth.uid() or p.marca_id = auth.uid())));

create policy "socio agrega los items de su pedido"
  on pedido_items for insert
  with check (exists (select 1 from pedidos p
                       where p.id = pedido_id and p.socio_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 4 · Pagos: el socio declara el suyo; la marca ve si le pagaron
-- ---------------------------------------------------------------------------

alter table pagos enable row level security;

create policy "socio ve el pago de su pedido"
  on pagos for select
  using (exists (select 1 from pedidos p
                  where p.id = pedido_id and p.socio_id = auth.uid()));

create policy "socio declara el pago de su pedido"
  on pagos for insert
  with check (exists (select 1 from pedidos p
                       where p.id = pedido_id and p.socio_id = auth.uid()));

-- La marca necesita saber si el pedido está pagado antes de despachar, pero no
-- puede tocar el pago: validarlo es trabajo de SOCIO.
create policy "marca ve el pago de sus pedidos"
  on pagos for select
  using (exists (select 1 from pedidos p
                  where p.id = pedido_id and p.marca_id = auth.uid()));

-- Nadie edita un pago desde la app: no hay política de update. La validación la
-- hace SOCIO desde el panel de administración (ver sección 6).

-- ---------------------------------------------------------------------------
-- 5 · Dinero: cada quien ve lo suyo
-- ---------------------------------------------------------------------------

alter table liberaciones_dinero enable row level security;

create policy "marca ve su propio dinero liberado"
  on liberaciones_dinero for select
  using (marca_id = auth.uid());

alter table retiros enable row level security;

create policy "cada quien ve sus propios retiros"
  on retiros for select
  using (marca_id = auth.uid() or socio_id = auth.uid());

create policy "cada quien solicita su propio retiro"
  on retiros for insert
  with check (marca_id = auth.uid() or socio_id = auth.uid());

-- Quién libera el dinero y quién marca un retiro como transferido es SOCIO, no
-- la marca: sin política de insert/update, desde la app queda prohibido.

-- ---------------------------------------------------------------------------
-- 6 · Bitácora: solo se escribe, nunca se edita ni se borra
-- ---------------------------------------------------------------------------

alter table bitacora enable row level security;

create policy "cualquiera con sesión deja constancia"
  on bitacora for insert
  with check (auth.uid() is not null);

-- Sin política de select, update ni delete: desde la app la bitácora es un
-- buzón de una sola dirección. Esto es lo que la regla nº 4 de docs/13 pedía y
-- que la línea comentada 'revoke update, delete' no llegaba a hacer.
revoke update, delete on bitacora from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7 · El trigger de niveles necesita permiso propio
-- ---------------------------------------------------------------------------
--
-- actualizar_nivel_socio() corre con los permisos de QUIEN dispara el update.
-- Quien confirma una entrega es la marca, y la marca no puede tocar la ficha
-- del socio: el update afectaba 0 filas y el nivel nunca subía. Sin error, en
-- silencio — el peor tipo de fallo.
--
-- 'security definer' hace que la función corra con los permisos de su dueño,
-- que es justo lo que necesita: es la plataforma quien sube el nivel, no la
-- marca. El cuerpo es idéntico al de docs/13; lo único que cambia es bajo qué
-- permisos se ejecuta.
--
-- 'set search_path' fija dónde busca las tablas, para que nadie pueda colarle
-- una tabla falsa a una función con permisos elevados.

create or replace function actualizar_nivel_socio()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado = 'entregado' and old.estado != 'entregado' then
    update usuarios_socios
    set ventas_entregadas = ventas_entregadas + 1,
        nivel = case
          when ventas_entregadas + 1 >= 50 then 'diamante'
          when ventas_entregadas + 1 >= 25 then 'oro'
          when ventas_entregadas + 1 >= 10 then 'plata'
          else 'bronce'
        end
    where id = new.socio_id;
  end if;
  return new;
end;
$$;

commit;
