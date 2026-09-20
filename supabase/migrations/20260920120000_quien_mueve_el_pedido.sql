-- =============================================================================
-- SOCIO · Quién puede mover un pedido, y qué ve el socio del dinero de la marca
--
-- La revisión de los permisos por fila encontró seis huecos. Esta migración
-- cierra los dos que tocan dinero; los otros cuatro quedan para una segunda,
-- porque son de otro orden y conviene mirarlos con calma.
--
--   1 · UNA MARCA PODÍA DARSE POR PAGADA SOLA Y COBRAR.
--       La marca tiene permiso de escribir 'estado' en SUS pedidos, y el
--       candado de estados comprobaba el ORDEN de la transición pero no QUIÉN
--       la hacía. Con eso recorría ella sola el camino entero —pendiente_pago
--       → pagado → validado → en_camino → entregado— y al llegar al final se
--       liquidaba su precio mayorista íntegro, sin que existiera ningún pago
--       ni ningún administrador de SOCIO de por medio.
--
--       Probado contra PostgreSQL 16: pedido de S/ 180, cero filas en 'pagos',
--       S/ 100 liberados a la marca y una venta entregada sumada al socio.
--
--       El estado 'validado' se creó justamente para esto (4ª migración): a
--       partir de ella 'pagado' significa «el vendedor dice que pagaron» y
--       'validado' es el permiso para despachar, que otorga SOCIO tras cruzar
--       el voucher contra el estado de cuenta. Eso era la intención; abajo
--       pasa a ser la regla.
--
--   2 · EL SOCIO PODÍA DEDUCIR EL PRECIO MAYORISTA Y LA COMISIÓN DE SOCIO.
--       Se le dejó leer las liquidaciones de sus propios pedidos para que
--       supiera si ya estaban cerrados. Pero esas filas llevan el MONTO, y la
--       suma de los dos hitos es el precio mayorista exacto de la marca;
--       restándolo de lo que él transfiere sale la comisión de la plataforma.
--
--       Probado: mayorista real S/ 100.00, el socio leyó S/ 100.00.
--
--       Es la regla nº 1 de CLAUDE.md, la misma que las vistas 'pedidos_socio'
--       y 'pedido_items_socio' se esmeran en sostener columna por columna.
--
-- Ninguno de los dos cambios toca lo que las tres pantallas hacen hoy: ni el
-- panel de la marca ni el de SOCIO escriben estados desde el navegador, y
-- nadie lee 'liberaciones_dinero' desde la app.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · El candado de estados ahora mira también QUIÉN llama
-- ---------------------------------------------------------------------------
--
-- Se conserva entero el cuerpo de la 6ª migración —el orden de los estados y
-- la evidencia obligatoria del despacho— y se le añaden dos comprobaciones de
-- autoría, después de la del orden para que los mensajes de error de siempre
-- no cambien.
--
-- 'pagado': lo pone el trigger trg_pago_registrado cuando el vendedor declara
-- su pago. En vez de intentar adivinar por qué camino vino el cambio, se
-- comprueba el hecho: si un pedido pasa a 'pagado', tiene que existir un pago
-- declarado para él. Y declarar un pago solo se puede por declarar_pago(), que
-- exige que el pedido sea del socio que llama — insertar a mano en 'pagos'
-- está prohibido para todos desde la 7ª migración.
--
-- 'validado': es el permiso para despachar y lo otorga SOCIO, nadie más.
--
-- La función pasa a 'security definer' para que la comprobación del pago sea
-- fiable venga de quien venga: si corriera con los permisos de quien llama,
-- alguien que no puede leer 'pagos' vería cero filas y se le rechazaría un
-- cambio legítimo. 'set search_path' fija dónde busca las tablas, para que
-- nadie pueda colarle una tabla falsa a una función con permisos elevados.

create or replace function pedido_transicion_valida()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  permitidos text[];
begin
  if new.estado = old.estado then
    return new;
  end if;

  permitidos := case old.estado
    when 'pendiente_pago' then array['pagado','cancelado']
    when 'pagado'         then array['validado','cancelado']
    when 'validado'       then array['en_camino','cancelado']
    when 'en_camino'      then array['entregado','cancelado']
    else array[]::text[]
  end;

  if not (new.estado = any (permitidos)) then
    raise exception
      'Un pedido en "%" no puede pasar a "%". Desde "%" solo puede ir a: %',
      old.estado, new.estado, old.estado,
      coalesce(nullif(array_to_string(permitidos, ', '), ''), 'ningún otro estado');
  end if;

  -- Quién puede dar cada paso, no solo en qué orden van.
  if new.estado = 'pagado'
     and not exists (select 1 from pagos pg where pg.pedido_id = new.id) then
    raise exception
      'Un pedido pasa a "pagado" cuando el vendedor declara su pago, no a mano. No hay ningún pago declarado para este pedido.';
  end if;

  if new.estado = 'validado' and not es_admin() then
    raise exception
      'Solo un administrador de SOCIO puede validar un pedido para despacho, después de cruzar el pago contra el estado de cuenta. La marca despacha a partir de ahí, no antes.';
  end if;

  -- Despacho obligatorio con evidencia (manual del contador, PASO 3, y FASE 3
  -- de la especificación técnica).
  if new.estado = 'en_camino' then
    if coalesce(trim(new.numero_guia), '') = '' then
      raise exception
        'Para marcar el pedido como despachado hace falta el número de la guía de remisión.';
    end if;

    if coalesce(trim(new.guia_url), '') = '' then
      raise exception
        'Falta la foto de la guía de remisión. Es obligatoria: es la evidencia de que el paquete salió, y sin ella el pedido no avanza.';
    end if;

    if new.modo_entrega = 'agencia'
       and (coalesce(trim(new.courier), '') = '' or coalesce(trim(new.tracking), '') = '') then
      raise exception
        'En un envío por agencia hacen falta también el courier y el número de tracking. Sin esa evidencia el pedido no avanza.';
    end if;

    new.despachado_en := coalesce(new.despachado_en, now());
  end if;

  if new.estado = 'entregado' then
    new.entregado_en := coalesce(new.entregado_en, now());
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2 · El socio ve SI se liquidó, no CUÁNTO
-- ---------------------------------------------------------------------------
--
-- Lo que el socio necesita saber de la liquidación es si su pedido ya está
-- cerrado y desde cuándo. El importe es lo que la marca cobra por su mercadería
-- y no es asunto suyo — es el mismo número que el resto del sistema le esconde.
--
-- Se retira el permiso sobre la tabla y se le da una vista sin la columna del
-- monto, que es el mismo remedio que ya se usó para el catálogo: el socio no
-- lee 'presentaciones', lee 'catalogo_publico', que sencillamente no tiene la
-- columna del precio mayorista.

drop policy if exists "socio ve las liberaciones de sus pedidos" on liberaciones_dinero;

create or replace view liquidaciones_socio with (security_invoker = false) as
  select l.pedido_id,
         p.codigo,
         l.hito,
         l.liberado_en
    from liberaciones_dinero l
    join pedidos p on p.id = l.pedido_id
   where p.socio_id = auth.uid();

comment on view liquidaciones_socio is
  'Lo que el socio puede saber de la liquidación de sus pedidos: qué hitos se cumplieron y cuándo. Sin el monto, que es el precio mayorista de la marca (CLAUDE.md, regla nº 1).';

grant select on liquidaciones_socio to authenticated;
revoke all on liquidaciones_socio from anon;

commit;
