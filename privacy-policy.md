# Política de Privacidad — ARCANUM

**Última actualización:** 25 de agosto de 2026

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

### 1.7 Datos técnicos y publicidad
- **Identificador de publicidad**, para los anuncios opcionales que conceden uso extra
- **Tipo de dispositivo y versión del sistema operativo**
- **Registros de errores** (Firebase Crashlytics)

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
| **Google AdMob** | Publicidad (anuncios bonificados) | Google LLC |
| **Firebase Crashlytics** | Reporte de errores | Google LLC |
| **Groq** | Oráculo IA (procesamiento de lenguaje natural) | Groq, Inc. |
| **Supabase** | Base de datos | Supabase, Inc. |
| **Railway** | Alojamiento del servidor | Railway App, Inc. |

Qué recibe cada uno, en concreto:

- **Groq** recibe el texto de tu consulta y el contexto astrológico necesario para responder. **No recibe las entradas de tu grimorio**, que viajan cifradas y no se descifran en ningún punto del servidor.
- **RevenueCat** recibe un identificador de cliente y el estado de compra. No recibe el contenido de la App.
- **AdMob** recibe el identificador de publicidad de tu dispositivo.

Cada servicio tiene su propia política de privacidad:
- [RevenueCat Privacy Policy](https://www.revenuecat.com/privacy)
- [Google Privacy Policy](https://policies.google.com/privacy)
- [Groq Privacy Policy](https://groq.com/privacy-policy/)
- [Supabase Privacy Policy](https://supabase.com/privacy)

---

## 4. Almacenamiento y seguridad

### 4.1 Qué está cifrado, y qué no

Con precisión, porque la diferencia importa:

- **Grimorio y notas personales** — cifrados con **AES-256 en tu propio dispositivo**, antes de salir de él. El servidor almacena texto cifrado y no dispone de la clave: no podemos leer tus notas aunque quisiéramos.
- **Contraseña** — hash bcrypt, irreversible. No se almacena en claro en ningún momento.
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

Para ejercerlos, escribe a **arcanum.magick.app@gmail.com**.

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
