#!/usr/bin/env bash
# Levanta un Postgres temporal, aplica la migración y corre todas las pruebas.
# No toca ningún Supabase real: es un cluster desechable en un directorio temporal.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
MIG="$AQUI/../migrations/20260912000000_modelo_de_datos_inicial.sql"
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

echo "### Aplicando la migración"
psql -h "$W" -p "$PUERTO" -U postgres -v ON_ERROR_STOP=1 -f "$MIG"

for f in 01-inspeccionar-esquema 02-probar-reglas-negocio 03-probar-aislamiento-rls 04-cobertura-rls-faltante; do
  echo; echo "################ $f ################"
  ejecutar "$AQUI/$f.sql"
done

echo; echo "### Listo. El cluster temporal se elimina al salir."
