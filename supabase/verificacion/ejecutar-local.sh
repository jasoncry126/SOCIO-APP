#!/usr/bin/env bash
# Levanta un Postgres temporal, aplica la migración y corre todas las pruebas.
# No toca ningún Supabase real: es un cluster desechable en un directorio temporal.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
# Las migraciones se descubren solas, en el orden de su fecha. Así una rama que
# añade una migración no choca con otra que añade la suya.
mapfile -t MIGS < <(ls "$AQUI"/../migrations/*.sql | sort)

PGBIN="$(ls -d /usr/lib/postgresql/*/bin | tail -1)"
W="$(mktemp -d)"
PUERTO=5599

limpiar() { "$PGBIN/pg_ctl" -D "$W/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$W"; }
trap limpiar EXIT

"$PGBIN/initdb" -D "$W/data" -U postgres --auth=trust >"$W/initdb.log" 2>&1
"$PGBIN/pg_ctl" -D "$W/data" -l "$W/pg.log" \
  -o "-k $W -p $PUERTO -c listen_addresses=''" -w start >/dev/null

ejecutar() { psql -h "$W" -p "$PUERTO" -U postgres -f "$1"; }

echo "### Stub de lo que Supabase ya provee (auth.uid, roles anon/authenticated)"
ejecutar "$AQUI/00-stub-supabase.sql" >/dev/null

# En Supabase real, anon/authenticated reciben permisos automáticamente sobre
# cada tabla nueva del esquema public. Aquí lo imitamos: primero se crean las
# tablas, luego los permisos amplios, y AL FINAL la 2ª migración, que es la que
# los recorta. Ese orden importa — al revés, los permisos amplios volverían a
# pisar el recorte y el socio podría subirse de nivel a mano.

echo "### Aplicando la 1ª migración (modelo de datos de docs/13)"
psql -h "$W" -p "$PUERTO" -U postgres -q -v ON_ERROR_STOP=1 -f "${MIGS[0]}"

echo "### Permisos por defecto de Supabase para anon/authenticated"
psql -h "$W" -p "$PUERTO" -U postgres -q -v ON_ERROR_STOP=1 \
  -c "grant usage on schema public to anon, authenticated;" \
  -c "grant select, insert, update, delete on all tables in schema public to anon, authenticated;"

for m in "${MIGS[@]:1}"; do
  echo "### Aplicando $(basename "$m")"
  psql -h "$W" -p "$PUERTO" -U postgres -q -v ON_ERROR_STOP=1 -f "$m"
done

for f in 01-inspeccionar-esquema 05-circuito-de-venta 06-ataques 07-administrador 08-estructura-fiscal 09-manual-operativo 10-especificacion-tecnica 11-circuito-de-venta 12-quien-mueve-el-pedido 13-los-otros-cuatro-huecos 14-stock-voucher-e-indices 15-el-deposito-y-su-captura 16-la-marca-despacha-y-el-socio-confirma; do
  echo; echo "################ $f ################"
  ejecutar "$AQUI/$f.sql"
done

echo; echo "################ la base contra app/socio-precios.js ################"
# El cálculo del dinero vive en dos sitios por necesidad. Esto comprueba que
# digan lo mismo, para que una divergencia salte aquí y no en la cuenta de
# alguien.
psql -h "$W" -p "$PUERTO" -U postgres -At -f "$AQUI/comparar-sql-y-js.sql" \
  | NODE_EXTRA_CA_CERTS= node "$AQUI/../../app/pruebas/comparar-con-la-base.js"

echo; echo "### Listo. El cluster temporal se elimina al salir."
