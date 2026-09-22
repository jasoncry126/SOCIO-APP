import { useMemo, useState } from "react";
import { motion } from "framer-motion";
import { urlDeFoto } from "../datos/catalogo";

/* ===========================================================================
   La foto de una presentación, con el emoji del producto de respaldo.

   El respaldo no es un adorno: una marca recién dada de alta no tiene fotos
   todavía, y su catálogo tiene que poder verse igual. Por eso aquí no hay
   ninguna imagen "de producto sin foto" — el emoji que la propia marca eligió
   dice más que un cuadro gris con una cámara tachada.

   También cubre el caso de la foto rota: si el archivo ya no está en el cubo,
   el navegador avisa y se vuelve al emoji en vez de dejar el hueco.
   =========================================================================== */

interface Props {
  /** Lo que guarda la base: ruta dentro del cubo, o URL https. */
  imagen: string;
  emoji: string;
  /** Qué es la foto, para quien no la ve. Vacío si el nombre ya está al lado. */
  alt: string;
  /** Tamaño del emoji cuando toca el respaldo. */
  clase?: string;
  /* Cómo ocupa su hueco. "cubrir" lo llena y recorta lo que sobra: bien para
     la cuadrícula, donde el hueco es cuadrado como las fotos. "contener" la
     enseña entera aunque queden bordes: bien para la ficha, donde recortar un
     frasco por la mitad es justo lo que no se quiere. */
  ajuste?: "cubrir" | "contener";
}

export function Foto({ imagen, emoji, alt, clase, ajuste }: Props) {
  const url = useMemo(() => urlDeFoto(imagen), [imagen]);
  const [rota, setRota] = useState(false);

  if (!url || rota) {
    return (
      <span className={"flex h-full w-full items-center justify-center " + (clase ?? "text-5xl")}
            aria-hidden="true">
        {emoji}
      </span>
    );
  }

  return (
    <motion.img
      src={url}
      alt={alt}
      loading="lazy"
      decoding="async"
      onError={() => setRota(true)}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.3, ease: "easeOut" }}
      className={"h-full w-full " + (ajuste === "contener" ? "object-contain" : "object-cover")}
    />
  );
}
