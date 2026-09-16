# SOCIO — Regla: todo producto debe tener precio

*Regla general del catálogo · Confirmada el 03/09/2026*

---

## La regla

**Ninguna presentación puede publicarse en SOCIO sin un precio definido.** No existe la categoría "a cotizar". Un producto sin precio no entra al catálogo hasta que el proveedor le asigna uno.

## Por qué

El vendedor (socio) **nunca se relaciona directamente con la empresa proveedora** — solo con SOCIO. Es la regla base de toda la plataforma, presente desde el primer documento de arquitectura: SOCIO es el enlace comercial, no un simple directorio de contactos.

Un producto "a cotizar" rompe eso por diseño: obliga al vendedor a negociar precio con alguien fuera de la app — un asesor, un vendedor de la marca, quien sea — es decir, lo obliga a **contratar directamente con el proveedor**. Eso abre la puerta a que la venta se cierre fuera de SOCIO, sin comisión, sin registro, sin protección para ninguna de las partes. Es exactamente el escenario que el modelo de comisión mercantil busca evitar.

## Qué exige esto en la práctica

**Panel del proveedor:** el asistente de carga de producto no permite avanzar de paso ni enviar a revisión si alguna presentación tiene nombre pero le falta precio mayorista o precio de página. El aviso es explícito: *"SOCIO no publica presentaciones sin precio."*

**App del vendedor:** el catálogo nunca muestra un producto sin precio. Si por algún error de datos llegara a colarse uno (por ejemplo, una carga masiva futura desde una hoja de cálculo con una fila incompleta), la app lo rechaza al intentar agregarlo al carrito en vez de ofrecer un camino alterno de contacto.

**Import de catálogos externos:** cuando se cargue un catálogo grande desde un archivo (como el que ya se hizo con los 47 productos de Lab Péptidos), cualquier presentación sin precio se **excluye del catálogo publicado**, no se muestra como pendiente ni con botón de contacto. Queda fuera hasta que el proveedor mande el precio.

## Consecuencia del catálogo actual

Del archivo de 76 presentaciones que cargó Lab Péptidos, **12 no tenían precio** y quedaron fuera:

Goralatide 5mg · ARA-290 10mg · Sermorelin 10mg · AOD-9604 10mg · FoxO4-DRI 5mg · Thymalin 10mg · Matrixyl 50mg · Argireline 50mg · SNAP-8 50mg · Semax 5mg · Stack Cardio · Stack Neuro

Seis de esos productos (Goralatide, ARA-290, Matrixyl, Argireline, Stack Cardio, Stack Neuro) no tenían ninguna otra presentación con precio, así que **desaparecieron del catálogo por completo**. Los otros seis conservan su presentación que sí tiene precio (por ejemplo, Sermorelin sigue en el catálogo con su presentación de 5mg; solo la de 10mg quedó fuera).

Catálogo resultante: **47 productos, 64 presentaciones, todas con precio.**

## Para cuando se construya en Claude Code

Esta regla debe vivir en la **validación del backend**, no solo en la interfaz — igual que la restricción de número de operación único en pagos. Sugerencia de restricción a nivel de base de datos:

```sql
alter table presentaciones
  add constraint precio_obligatorio check (precio_publico is not null and precio_publico > 0);
```

Así, aunque alguien intente insertar una fila sin precio directamente en la base (o por una carga masiva mal hecha), la base de datos la rechaza sola — el mismo principio que ya se aplicó a los vouchers duplicados.
