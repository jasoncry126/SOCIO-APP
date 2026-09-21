/* ===========================================================================
   Los tipos del dominio de SOCIO.

   Salen de lo que la base devuelve de verdad, no de lo que sería cómodo tener.
   El caso más importante es el precio: la vista `catalogo_publico` NO tiene
   columna de precio mayorista —ese dato no sale de la base hacia el teléfono
   del socio— así que aquí tampoco existe el campo. No es una omisión: es la
   regla 1 de CLAUDE.md escrita en el sistema de tipos, para que nadie pueda
   pintar en pantalla un número que no puede tener.
   =========================================================================== */

/** Los seis estados por los que pasa un pedido en la base. */
export type EstadoPedido =
  | "pendiente_pago"
  | "pagado"
  | "validado"
  | "en_camino"
  | "entregado"
  | "cancelado";

/** Los cuatro niveles del socio. Los mueve la base según ventas ENTREGADAS. */
export type NivelId = "bronce" | "plata" | "oro" | "diamante";

export interface Nivel {
  id: NivelId;
  nombre: string;
  medalla: string;
  /** Lo que el socio se queda, como fracción del precio de página. */
  comision: number;
  /** Ventas entregadas que hacen falta para llegar. */
  meta: number;
  requisito: string;
}

/** Una presentación concreta de un producto: el tamaño que se vende. */
export interface Variante {
  id: string;
  presentacion: string;
  /** Precio de página: el público. NO existe el mayorista (ver arriba). */
  precioPagina: number;
  /** null = la marca no lleva la cuenta del stock en ese origen. */
  stockAlmacen: number | null;
  stockPunto: number | null;
}

export interface Producto {
  id: string;
  marcaId: string;
  marca: string;
  marcaGiro: string;
  marcaCiudadAlmacen: string;
  marcaCiudadPunto: string;
  nombre: string;
  categoria: string;
  emoji: string;
  descripcion: string;
  recomendaciones: string;
  tiempoPreparacion: string;
  variantes: Variante[];
}

export interface Marca {
  id: string;
  nombre: string;
  giro: string;
  ciudadAlmacen: string;
  ciudadPunto: string;
}

export interface Pedido {
  codigo: string;
  estado: EstadoPedido;
  destinatario: string;
  detalleEntrega: string;
  fecha: string;
  numeroGuia: string;
  total: number;
  ganancia: number;
}

/** De qué origen se despacha. Hoy son dos; cada marca definirá los suyos. */
export type Origen = "almacen" | "punto";
