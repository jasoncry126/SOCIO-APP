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

# TODAS las migraciones, numeradas en el orden en que van. Van todas y no solo
# las últimas a propósito: aplicar una de más no hace nada (cada una comprueba
# lo suyo antes de tocar), mientras que saltarse una anterior deja la base a
# medias de una forma que solo se ve al fallar una venta.
i=1
for m in $(ls "$RAIZ/supabase/migrations"/*.sql | sort); do
  printf -v n '%02d' "$i"
  cp "$m" "$SQLDIR/$n-$(basename "$m")"
  i=$((i + 1))
done

# Un solo archivo que lo hace todo, en orden, sin que nadie pueda equivocarse:
# el borrado y detrás las quince migraciones, una tras otra. Es la forma de
# reinstalar cuando la base quedó desordenada — que es justo el estado en el que
# aplicar los archivos sueltos uno por uno vuelve a fallar.
INSTALADOR="$SQLDIR/REINSTALAR-TODO-DE-CERO.sql"
{
  cat <<'CABECERA'
-- =============================================================================
-- ⚠️  REINSTALA LA BASE ENTERA, DESDE CERO Y EN ORDEN
-- -----------------------------------------------------------------------------
-- QUÉ HACE
--   Primero BORRA las once tablas con todo lo que tengan dentro —socios,
--   marcas, productos, pedidos, pagos— y después vuelve a crear la base
--   aplicando las quince migraciones en su orden correcto, de una sentada.
--
--   Se usa cuando la base quedó desordenada: migraciones aplicadas salteadas o
--   fuera de orden. En ese estado, volver a pegar los archivos uno por uno
--   vuelve a fallar; esto lo deja limpio de una vez.
--
-- QUÉ SE PIERDE
--   Todo lo que hayas registrado: cuentas de socio, marcas, catálogo, pedidos.
--   Si alguien ya usó las páginas de verdad, eso desaparece. No se puede
--   deshacer.
--
-- QUÉ NO SE PIERDE
--   Las cuentas de Authentication (los correos y celulares con los que se
--   entra) y los archivos ya subidos a los cubos. Lo único que tendrás que
--   rehacer a mano es la fila de la tabla 'administradores' con tu User UID.
--
-- CÓMO SE USA
--   SQL Editor → New query → pega esto entero → Run. Tarda un poco: son
--   quince migraciones seguidas. Al terminar, corre '00-EMPIEZA-AQUI-que-falta'
--   y tienen que salir las quince en ✅.
-- =============================================================================

CABECERA
  echo "-- ---------------------------------------------------------------------------"
  echo "-- PASO 0 · Borrar lo que haya"
  echo "-- ---------------------------------------------------------------------------"
  cat "$RAIZ/supabase/reiniciar-desde-cero.sql"
  echo
  i=1
  for m in $(ls "$RAIZ/supabase/migrations"/*.sql | sort); do
    echo
    echo "-- ---------------------------------------------------------------------------"
    echo "-- PASO $i de 15 · $(basename "$m" .sql)"
    echo "-- ---------------------------------------------------------------------------"
    cat "$m"
    echo
    i=$((i + 1))
  done
} > "$INSTALADOR"

cp "$RAIZ/supabase/verificacion/comprobar-en-supabase.sql" "$SQLDIR/00-EMPIEZA-AQUI-que-falta.sql"
cp "$RAIZ/supabase/datos/datos-de-prueba.sql"              "$SQLDIR/99-datos-de-prueba.sql"
cp "$RAIZ/docs/17-subir-a-netlify.md"                      "$SQLDIR/LEEME-PRIMERO.md"

( cd "$SQLDIR" && zip -qr "$ZIPSQL" . -x ".*" )

echo "Listo:"
echo "  $ZIP"
echo "    $(find "$CARPETA" -type f | wc -l) archivos · $(du -sh "$ZIP" | cut -f1)"
echo "  $ZIPSQL"
echo "    $(find "$SQLDIR" -type f | wc -l) archivos · $(du -sh "$ZIPSQL" | cut -f1)"
