# SOCIO — ¿De quién es la diferencia? El reparto del margen

*Análisis del modelo de precios con productos de terceros · Agosto 2026*

---

## 1. La respuesta corta a tu pregunta

Con tu ejemplo del celular: el proveedor vende a **S/ 80** (su precio mayorista) y el público paga **S/ 115**. Entre ambos hay **S/ 35 de margen disponible**, y ese dinero se reparte entre dos partes:

- **El vendedor**, que consiguió al cliente y cerró la venta.
- **SOCIO**, que puso la plataforma, validó el pago, coordinó el despacho y respalda la operación.

**El proveedor siempre recibe sus S/ 80 íntegros**, sin importar el nivel del socio. Y aquí está la respuesta clave a tu pregunta: **la diferencia entre el 10% y el 20% es dinero de SOCIO, no del proveedor.** Cuando un socio sube de nivel, la plataforma le cede parte de su propia comisión para premiarlo. El proveedor no pierde ni un sol — por eso el panel de la marca dice explícitamente que el descuento por nivel lo asume SOCIO.

Así queda el celular con el modelo actual:

| Nivel del socio | Socio paga | Gana el socio | Recibe el proveedor | Queda para SOCIO |
|---|---|---|---|---|
| 🥉 Bronce (10%) | S/ 103.50 | S/ 11.50 | S/ 80.00 | **S/ 23.50** |
| 🥈 Plata (13%) | S/ 100.05 | S/ 14.95 | S/ 80.00 | **S/ 20.05** |
| 🥇 Oro (16%) | S/ 96.60 | S/ 18.40 | S/ 80.00 | **S/ 16.60** |
| 💎 Diamante (20%) | S/ 92.00 | S/ 23.00 | S/ 80.00 | **S/ 12.00** |

En este caso funciona bien: SOCIO siempre queda con algo, el socio gana más al subir, y el proveedor cobra igual.

---

## 2. El problema que descubriste (y que hay que arreglar antes del lanzamiento)

El modelo actual calcula el descuento **sobre el precio público**, sin mirar cuánto margen hay realmente disponible. Eso funciona cuando el margen es amplio, pero **se rompe cuando es estrecho**.

Mira qué pasa con un proveedor que vende a S/ 105 y su público paga S/ 115 (solo S/ 10 de margen — normal en electrónica y abarrotes):

| Nivel | Socio paga | Recibe el proveedor | Queda para SOCIO |
|---|---|---|---|
| 🥉 Bronce (10%) | S/ 103.50 | S/ 105.00 | **− S/ 1.50 ❌** |
| 💎 Diamante (20%) | S/ 92.00 | S/ 105.00 | **− S/ 13.00 ❌** |

**SOCIO pondría dinero de su bolsillo en cada venta.** Con productos propios de Lab Péptidos esto nunca aparece porque tú controlas ambos precios; con terceros de otros rubros va a aparecer el primer mes.

---

## 3. La solución: repartir el margen, no descontar del precio público

El cambio es simple pero cambia la naturaleza del cálculo: **el nivel define qué porcentaje del margen disponible se lleva el socio**, no qué porcentaje del precio público se le descuenta.

```
Margen disponible = Precio público − Precio mayorista del proveedor
Ganancia del socio = Margen disponible × % de su nivel
Comisión SOCIO    = Margen disponible − Ganancia del socio
El proveedor      = siempre su precio mayorista íntegro
```

Con el celular (margen S/ 35):

| Nivel | % del margen | Gana el socio | Queda para SOCIO |
|---|---|---|---|
| 🥉 Bronce | 40% | S/ 14.00 | S/ 21.00 |
| 🥈 Plata | 50% | S/ 17.50 | S/ 17.50 |
| 🥇 Oro | 60% | S/ 21.00 | S/ 14.00 |
| 💎 Diamante | 70% | S/ 24.50 | S/ 10.50 |

Y con el caso estrecho (margen S/ 10): Bronce gana S/ 4 y SOCIO S/ 6; Diamante gana S/ 7 y SOCIO S/ 3. **Nunca queda en negativo**, porque siempre se reparte lo que existe. Además el socio gana más que con el modelo anterior en el caso amplio (S/ 14 vs S/ 11.50 en Bronce), lo que hace tu red más atractiva frente a otras plataformas.

**Dos protecciones que conviene sumar:**

1. **Piso de SOCIO.** Que la plataforma nunca baje de un mínimo por transacción (por ejemplo, 3% del precio público o S/ 3, lo que sea mayor), para que las ventas de margen chico sigan cubriendo el costo operativo.
2. **Validación al cargar el producto.** Si un proveedor pone un margen tan pequeño que ni el nivel Bronce deja ganancia razonable al socio, el panel debe avisarle: *"Con este margen, un socio ganaría S/ 2 por unidad — pocos elegirán venderlo."* Nadie pierde tiempo publicando algo que la red no va a mover.

---

## 4. Un detalle importante: esto solo aplica a terceros

Con **productos propios de Lab Péptidos**, SOCIO y la marca son el mismo bolsillo: no hay dos partes repartiendo nada, solo tu margen mayorista completo menos lo que le cedes al socio. Por eso ahí la regla del 10% plano (y la escalera a 20%) funciona tal como está — el descuento sale de tu propia ganancia y tú decides hasta dónde.

Para **terceros**, el reparto del margen es el modelo correcto, porque el precio mayorista lo pone otro y tú no controlas cuánto espacio hay.

En la práctica, el sistema debe manejar los dos casos: si el producto es propio, el cálculo actual; si es de tercero, reparto del margen con piso garantizado.

---

## 5. Lo que hay que cambiar en la app

**En el panel del proveedor:** agregar el campo **"Tu precio mayorista"** junto al precio de página en cada presentación. Hoy solo pedimos el precio público, y sin el mayorista el sistema no puede calcular el reparto. Con ambos, la vista previa puede mostrarle al proveedor exactamente lo que ya muestra ahora, pero con números reales y sin riesgo de números negativos.

**En la app del vendedor:** ningún cambio visible. El socio sigue viendo un solo número (su costo) y su ganancia — el reparto ocurre por debajo. La regla de visibilidad que definimos se mantiene intacta.

**En el sistema de control:** cada pedido debe registrar las tres partes (proveedor, socio, SOCIO) para que las liquidaciones y la contabilidad cuadren solas.

---

Si te parece bien el modelo de reparto, lo implemento en el panel del proveedor (campo de precio mayorista + validación de margen) y ajusto el cálculo de niveles para que distinga producto propio de tercero.
