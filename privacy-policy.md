# Política de Privacidad — ARCANUM

**Última actualización:** 30 de agosto de 2026
**Versión:** 2026-08-30

ARCANUM ("la App") es una aplicación móvil de práctica mágica, astrología y esoterismo. Esta Política de Privacidad describe cómo recopilamos, usamos, almacenamos y protegemos tu información personal.

Al usar ARCANUM, aceptas las prácticas descritas en esta política.

**Responsable del tratamiento:** Samuel Andrés Escobar Saldarriaga (Colombia).
**Contacto:** arcanum.magick.app@gmail.com

---

## 1. Datos que recopilamos

### 1.1 Datos de cuenta
- **Correo electrónico** — requerido para registro y autenticación
- **Contraseña** — almacenada como hash bcrypt, irreversible
- **Nombre para mostrar** — opcional

### 1.2 Datos de nacimiento (para cálculos astrológicos)
- **Fecha de nacimiento**
- **Hora de nacimiento**
- **Lugar de nacimiento** (ciudad, coordenadas lat/lon, zona horaria)

Son necesarios para generar tu carta natal: son los parámetros del cálculo, no un dato de perfil. Puedes usar la App sin ellos, pero la parte astrológica no podrá funcionar.

### 1.3 Ubicación actual
- **Ciudad, coordenadas y zona horaria de residencia**

Se usan para la hora planetaria, el regente del día y tu fecha local. **La App no lee el GPS de tu dispositivo**: la ubicación la introduces tú al elegir una ciudad. El único permiso que la App declara en Android es el de acceso a internet.

### 1.4 Preferencias
- **Tradición preferida** (ej: occidental, cabalística)
- **Sistema de casas** (ej: Placidus, Regiomontanus)

### 1.5 Datos de uso
- **Sesiones de adivinación** (tiradas de tarot, consultas al oráculo)
- **Entradas del grimorio** (notas personales, cifradas — ver 4.1)
- **Conversaciones con el oráculo IA**
- **Lecturas de tarot guardadas**
- **Progreso de lectura, marcadores y pasajes guardados** de la biblioteca
- **Contadores de uso diario**, para aplicar los límites del plan gratuito

### 1.6 Datos de suscripción
- **Nivel de suscripción** (gratis/mensual/anual)
- **ID de cliente de RevenueCat**
- **Fecha de expiración de la suscripción**

### 1.7 Datos técnicos

- **Tipo de dispositivo y versión del sistema operativo**
- **Registros de errores** (Firebase Crashlytics)

**Esta versión de ARCANUM no muestra anuncios y no recoge tu identificador de publicidad.** El código incluye la integración con AdMob desactivada; si algún día se activa, actualizaremos esta política antes y pediremos consentimiento previo donde la ley lo exija.

---

## 2. Cómo usamos tus datos

- **Proporcionar el servicio** — cartas natales, tránsitos, interpretaciones y respuestas del oráculo
- **Personalizar tu experiencia** — contenido según tu tradición y configuración
- **Gestionar suscripciones** — verificar el estado premium y procesar compras
- **Mostrar anuncios opcionales** — nunca obligatorios, y solo para conceder uso extra
- **Mejorar la App** — detectar errores y fallos de rendimiento

**No usamos analítica de uso.** La App no lleva Firebase Analytics ni ningún otro sistema que registre qué pantallas visitas o cómo la usas.
- **Prevenir abuso** — autenticación, límites de frecuencia y detección de uso anómalo

**Nunca vendemos tus datos**, ni los usamos para publicidad segmentada basada en tu carta natal, tus lecturas o tus notas.

---

## 3. Servicios de terceros

| Servicio | Propósito | Proveedor |
|----------|-----------|-----------|
| **RevenueCat** | Gestión de suscripciones y pagos | RevenueCat, Inc. |
| **Firebase Crashlytics** | Reporte de errores | Google LLC |
| **Groq** | Oráculo IA (procesamiento de lenguaje natural) | Groq, Inc. |
| **Railway** | Alojamiento del servidor (la API) | Railway Corp. |
| **Supabase** | Base de datos | Supabase, Inc. |

Qué recibe cada uno, en concreto:

- **Groq** recibe el texto de tu consulta, el contexto astrológico necesario para responder, las cartas de la tirada y **tu nombre visible** (el que eliges en tu perfil; si no pones ninguno, se envía «Consultante»). **No recibe tu correo electrónico, tu identificador de usuario ni las entradas de tu grimorio**, que viajan cifradas y no se descifran en ningún punto del servidor.

  Si prefieres que tu nombre real no salga de aquí, cambia el nombre visible en tu perfil por el que quieras: es el único que se envía.
- **RevenueCat** recibe un identificador de cliente y el estado de compra. No recibe el contenido de la App.
- **Railway** aloja la API. A su vez se apoya en Google Cloud, Cloudflare y Stripe.
- **Supabase** aloja la base de datos: es quien custodia tu cuenta, tu perfil natal, tu grimorio cifrado y tu historial. Es el proveedor que guarda el conjunto de tus datos.
- **AdMob** no recibe nada hoy: los anuncios están desactivados.

Una versión anterior de esta política listaba **AdMob** como servicio activo. No lo está: esta versión no muestra anuncios. Corregido.

El 30 de agosto de 2026 esta política llegó a afirmar, durante unas horas, que Supabase «ya no se usa» y que la base vivía en Railway. **Era falso**, y se comprobó mirando el código en vez de la configuración real del despliegue: la base de datos está en Supabase. La lista de arriba es la correcta.

Cada servicio tiene su propia política de privacidad:
- [RevenueCat Privacy Policy](https://www.revenuecat.com/privacy)
- [Google Privacy Policy](https://policies.google.com/privacy)
- [Groq Privacy Policy](https://groq.com/privacy-policy/)
- [Railway Privacy Policy](https://railway.com/legal/privacy)
- [Supabase Privacy Policy](https://supabase.com/privacy)

---

## 3.1 Dónde se tratan tus datos

Los tres proveedores anteriores tratan datos **en Estados Unidos**. Eso significa que tus datos salen de Colombia, del Espacio Económico Europeo y del Reino Unido.

La transferencia se ampara en las **Cláusulas Contractuales Tipo** de la Comisión Europea, con el addendum del ICO para el Reino Unido, incorporadas a los acuerdos de tratamiento de cada proveedor. Para Colombia se realiza con tu autorización y bajo contrato de transmisión, conforme al artículo 26 de la Ley 1581 de 2012.

Publicaremos aquí el alta de cualquier proveedor nuevo antes de que empiece a tratar datos.

---

## 3.2 Inteligencia artificial

Las lecturas del Oráculo **las genera un modelo de lenguaje** operado por Groq. Se te avisa dentro de la App antes de la primera consulta y se te pide consentimiento explícito, que puedes retirar cuando quieras desde Ajustes. Si lo retiras, el Oráculo deja de funcionar; el resto de la App sigue disponible.

Groq declara que no entrena sus modelos con las entradas ni con las salidas. Puede conservar entradas y salidas hasta 30 días por motivos de fiabilidad y prevención de abuso.

No se toma ninguna decisión automatizada que produzca efectos jurídicos sobre ti ni te afecte de forma similar. El Oráculo no evalúa, puntúa ni clasifica a personas. Su contenido es simbólico: no es consejo médico, jurídico, financiero ni psicológico.

Puedes denunciar cualquier respuesta generada por IA desde la propia pantalla donde aparece.

---

## 3.3 Categorías especiales de datos

Lo que preguntas al Oráculo puede revelar **creencias religiosas o filosóficas**. En Europa son una categoría especial (artículo 9 del RGPD) y en Colombia un dato sensible (artículo 5 de la Ley 1581 de 2012).

Por eso se piden **aparte**, con un consentimiento explícito que se registra junto a la versión de esta política, y por eso **puedes usar ARCANUM sin concederlo**. Facilitar datos sensibles es siempre voluntario.

---

## 3.4 Base legal de cada tratamiento

| Qué | Para qué | Base legal |
|---|---|---|
| Cuenta y autenticación | Prestarte el servicio | Ejecución del contrato |
| Datos de nacimiento y carta natal | Calcular e interpretar | Contrato + consentimiento explícito |
| Preguntas al Oráculo y grimorio | Generar y guardar tu práctica | Contrato + consentimiento explícito cuando revelan convicciones |
| Créditos, compras y suscripción | Cobrar, reembolsar y llevar la contabilidad | Contrato + obligación legal |
| Registros de errores | Mantener la App estable y segura | Interés legítimo |

Puedes **retirar cualquier consentimiento** en cualquier momento, sin que ello afecte a la licitud del tratamiento anterior.

---

## 4. Almacenamiento y seguridad

### 4.1 Qué está cifrado, y qué no

Con precisión, porque la diferencia importa:

- **Grimorio y notas personales** — cifrados con **AES-256 en tu propio dispositivo**, antes de salir de él. El servidor almacena texto cifrado y no dispone de la clave: no podemos leer tus notas aunque quisiéramos.
- **Contraseña** — hash bcrypt, irreversible. No se almacena en claro en ningún momento.
- **La pregunta que acompaña a una tirada** — cifrada, junto a la sesión de adivinación.
- **Las conversaciones con el Oráculo** — se guardan **en claro**, para poder mostrarte tu historial y atender denuncias de contenido. Están protegidas por el control de acceso del servidor y el cifrado en reposo del proveedor, pero **no** por cifrado de extremo a extremo. Tenlo en cuenta al escribir.
- **El título y las etiquetas** de una entrada del grimorio viajan en claro, aunque su cuerpo vaya cifrado: hacen falta para poder listarla y buscarla.
- **El resto de tus datos** (correo, nombre, datos de nacimiento, ubicación, preferencias, historial de lecturas) se almacenan **sin cifrado adicional a nivel de campo**, protegidos por el cifrado en reposo del proveedor de base de datos y por el control de acceso a la infraestructura.

> Una versión anterior de esta política afirmaba que los datos de nacimiento se almacenaban cifrados en la base de datos. **Era inexacto** y se ha corregido: el cifrado extremo a extremo se aplica al grimorio, no a los datos de perfil.

### 4.2 Transporte y acceso

- **Comunicación** — todas las conexiones usan HTTPS/TLS
- **Acceso** — solo personal autorizado accede a la infraestructura

---

## 5. Retención de datos

- **Datos de cuenta** — mientras tu cuenta esté activa
- **Datos del grimorio** — se eliminan al eliminar tu cuenta
- **Registros de errores** — 90 días
- **Registros de compra y facturación** — el tiempo que exija la normativa contable y fiscal, aunque la cuenta se elimine

---

## 6. Tus derechos

De acuerdo con la Ley 1581 de 2012 de Colombia y las regulaciones aplicables, tienes derecho a:

- **Acceder** a tus datos personales
- **Rectificar** datos inexactos
- **Solicitar la eliminación** de tus datos
- **Oponerte** al procesamiento de tus datos
- **Portabilidad** de tus datos

Para ejercerlos, escribe a **arcanum.magick.app@gmail.com** desde el correo de tu cuenta.

**Plazos de respuesta:**

- **Colombia** — diez (10) días hábiles para consultas y quince (15) días hábiles para reclamos, prorrogables conforme a los artículos 14 y 15 de la Ley 1581 de 2012.
- **Espacio Económico Europeo y Reino Unido** — un mes, prorrogable dos meses más si la solicitud es compleja, avisándote (artículo 12.3 del RGPD).

**Derecho a reclamar.** Si crees que tratamos mal tus datos puedes acudir a la autoridad de control: la **Superintendencia de Industria y Comercio** en Colombia, la autoridad de protección de datos de tu país en el Espacio Económico Europeo, o la **Information Commissioner's Office** en el Reino Unido.

**California.** No vendemos ni compartimos tu información personal en el sentido de la CCPA/CPRA, y ejercer tus derechos nunca dará lugar a un trato discriminatorio.

**Brechas de seguridad.** Si se produce una violación de seguridad que suponga un riesgo para tus derechos, la notificaremos a la autoridad competente dentro de las 72 horas siguientes a tener constancia de ella (artículo 33 del RGPD), y te avisaremos directamente cuando el riesgo sea alto.

---

## 7. Eliminación de cuenta

Puedes eliminarla desde **Ajustes → Eliminar cuenta** dentro de la App, o sin tenerla instalada siguiendo las instrucciones de **[Eliminar tu cuenta](account-deletion.html)**.

Al eliminar tu cuenta se borran tus datos personales de nuestros servidores y se elimina tu cliente en RevenueCat. El detalle de qué se borra y qué no está en esa página.

---

## 8. Privacidad de menores

ARCANUM está dirigida a personas mayores de **18 años**. No recopilamos intencionadamente datos de menores. Si descubrimos que un menor ha proporcionado datos personales, los eliminaremos de inmediato.

---

## 9. Cambios en esta política

Nos reservamos el derecho de actualizarla. Te notificaremos de cambios significativos a través de la App o por correo electrónico. El uso continuado tras los cambios constituye aceptación de la política actualizada.

---

## 10. Contacto

- **Responsable:** Samuel Andrés Escobar Saldarriaga
- **Correo electrónico:** arcanum.magick.app@gmail.com
- **País:** Colombia

---

*Esta política se rige por las leyes de la República de Colombia.*
