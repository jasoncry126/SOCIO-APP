# Catálogo de LAB PEPTIDOS PERU — fuente original

`manifest.js` es el archivo donde la marca mantiene su catálogo en su propia
página web (el paquete `sitio-final-cloudflare`). Es la **fuente de verdad** de
los cuatro datos que SOCIO necesita de cada presentación:

| Dato | Campo en el manifiesto |
|---|---|
| nombre | `name` + `conc` (o `unit: "blend"`) |
| contexto | `blurb` |
| precio de página | `prices[<concentración>]` |
| imagen | `assets/img/products/{img\|id}-{concentración}.webp` |

El **precio mayorista no está aquí y no puede estar**: es el precio al que la
marca le vende a SOCIO, no un precio público. Lo pone la marca en su panel.

Se lee con `../extraer-catalogo.py`. Solo se guarda el manifiesto, no el sitio
entero: las 63 fotos de las presentaciones publicables ya están en
`app/imagenes/`.
