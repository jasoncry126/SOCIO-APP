# SOCIO — Reglas de Visibilidad de Precios

*Documento de decisión · Agosto 2026*

---

## 1. La contradicción detectada (bien visto)

La regla original decía: *el vendedor solo ve el precio socio; el desglose (precio crudo del proveedor y comisión de la app) no le pertenece*. Pero en el panel v2, la vista previa mostraba el precio socio igual al precio crudo del proveedor y la comisión como línea separada — es decir, el vendedor podía deducir exactamente cuánto recibe el proveedor y cuánto se lleva SOCIO. Dos diseños incompatibles conviviendo. Había que elegir uno.

## 2. La decisión: cada actor ve el desglose solo de su propio contrato

Gana la regla original, y esta es la formulación definitiva:

> **El precio socio es UN solo número que ya trae la comisión SOCIO adentro.** Se construye en el sistema (precio proveedor + comisión) pero se muestra al vendedor como una sola cifra — exactamente como en las apps de comida, donde el precio del plato ya incluye la ganancia del aplicativo y nadie ve la tajada de cada quien.

La matriz completa de quién ve qué:

| Número | Proveedor | Vendedor | Cliente final |
|---|---|---|---|
| Precio proveedor (crudo) | ✅ Es suyo | ❌ Nunca | ❌ Nunca |
| Comisión SOCIO | ✅ La firma en contrato y la ve en cada liquidación | ❌ Nunca (viene fundida en el precio socio) | ❌ Nunca |
| Precio socio | ✅ Lo ve como "así le llega al vendedor" | ✅ Es su costo, un solo número | ❌ Nunca |
| Ganancia del vendedor | ❌ Nunca | ✅ Es suya (precio final − precio socio) | ❌ Nunca |
| Precio final + envío | ⚪ Solo el sugerido de referencia | ✅ Él lo fija | ✅ Es lo único que ve |

La fórmula del sistema queda así:

```
Comisión SOCIO   = % del valor agregado (sugerido − precio proveedor)
Precio socio     = precio proveedor + comisión SOCIO      ← lo que ve el vendedor
Ganancia socio   = precio final que él fija − precio socio ← ya limpia, sin descuentos
El proveedor recibe = su precio, exacto, siempre
```

## 3. Por qué esta opción es la mejor (la psicología detrás)

**Aversión a la pérdida.** Si el vendedor ve "tu ganancia S/ 23... menos comisión S/ 1.15", siente que le *quitan* algo suyo — aunque el resultado sea idéntico. Si ve "precio socio S/ 43.15, tu ganancia S/ 21.85", su ganancia nace limpia y nunca se le descuenta nada. Mismo dinero, emociones opuestas. Las plataformas que descuentan comisiones visibles de las ganancias de su gente pelean esa batalla psicológica todos los días; las que la incluyen en el precio, nunca.

**Riesgo de desintermediación.** Si el vendedor conoce el precio crudo del proveedor, la tentación es obvia: contactarlo directo y saltarse la app. Con el desglose oculto, no sabe cuánto hay "detrás" del precio socio, y el incentivo de puentear a SOCIO se debilita. Es la misma razón por la que el cliente final nunca ve el precio socio: cada capa de la cadena solo conoce su piso inmediato.

**La comparación odiosa.** Un vendedor que ve que SOCIO "solo" gana S/ 1.15 mientras él trabaja el cierre puede subvalorar la plataforma; uno que ve que gana más puede resentirla. Cualquier número visible invita al juicio. El número invisible no se juzga.

**Y del lado del proveedor, transparencia total — porque es contractual.** El proveedor sí ve su precio, la comisión y el precio socio resultante: firmó el contrato de comisión mercantil, recibe liquidaciones documentadas y la factura de SOCIO por esa comisión. Su relación es formal y necesita los números; la del vendedor es de oportunidad y necesita simplicidad. Distintos vínculos, distintas vistas.

## 4. Qué se corrigió en los prototipos

**Panel del proveedor (v2):** la calculadora ahora construye el precio socio sumando la comisión (proveedor + comisión = precio socio, marcado como "lo único que ve el vendedor"), la ganancia del socio se calcula contra el precio socio (no contra el precio crudo), la vista previa de la tarjeta del socio muestra el precio socio ya fundido, y el catálogo muestra la ganancia real del socio con la comisión ya incluida.

**App del vendedor:** no requería cambios — su "precio socio" ya era un solo número sin desglose, cumpliendo la regla desde el inicio. Solo debe entenderse que, en el sistema real, ese número llega calculado del backend con la comisión adentro.
