# SOCIO — Dónde ver la app y cómo llegar a la descarga pública

*Guía de publicación por fases · Agosto 2026*

---

## 1. HOY MISMO — Ver y compartir los prototipos (costo: S/ 0)

Los archivos HTML que ya tienes funcionan en cualquier navegador, pero para verlos como app en el celular y compartirlos con socios de prueba, hay que subirlos a internet:

**Netlify (el que ya conoces).** Ya lo usas para labpeptprotocolos.netlify.app, así que es tu camino natural: entra a app.netlify.com, arrastra la carpeta con los HTML y en segundos tienes URLs como `socio-app.netlify.app`. Gratis, con HTTPS automático. Puedes tener tres sitios: la app del vendedor, el panel del proveedor y el panel de control.

**Alternativas equivalentes:** Vercel (vercel.com, idéntico en simpleza) y GitHub Pages (gratis, pero requiere manejar un repositorio — más útil cuando el proyecto tenga código real versionado).

**Para compartir:** el link directo por WhatsApp + un QR (cualquier generador gratuito) que pruebe la experiencia real: escanear → abrir → usar. Consejo: usa nombres de sitio no obvios (`socio-piloto-x7.netlify.app`) mientras sea privado, porque los sitios gratuitos son públicos para quien tenga el link.

## 2. LA APP INSTALABLE SIN TIENDAS — La PWA (costo: solo el dominio)

Este es el secreto que te ahorra meses: una **PWA (Progressive Web App)** es tu web convertida en app instalable. El usuario entra al link, el navegador le ofrece **"Agregar a pantalla de inicio"**, y SOCIO queda con su ícono en el celular, abriendo a pantalla completa como cualquier app — sin pasar por Google ni Apple, sin esperar aprobaciones, actualizándose al instante.

Qué necesita: (1) el hosting que ya tienes (Netlify), (2) dos archivos técnicos que se agregan al proyecto (el *manifest* con nombre, ícono y colores, y un *service worker* — te los puedo generar cuando toque), y (3) un **dominio propio** para que se vea profesional: `socio.pe` se registra vía Punto.pe (el registro oficial peruano, desde ~S/ 100–130 al año a través de sus registradores) o `socioapp.com` en cualquier registrador internacional (Namecheap, Cloudflare, ~USD 10–12/año). El dominio se conecta a Netlify en minutos.

**Con esto la app ya está "abierta a la descarga pública"** en el sentido práctico: cualquiera con el link la instala. Es la fase correcta para el piloto de 10–20 vendedores y para validar el modelo antes de gastar en tiendas.

## 3. GOOGLE PLAY — La descarga pública en tienda (Android primero)

Cuando el piloto valide, el camino a Play Store:

**La cuenta:** Google Play Console (play.google.com/console) — pago **único de USD 25**. Y aquí la decisión importante: crea una **cuenta de organización** (a nombre de tu empresa, con RUC y verificación vía número D-U-N-S), no personal. Motivo de peso: las cuentas personales creadas desde noviembre de 2023 están obligadas a una **prueba cerrada con mínimo 12 testers durante 14 días continuos** antes de poder publicar; las cuentas de organización están exentas de ese requisito. Además la ficha sale a nombre de la empresa (más confianza para descargar) y la propiedad queda en el negocio, no en una persona.

**El empaquetado:** tu PWA se convierte en app de Play mediante **TWA (Trusted Web Activity)** con herramientas como Bubblewrap o PWABuilder (pwabuilder.com, gratuita: le das tu URL y te genera el paquete .aab listo para subir). La alternativa más robusta a futuro es reconstruir con Capacitor o React Native, pero para empezar la TWA de tu PWA es el camino corto y legítimo.

**Requisitos técnicos vigentes:** el paquete debe apuntar a **API 36 (Android 16) desde el 31 de agosto de 2026** — dato clave porque estamos justo antes de ese corte — y desde el 30 de septiembre de 2026 comienza a aplicarse el programa de **verificación de desarrolladores** de Android. Ambos los resuelve tener la cuenta bien constituida y el empaquetado actualizado.

**La ficha:** nombre, descripción, capturas, ícono, **URL de política de privacidad pública** (obligatoria — una página en tu mismo dominio), clasificación de contenido y declaración de seguridad de datos. Revisión de producción: días, no meses.

**Posicionamiento de la ficha (crítico en tu caso):** SOCIO se presenta como lo que es — *plataforma de gestión para vendedores independientes y marcas* (categoría Negocios/Compras) — no como tienda de un producto específico. El catálogo vive dentro, administrado por las marcas con su revisión y documentación. Así la ficha cumple políticas y el mensaje le habla a tu usuario real: el que busca ingresos.

## 4. APP STORE (iPhone) — La segunda tienda, no la primera

**Apple Developer Program:** USD **99 al año** (individual u organización; la de organización también pide D-U-N-S y muestra el nombre de la empresa). Necesitarás acceso a una Mac con Xcode para compilar y subir (o delegar ese paso puntual a un técnico). Apple no acepta PWAs "envueltas" sin más: exige experiencia de app real, por lo que aquí sí conviene el empaquetado con **Capacitor** y una revisión más exigente (24–48 h típicamente, con rechazos frecuentes a la primera).

**Recomendación honesta:** Android primero. En Perú la mayoría de tu público vendedor está en Android, el costo es único (no anual), y la PWA cubre a los usuarios de iPhone mientras tanto (en iOS también se puede "Agregar a inicio" desde Safari). App Store llega cuando la red ya factura.

## 5. La ruta completa, en una tabla

| Fase | Dónde | Costo | Tiempo | Qué logras |
|---|---|---|---|---|
| Ver prototipos | Netlify (drag & drop) | S/ 0 | Hoy, 10 min | Links + QR para mostrar y testear |
| Piloto instalable | PWA en Netlify + dominio socio.pe | ~S/ 100–130/año | 1–2 semanas | App instalable pública, sin tiendas |
| Descarga en Play Store | Play Console (cuenta organización) + TWA | USD 25 único | 2–4 semanas tras el piloto | "Descárgala en Google Play" |
| Descarga en App Store | Apple Developer + Capacitor | USD 99/año | Cuando la red facture | Cobertura iPhone completa |

**Requisitos transversales que conviene dejar listos desde ya:** empresa constituida con RUC (también la pide el modelo tributario), página de política de privacidad y términos del socio en tu dominio, y el logo/ícono de SOCIO en las medidas de tienda (512×512 y 1024×1024).
