#!/usr/bin/env python3
"""
Extrae el catálogo de un proveedor desde su propia página web y lo deja listo
para cargarlo en SOCIO.

Fuente: el manifiesto de la web del proveedor (lib/manifest.js), que es donde
la marca mantiene sus productos y sus precios de página. De ahí salen los
cuatro datos que SOCIO necesita de cada presentación:

    imagen · nombre · contexto · precio de página

El precio MAYORISTA no está aquí y no puede estarlo: es el precio al que la
marca le vende a SOCIO, y lo escribe ella misma en su panel (proveedor.html)
o en la columna correspondiente del CSV que este script genera.

Uso:
    # inventario del catálogo: qué hay, qué tiene precio, qué imagen le falta
    python3 extraer-catalogo.py --revisar --sitio ruta/al/sitio

    # CSV con los 4 campos + la columna de precio mayorista para completar
    python3 extraer-catalogo.py --csv --sitio ruta/al/sitio

    # SQL para cargar el catálogo en Supabase
    python3 extraer-catalogo.py --sql --sitio ruta/al/sitio \
        --marca-id <uuid> --desde-csv catalogo-proveedor.csv
"""

import argparse, csv, json, pathlib, re, subprocess, sys, uuid

AQUI = pathlib.Path(__file__).resolve().parent
NS = uuid.UUID("6f1b6c6e-5f1e-4a5b-9c3d-0a1b2c3d4e5f")


# --------------------------------------------------------------------------
# Lectura del manifiesto
# --------------------------------------------------------------------------

def leer_sitio(raiz: pathlib.Path):
    """Evalúa lib/manifest.js con node y devuelve la marca y sus productos."""
    manifest = raiz / "lib" / "manifest.js"
    if not manifest.exists():
        sys.exit(f"❌ No encuentro {manifest}. ¿Es la carpeta del sitio del proveedor?")
    js = (
        "global.window={};"
        f"require({str(manifest)!r});"
        "process.stdout.write(JSON.stringify(window.__BRAND__||{}));"
    )
    try:
        salida = subprocess.run(["node", "-e", js], capture_output=True,
                                text=True, check=True).stdout
    except FileNotFoundError:
        sys.exit("❌ Hace falta node para leer el manifiesto del sitio.")
    except subprocess.CalledProcessError as e:
        sys.exit(f"❌ No pude leer el manifiesto:\n{e.stderr}")
    return json.loads(salida)


def presentaciones(marca, raiz: pathlib.Path):
    """Aplana el catálogo a una fila por presentación, con sus 4 campos."""
    cats = marca.get("categories", {})
    filas = []
    for p in marca.get("products", []):
        claves = ["blend"] if p.get("unit") == "blend" else [
            str(c).replace(".", "_") for c in p.get("conc", [])
        ]
        # La unidad la declara el producto: casi todo va en mg, pero el agua
        # bacteriostática va en ml y los combos no llevan concentración.
        unidad = p.get("unit") or "mg"
        etiquetas = ["Presentación única"] if p.get("unit") == "blend" else [
            f"Vial {c} {unidad}" for c in p.get("conc", [])
        ]
        for clave, etiqueta in zip(claves, etiquetas):
            precio = (p.get("prices") or {}).get(clave)
            img = f"{p.get('img') or p['id']}-{clave}.webp"
            filas.append({
                "producto": p["name"],
                "presentacion": etiqueta,
                "categoria": (cats.get(p.get("cat"), {}) or {}).get("label", ""),
                "contexto": p.get("blurb", ""),
                "imagen": img,
                "imagen_existe": (raiz / "assets" / "img" / "products" / img).exists(),
                "precio_publico": precio,
            })
    return filas


# --------------------------------------------------------------------------
# Modos
# --------------------------------------------------------------------------

def revisar(marca, filas):
    print(f"Marca: {marca.get('name','(sin nombre)')}")
    print(f"Productos: {len({f['producto'] for f in filas})}")
    print(f"Presentaciones: {len(filas)}\n")

    con = [f for f in filas if f["precio_publico"] is not None]
    sin = [f for f in filas if f["precio_publico"] is None]
    print(f"✅ Con precio de página: {len(con)}")
    print(f"⚠️  Sin precio: {len(sin)} — no se pueden publicar (docs/10)")
    for f in sin:
        print(f"     · {f['producto']} — {f['presentacion']}")

    faltan = [f for f in con if not f["imagen_existe"]]
    print(f"\n{'❌' if faltan else '✅'} Imágenes: "
          f"{len(con)-len(faltan)}/{len(con)} presentaciones con precio tienen foto")
    for f in faltan:
        print(f"     · {f['producto']} — {f['presentacion']} → falta {f['imagen']}")

    cats = {}
    for f in con:
        cats[f["categoria"]] = cats.get(f["categoria"], 0) + 1
    print("\nCategorías (solo lo publicable):")
    for c, n in sorted(cats.items(), key=lambda x: -x[1]):
        print(f"     {n:>3}  {c}")


def generar_csv(filas):
    destino = AQUI / "catalogo-proveedor.csv"
    con = [f for f in filas if f["precio_publico"] is not None]
    with destino.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["producto", "presentacion", "categoria", "contexto",
                    "imagen", "precio_publico", "precio_mayorista"])
        for f in con:
            w.writerow([f["producto"], f["presentacion"], f["categoria"],
                        f["contexto"], f["imagen"], f["precio_publico"], ""])
    print(f"✅ {destino.name}: {len(con)} presentaciones publicables")
    print("   Falta una sola columna: precio_mayorista (lo pone la marca).")


def q(v):
    if v is None or v == "":
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


def generar_sql(marca, filas, marca_id, precios):
    porprod = {}
    for f in filas:
        if f["precio_publico"] is None:
            continue
        may = precios.get((f["producto"], f["presentacion"]))
        if may is None:
            continue
        porprod.setdefault(f["producto"], {"info": f, "pres": []})["pres"].append((f, may))

    L = ["-- Catálogo generado desde la web del proveedor por extraer-catalogo.py",
         "-- NO editar a mano.", "", "begin;", ""]
    for nombre, d in porprod.items():
        info = d["info"]
        pid = uuid.uuid5(NS, f"{marca_id}:{nombre}")
        L += [f"-- {nombre} · {info['categoria']}",
              "insert into productos (id, marca_id, nombre, categoria, descripcion, estado, activo)",
              f"values ({q(pid)}, {q(marca_id)}, {q(nombre)}, {q(info['categoria'])},",
              f"        {q(info['contexto'])}, 'aprobado', true)",
              "on conflict (id) do nothing;"]
        for f, may in d["pres"]:
            vid = uuid.uuid5(NS, f"{marca_id}:{nombre}:{f['presentacion']}")
            L += ["insert into presentaciones (id, producto_id, nombre, precio_mayorista, precio_publico)",
                  f"values ({q(vid)}, {q(pid)}, {q(f['presentacion'])}, "
                  f"{float(may):.2f}, {float(f['precio_publico']):.2f})",
                  "on conflict (id) do nothing;"]
        L.append("")
    L += ["commit;"]

    destino = AQUI / "seed-catalogo.sql"
    destino.write_text("\n".join(L) + "\n", encoding="utf-8")
    n = sum(len(d["pres"]) for d in porprod.values())
    print(f"✅ {destino.name}: {len(porprod)} productos · {n} presentaciones")


def cargar_precios(ruta):
    precios, faltan, malos = {}, [], []
    with open(ruta, newline="", encoding="utf-8") as fh:
        for fila in csv.DictReader(fh):
            clave = (fila["producto"], fila["presentacion"])
            crudo = (fila.get("precio_mayorista") or "").strip()
            if not crudo:
                faltan.append(clave); continue
            try:
                may = float(crudo.replace(",", "."))
            except ValueError:
                malos.append((clave, crudo)); continue
            pub = float(fila["precio_publico"])
            if may >= pub:
                malos.append((clave, f"{may} ≥ precio de página {pub}")); continue
            precios[clave] = may
    return precios, faltan, malos


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sitio", required=True, help="carpeta del sitio del proveedor")
    ap.add_argument("--revisar", action="store_true")
    ap.add_argument("--csv", action="store_true")
    ap.add_argument("--sql", action="store_true")
    ap.add_argument("--marca-id")
    ap.add_argument("--desde-csv")
    a = ap.parse_args()

    raiz = pathlib.Path(a.sitio).expanduser().resolve()
    marca = leer_sitio(raiz)
    filas = presentaciones(marca, raiz)

    if a.revisar:
        revisar(marca, filas); return
    if a.csv:
        generar_csv(filas); return
    if a.sql:
        if not a.marca_id or not a.desde_csv:
            ap.error("--sql necesita --marca-id y --desde-csv")
        try:
            uuid.UUID(a.marca_id)
        except ValueError:
            ap.error(f"--marca-id no es un uuid válido: {a.marca_id}")
        precios, faltan, malos = cargar_precios(a.desde_csv)
        if malos:
            print("❌ Precios que la base rechazaría:")
            for (p, pr), m in malos:
                print(f"   · {p} — {pr}: {m}")
            sys.exit(1)
        if faltan:
            print(f"⚠️  {len(faltan)} presentaciones sin precio mayorista; quedan fuera.")
        generar_sql(marca, filas, a.marca_id, precios); return
    ap.error("elige --revisar, --csv o --sql")


if __name__ == "__main__":
    main()
