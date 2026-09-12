#!/usr/bin/env python3
"""
Saca el catálogo de Lab Péptidos de app/vendedor.html y lo convierte en SQL
para las tablas 'marcas', 'productos' y 'presentaciones'.

El catálogo hoy vive incrustado en el JavaScript del panel del vendedor. Este
script lo lee de ahí — no hay que copiar nada a mano — y produce dos cosas:

  1. presentaciones-precios.csv  · plantilla con las 64 presentaciones para que
                                   Jason complete el PRECIO MAYORISTA de cada una.
                                   Ese dato no existe en el HTML: solo lo tiene él.

  2. seed-lab-peptidos.sql       · los INSERT listos para pegar en Supabase.

Uso:
    # 1) generar la plantilla de precios
    python3 extraer-catalogo.py --plantilla

    # 2) con los precios reales ya completados en el CSV
    python3 extraer-catalogo.py --sql --marca-id <uuid> --desde-csv presentaciones-precios.csv

    # 2-bis) o con precios PROVISIONALES, solo para probar que todo funciona
    python3 extraer-catalogo.py --sql --marca-id <uuid> --margen 0.30
"""

import argparse, csv, json, pathlib, sys, uuid

RAIZ = pathlib.Path(__file__).resolve().parents[2]
FUENTE = RAIZ / "app" / "vendedor.html"
AQUI = pathlib.Path(__file__).resolve().parent

# Espacio de nombres fijo: el id de cada producto sale siempre igual, así el
# seed se puede volver a aplicar tras un reinicio sin que cambien las claves.
NS = uuid.UUID("6f1b6c6e-5f1e-4a5b-9c3d-0a1b2c3d4e5f")


def bloque(texto: str, marcador: str, cierre: str):
    """Extrae un literal JSON del JavaScript, por su declaración."""
    i = texto.index(marcador)
    j = texto.index(cierre, i)
    return json.loads(texto[i + len(marcador): j + len(cierre) - 1])


def leer_catalogo():
    t = FUENTE.read_text()
    productos = bloque(t, "const productos = ", "\n];")
    fichas = bloque(t, "const FICHAS = ", "\n};")
    return productos, fichas


def q(v):
    """Literal SQL: escapa comillas simples, o NULL si no hay valor."""
    if v is None or v == "":
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


def id_producto(p):
    return uuid.uuid5(NS, f"{p['marca']}:{p['id']}:{p['nombre']}")


def id_presentacion(p, v):
    return uuid.uuid5(NS, f"{p['marca']}:{p['id']}:{p['nombre']}:{v['pres']}")


def generar_plantilla(productos):
    destino = AQUI / "presentaciones-precios.csv"
    filas = 0
    with destino.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["producto", "presentacion", "precio_publico", "precio_mayorista"])
        for p in productos:
            for v in p["variantes"]:
                w.writerow([p["nombre"], v["pres"], v["sug"], ""])
                filas += 1
    print(f"✅ {destino.name}: {filas} presentaciones por completar")
    print("   Rellena la columna precio_mayorista y vuelve a correr el script con --sql.")


def cargar_precios(ruta):
    """Lee el CSV completado. Devuelve {(producto, presentacion): mayorista}."""
    precios, faltan, malos = {}, [], []
    with open(ruta, newline="", encoding="utf-8") as fh:
        for fila in csv.DictReader(fh):
            clave = (fila["producto"], fila["presentacion"])
            crudo = (fila.get("precio_mayorista") or "").strip()
            if not crudo:
                faltan.append(clave)
                continue
            try:
                may = float(crudo.replace(",", "."))
            except ValueError:
                malos.append((clave, crudo))
                continue
            pub = float(fila["precio_publico"])
            # La base rechaza precio_publico <= precio_mayorista: sin margen no
            # hay nada que repartir entre el socio y SOCIO.
            if may >= pub:
                malos.append((clave, f"{may} ≥ precio público {pub}"))
                continue
            precios[clave] = may
    return precios, faltan, malos


def generar_sql(productos, fichas, marca_id, precios, margen):
    L = []
    a = L.append
    a("-- ============================================================================")
    a("-- Catálogo de Lab Péptidos · generado por extraer-catalogo.py")
    a("-- NO editar a mano: se regenera desde app/vendedor.html")
    a("-- ============================================================================")
    if margen is not None:
        a("--")
        a(f"-- ⚠️  PRECIOS MAYORISTAS PROVISIONALES (precio público − {margen:.0%}).")
        a("--     Son inventados, sirven solo para probar que el circuito funciona.")
        a("--     Reemplázalos por los reales antes de vender nada:")
        a("--     completa presentaciones-precios.csv y regenera con --desde-csv.")
        a("--")
    a("")
    a("begin;")
    a("")
    a("-- La marca. El id debe ser el MISMO que Supabase Auth le dio a su cuenta,")
    a("-- o las reglas de permisos no la dejarán ver su propio catálogo.")
    a("insert into marcas (id, nombre, ruc, giro, ciudad_almacen, ciudad_punto,")
    a("                    celular, clave_hash, nivel_fiabilidad)")
    a("values (")
    a(f"  {q(marca_id)},")
    a("  'Lab Péptidos Perú',")
    a("  '00000000000',            -- ⚠️ RUC real de la marca")
    a("  'Salud · Bienestar · Cuidado de la piel',")
    a("  'Cusco',                  -- almacén")
    a("  'Lima',                   -- ciudad con entrega a domicilio")
    a("  '000000000',              -- ⚠️ celular real de la marca")
    a("  'gestionado_por_supabase_auth',  -- la clave vive en Auth, no aquí")
    a("  'nueva'")
    a(")")
    a("on conflict (id) do nothing;")
    a("")

    n_pres = 0
    sin_precio = []
    for p in productos:
        # docs/10: ningún producto puede publicarse sin precio. Si ninguna de sus
        # presentaciones tiene mayorista, el producto entero queda fuera del seed
        # en vez de publicarse vacío.
        vendibles = [
            v for v in p["variantes"]
            if precios is None or (p["nombre"], v["pres"]) in precios
        ]
        if not vendibles:
            sin_precio.append(p["nombre"])
            continue

        pid = id_producto(p)
        ficha = fichas.get(str(p["id"]), {})
        desc = ficha.get("desc") or p.get("det")
        a(f"-- {p['nombre']} · {p.get('categoria','')}")
        a("insert into productos (id, marca_id, nombre, categoria, emoji, descripcion,")
        a("                       estado, activo)")
        a(f"values ({q(pid)}, {q(marca_id)}, {q(p['nombre'])}, {q(p.get('categoria'))},")
        a(f"        {q(p.get('emoji') or '📦')}, {q(desc)}, 'aprobado', true)")
        a("on conflict (id) do nothing;")
        for v in vendibles:
            vid = id_presentacion(p, v)
            pub = float(v["sug"])
            if precios is not None:
                may = precios[(p["nombre"], v["pres"])]
            else:
                may = round(pub * (1 - margen), 2)
            stock = v.get("stock") or {}
            alm = stock.get("cusco") or 0
            pto = stock.get("lima") or 0
            a("insert into presentaciones (id, producto_id, nombre, precio_mayorista,")
            a("                            precio_publico, stock_almacen, stock_punto)")
            a(f"values ({q(vid)}, {q(pid)}, {q(v['pres'])}, {may:.2f}, {pub:.2f}, {alm}, {pto})")
            a("on conflict (id) do nothing;")
            n_pres += 1
        a("")

    a("commit;")
    destino = AQUI / "seed-lab-peptidos.sql"
    destino.write_text("\n".join(L) + "\n", encoding="utf-8")
    n_prod = len(productos) - len(sin_precio)
    print(f"✅ {destino.name}: 1 marca · {n_prod} productos · {n_pres} presentaciones")
    if sin_precio:
        print(f"   ⚠️  {len(sin_precio)} productos quedaron fuera por no tener ninguna")
        print("      presentación con precio (docs/10: nada se publica sin precio).")
    return n_pres


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--plantilla", action="store_true",
                    help="genera el CSV de precios para completar")
    ap.add_argument("--sql", action="store_true", help="genera el seed SQL")
    ap.add_argument("--marca-id", help="uuid de la cuenta de la marca en Supabase Auth")
    ap.add_argument("--desde-csv", help="CSV con los precios mayoristas reales")
    ap.add_argument("--margen", type=float,
                    help="margen PROVISIONAL (0.30 = mayorista 30%% por debajo del público)")
    args = ap.parse_args()

    if not args.plantilla and not args.sql:
        ap.error("elige --plantilla o --sql")

    productos, fichas = leer_catalogo()
    print(f"Leído de {FUENTE.relative_to(RAIZ)}: {len(productos)} productos, "
          f"{sum(len(p['variantes']) for p in productos)} presentaciones\n")

    if args.plantilla:
        generar_plantilla(productos)
        return

    if not args.marca_id:
        ap.error("--sql necesita --marca-id (el uuid de la cuenta de la marca en Auth)")
    try:
        uuid.UUID(args.marca_id)
    except ValueError:
        ap.error(f"--marca-id no es un uuid válido: {args.marca_id}")

    if bool(args.desde_csv) == bool(args.margen is not None):
        ap.error("elige --desde-csv (precios reales) o --margen (provisionales), no ambos")

    precios = None
    if args.desde_csv:
        precios, faltan, malos = cargar_precios(args.desde_csv)
        if malos:
            print("❌ Precios que la base rechazaría:")
            for (prod, pres), motivo in malos:
                print(f"   · {prod} — {pres}: {motivo}")
            sys.exit(1)
        if faltan:
            print(f"⚠️  {len(faltan)} presentaciones sin precio mayorista; quedan fuera del seed:")
            for prod, pres in faltan[:10]:
                print(f"   · {prod} — {pres}")
            if len(faltan) > 10:
                print(f"   · … y {len(faltan)-10} más")
            print()

    generar_sql(productos, fichas, args.marca_id, precios, args.margen)


if __name__ == "__main__":
    main()
