# Generadores de documentos

Documentos de negocio que se arman con código en vez de a mano, para que los
números salgan siempre del sistema y no de una copia que se quedó vieja.

## consulta-contador.js

Genera el documento que se le entrega al contador: qué es SOCIO, cómo se mueve
el dinero en una venta con números reales, las dos figuras tributarias que
hemos identificado, el problema de la boleta que viaja en el paquete, y las
siete preguntas concretas que bloquean el desarrollo.

Las cifras del ejemplo salen de `app/socio-precios.js`, así que si cambian los
niveles, el margen mínimo o el IGV, se regenera y el documento queda al día.

```bash
npm install docx          # solo la primera vez
node docs/generadores/consulta-contador.js SOCIO-consulta-contador.docx
```
