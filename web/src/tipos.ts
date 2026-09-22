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
  /* La foto, tal como la guarda la base: una ruta dentro del cubo `catalogo`
     (`<marca_id>/archivo.webp`) o una URL https si la marca la aloja fuera.
     Vacío es lo normal mientras una marca no haya subido las suyas, y la
     pantalla enseña el emoji del producto. Se pinta con urlDeFoto(). */
  imagen: string;
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

export interface Socio {
  id: string;
  nombre: string;
  dni: string;
  celular: string;
  ciudad: string;
  validado: boolean;
  /** Lo pone la base por ventas ENTREGADAS. Nunca se calcula en la pantalla. */
  nivel: NivelId;
  ventasEntregadas: number;
}

/** En qué quedó el pago que el socio declaró, si llegó a declarar alguno. */
export type EstadoPago = "declarado" | "validado" | "rechazado";

export interface Pedido {
  id: string;
  codigo: string;
  estado: EstadoPedido;
  destinatario: string;
  detalleEntrega: string;
  fecha: string;
  numeroGuia: string;
  total: number;
  ganancia: number;
  /* Lo que el socio tiene que depositar, con los céntimos que identifican
     este pedido y ningún otro en el extracto del día. Sale de la base: los
     céntimos se derivan del código, y el código no existe hasta que el
     pedido está registrado. Por eso primero se registra y después se cobra. */
  montoADepositar: number;
  pagoEstado: EstadoPago | null;
  /** Ruta dentro del cubo privado, no una URL: la firmada caduca en minutos. */
  pagoCaptura: string;
  /** Por qué SOCIO rechazó el pago, para que el socio pueda subir otra. */
  pagoMotivo: string;
}

/** Lo que el carrito manda a la base: qué presentación y cuántas. Ningún
    precio — los calcula crear_pedido() leyendo el catálogo y el nivel. */
export interface ItemPedido {
  presentacion_id: string;
  cantidad: number;
}

/** Una línea del carrito, con lo que hace falta para pintarla. */
export interface LineaCarrito {
  producto: Producto;
  variante: Variante;
  cantidad: number;
}

export type ModoEntrega = "agencia" | "domicilio";

export interface DatosEnvio {
  destinatario: string;
  documento: string;
  celular: string;
  modo: ModoEntrega;
  /** Con modo "agencia": el local de recojo. Con "domicilio": la dirección. */
  detalle: string;
  referencia: string;
  agencia: string;
}

/** De qué origen se despacha. Hoy son dos; cada marca definirá los suyos. */
export type Origen = "almacen" | "punto";
