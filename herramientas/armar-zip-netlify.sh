#!/usr/bin/env bash
# ===========================================================================
# SOCIO · Arma el zip que se arrastra a Netlify
# ---------------------------------------------------------------------------
# Netlify publica lo que le sueltes tal cual. Este guion junta SOLO lo que el
# sitio necesita para funcionar —las tres pantallas, sus scripts, las fotos y
# los íconos— y deja fuera lo que no tiene por qué estar publicado: la
# documentación, las migraciones de la base, las pruebas y el historial de git.
#
#   bash herramientas/armar-zip-netlify.sh
#
# Deja dos paquetes en dist/
#   socio-netlify.zip            ← se arrastra a Netlify
#   socio-sql-para-supabase.zip  ← se pega en el SQL Editor de Supabase
# ===========================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SALIDA="$RAIZ/dist"
CARPETA="$SALIDA/socio-netlify"
ZIP="$SALIDA/socio-netlify.zip"

rm -rf "$CARPETA" "$ZIP"
mkdir -p "$CARPETA/app"

# La raíz del sitio
cp "$RAIZ/index.html"    "$CARPETA/"
cp "$RAIZ/manifest.json" "$CARPETA/"
cp "$RAIZ/sw.js"         "$CARPETA/"
cp "$RAIZ/netlify.toml"  "$CARPETA/"
cp -r "$RAIZ/icons"      "$CARPETA/"

# Las tres pantallas y lo que cargan
cp "$RAIZ/app/vendedor.html"      "$CARPETA/app/"
cp "$RAIZ/app/proveedor.html"     "$CARPETA/app/"
cp "$RAIZ/app/administrador.html" "$CARPETA/app/"
cp "$RAIZ/app/socio-config.js"    "$CARPETA/app/"
cp "$RAIZ/app/socio-precios.js"   "$CARPETA/app/"
cp "$RAIZ/app/socio-datos.js"     "$CARPETA/app/"
cp "$RAIZ/app/socio-catalogo.js"  "$CARPETA/app/"
cp -r "$RAIZ/app/imagenes"        "$CARPETA/app/"

# La hoja de ruta, dentro del propio paquete
cp "$RAIZ/docs/17-subir-a-netlify.md" "$CARPETA/LEEME-PRIMERO.md"

# Se comprime el CONTENIDO, sin carpeta que lo envuelva: Netlify publica la
# raíz del zip, así que si index.html quedara dentro de una carpeta el sitio
# abriría en una lista de archivos en vez de en la portada.
( cd "$CARPETA" && zip -qr "$ZIP" . -x ".*" )

# ---------------------------------------------------------------------------
# El segundo paquete: el SQL que hay que pegar en Supabase.
# Va aparte a propósito. Estos archivos no tienen por qué estar publicados en
# el sitio, y Jason los necesita en el navegador, no en el servidor.
# ---------------------------------------------------------------------------
SQLDIR="$SALIDA/socio-sql"
ZIPSQL="$SALIDA/socio-sql-para-supabase.zip"
rm -rf "$SQLDIR" "$ZIPSQL"
mkdir -p "$SQLDIR"

# Las cinco migraciones que faltan por aplicar, numeradas en el orden en que van.
i=1
for m in 20260921120000_stock_voucher_e_indices \
         20260921140000_el_deposito_y_su_captura \
         20260921160000_la_marca_despacha_y_el_socio_confirma \
         20260921170000_el_nivel_baja_si_baja_el_ritmo \
         20260921180000_las_fotos_del_catalogo; do
  cp "$RAIZ/supabase/migrations/$m.sql" "$SQLDIR/$i-$m.sql"
  i=$((i + 1))
done

cp "$RAIZ/supabase/verificacion/comprobar-en-supabase.sql" "$SQLDIR/6-comprobar-que-quedo-bien.sql"
cp "$RAIZ/supabase/datos/datos-de-prueba.sql"              "$SQLDIR/7-datos-de-prueba.sql"
cp "$RAIZ/docs/17-subir-a-netlify.md"                      "$SQLDIR/LEEME-PRIMERO.md"

( cd "$SQLDIR" && zip -qr "$ZIPSQL" . -x ".*" )

echo "Listo:"
echo "  $ZIP"
echo "    $(find "$CARPETA" -type f | wc -l) archivos · $(du -sh "$ZIP" | cut -f1)"
echo "  $ZIPSQL"
echo "    $(find "$SQLDIR" -type f | wc -l) archivos · $(du -sh "$ZIPSQL" | cut -f1)"
