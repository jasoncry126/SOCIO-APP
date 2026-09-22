#!/usr/bin/env node
/* Sube las fotos del catálogo de una marca a su carpeta del cubo `catalogo` y
   deja apuntada cada una en su presentación.

   Entra como la marca, con su celular y su clave —las mismas con las que abre
   `app/proveedor.html`—, así que no hace falta ninguna clave de servicio: todo
   lo que hace este script lo podría hacer la marca desde su panel. Si algo se
   sale de su sitio, las reglas de la base lo paran, que es justamente lo que
   queremos comprobar.

   Uso (desde la carpeta web/, que es donde está instalado supabase-js):

       cd web
       node ../supabase/datos/subir-fotos.mjs --celular 9XXXXXXXX --clave XXXX --seco
       node ../supabase/datos/subir-fotos.mjs --celular 9XXXXXXXX --clave XXXX

   Con --seco no sube ni escribe nada: solo dice qué haría. Conviene mirarlo
   antes, sobre todo la lista de presentaciones que no casan con el CSV.

   La conexión sale de web/.env.local, o de las variables de entorno
   VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY.

   Necesita la migración 20260921180000 aplicada: sin ella no existe ni la
   columna `imagen` ni el cubo `catalogo`. */

import { createClient } from "@supabase/supabase-js";
import { readFileSync, existsSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const AQUI = dirname(fileURLToPath(import.meta.url));
const RAIZ = join(AQUI, "..", "..");
const CSV = join(AQUI, "catalogo-proveedor.csv");
const FOTOS = join(RAIZ, "app", "imagenes");
const CUBO = "catalogo";
const DOMINIO_MARCAS = "marcas.socio.local";
const SUFIJO_CLAVE = "-socioapp";

/* ------------------------------------------------------------------ */
/* Argumentos y conexión                                               */
/* ------------------------------------------------------------------ */

function argumento(nombre) {
  const i = process.argv.indexOf("--" + nombre);
  return i >= 0 ? process.argv[i + 1] : null;
}
const seco = process.argv.includes("--seco");
const celular = argumento("celular");
const clave = argumento("clave");

if (!celular || !clave) {
  console.error("Falta --celular o --clave. Son los de la marca, los mismos de proveedor.html.");
  process.exit(1);
}

function leerEntorno() {
  const env = { ...process.env };
  const archivo = join(RAIZ, "web", ".env.local");
  if (existsSync(archivo)) {
    for (const linea of readFileSync(archivo, "utf8").split("\n")) {
      const m = /^\s*([A-Z_]+)\s*=\s*(.*)\s*$/.exec(linea);
      if (m && !env[m[1]]) env[m[1]] = m[2].replace(/^["']|["']$/g, "");
    }
  }
  return env;
}

const env = leerEntorno();
if (!env.VITE_SUPABASE_URL || !env.VITE_SUPABASE_ANON_KEY) {
  console.error("Falta la conexión. Copia web/.env.example como web/.env.local y pega tus datos.");
  process.exit(1);
}
const sb = createClient(env.VITE_SUPABASE_URL, env.VITE_SUPABASE_ANON_KEY);

/* ------------------------------------------------------------------ */
/* El CSV del catálogo                                                 */
/* ------------------------------------------------------------------ */
/* Se parsea a mano porque las descripciones llevan comas dentro de comillas y
   un split(",") las partiría por la mitad. */

function filasDelCsv(texto) {
  const filas = [];
  let campo = "";
  let fila = [];
  let entreComillas = false;

  for (let i = 0; i < texto.length; i++) {
    const c = texto[i];
    if (entreComillas) {
      if (c === '"' && texto[i + 1] === '"') { campo += '"'; i++; }
      else if (c === '"') entreComillas = false;
      else campo += c;
    } else if (c === '"') entreComillas = true;
    else if (c === ",") { fila.push(campo); campo = ""; }
    else if (c === "\n") { fila.push(campo); filas.push(fila); fila = []; campo = ""; }
    else if (c !== "\r") campo += c;
  }
  if (campo || fila.length) { fila.push(campo); filas.push(fila); }

  const cabecera = filas.shift().map((c) => c.trim());
  return filas
    .filter((f) => f.length === cabecera.length)
    .map((f) => Object.fromEntries(cabecera.map((c, i) => [c, f[i]])));
}

/* La clave con la que se casan el CSV y la base: nombre del producto más
   nombre de la presentación, sin acentos ni mayúsculas ni espacios de más.
   Así "Vial 5 mg" y "vial 5 mg" son lo mismo, que es lo que uno espera. */
function llave(producto, presentacion) {
  const limpiar = (t) =>
    String(t ?? "")
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .toLowerCase()
      .replace(/\s+/g, " ")
      .trim();
  return limpiar(producto) + " · " + limpiar(presentacion);
}

/* ------------------------------------------------------------------ */

async function principal() {
  console.log("\n  Entrando como la marca…");
  const entrada = await sb.auth.signInWithPassword({
    email: celular.replace(/\D/g, "") + "@" + DOMINIO_MARCAS,
    password: clave + SUFIJO_CLAVE,
  });
  if (entrada.error) {
    console.error("  No se pudo entrar: " + entrada.error.message);
    process.exit(1);
  }
  const marcaId = entrada.data.user.id;

  const { data: marca } = await sb.from("marcas").select("nombre").eq("id", marcaId).maybeSingle();
  console.log("  Marca: " + (marca?.nombre ?? marcaId));

  /* Las presentaciones de esta marca. Las reglas de la base ya limitan lo que
     devuelve a las suyas; el filtro por marca_id es para que se vea aquí. */
  const { data: filas, error } = await sb
    .from("presentaciones")
    .select("id, nombre, imagen, productos!inner(nombre, marca_id)")
    .eq("productos.marca_id", marcaId);

  if (error) {
    console.error("  No se pudo leer el catálogo: " + error.message);
    process.exit(1);
  }

  const enLaBase = new Map();
  for (const f of filas ?? []) enLaBase.set(llave(f.productos.nombre, f.nombre), f);
  console.log("  Presentaciones en la base: " + enLaBase.size);

  const delCsv = filasDelCsv(readFileSync(CSV, "utf8"));
  const archivos = new Set(existsSync(FOTOS) ? readdirSync(FOTOS) : []);

  const cuenta = { subidas: 0, apuntadas: 0, sinArchivo: [], sinCasar: [], igual: 0 };

  for (const fila of delCsv) {
    const archivo = (fila.imagen ?? "").trim();
    if (!archivo) continue;

    const pres = enLaBase.get(llave(fila.producto, fila.presentacion));
    if (!pres) { cuenta.sinCasar.push(fila.producto + " · " + fila.presentacion); continue; }
    if (!archivos.has(archivo)) { cuenta.sinArchivo.push(archivo); continue; }

    const ruta = marcaId + "/" + archivo;
    if (pres.imagen === ruta) { cuenta.igual++; continue; }

    if (seco) {
      console.log("  (seco) subiría " + archivo + " → " + fila.producto + " · " + fila.presentacion);
      cuenta.subidas++;
      continue;
    }

    const bytes = readFileSync(join(FOTOS, archivo));
    const subida = await sb.storage.from(CUBO).upload(ruta, bytes, {
      contentType: archivo.endsWith(".webp") ? "image/webp" : "image/jpeg",
      upsert: true,
    });
    if (subida.error) {
      console.error("  ✗ " + archivo + ": " + subida.error.message);
      continue;
    }
    cuenta.subidas++;

    const apunte = await sb.from("presentaciones").update({ imagen: ruta }).eq("id", pres.id);
    if (apunte.error) {
      console.error("  ✗ apuntando " + archivo + ": " + apunte.error.message);
      continue;
    }
    cuenta.apuntadas++;
    console.log("  ✓ " + fila.producto + " · " + fila.presentacion);
  }

  console.log("\n  " + (seco ? "Subiría" : "Subidas") + ": " + cuenta.subidas);
  if (!seco) console.log("  Apuntadas en la base: " + cuenta.apuntadas);
  if (cuenta.igual) console.log("  Ya estaban al día: " + cuenta.igual);
  if (cuenta.sinArchivo.length) {
    console.log("  Sin archivo en app/imagenes: " + cuenta.sinArchivo.length);
    for (const a of cuenta.sinArchivo) console.log("    · " + a);
  }
  if (cuenta.sinCasar.length) {
    console.log("  En el CSV pero no en la base: " + cuenta.sinCasar.length);
    for (const a of cuenta.sinCasar) console.log("    · " + a);
  }
  console.log("");
}

principal().catch((e) => {
  console.error("\n  Se rompió: " + (e?.message ?? e) + "\n");
  process.exit(1);
});
