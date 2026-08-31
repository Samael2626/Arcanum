# ARCANUM - Inventario Data Safety

Fecha de auditoria: **2026-08-30** (sustituye a la de 2026-08-10)
Paquete Android: `com.arcanum.magick`
Politica de referencia: rama `gh-pages`, `privacy-policy.md`, version **2026-08-30**.
Publicada en https://samael2626.github.io/Arcanum/privacy-policy.html

Borrador tecnico para cargar en Play Console. El formulario lo firma Samuel: la
responsabilidad de que coincida con el binario es del desarrollador, no de esta
tabla.

> **Lo primero: el envio se hace SIN anuncios.**
> `ReleaseConfig.adsEnabled` viene de `bool.fromEnvironment('ADS_ENABLED')`, que
> vale `false` salvo que se compile pasandolo, y `main.dart:29` solo inicializa
> `MobileAds` dentro de ese `if`. El build de lanzamiento **no carga el SDK de
> anuncios ni recoge Ad ID**.
>
> Declarar recogida de datos publicitarios que no ocurre es una discrepancia de
> Data safety igual de sancionable que omitir una que si ocurre. Las filas de
> anuncios de abajo van marcadas `NO APLICA HOY` y **solo se activan en el mismo
> envio en que se active `ADS_ENABLED`** — que a su vez exige implementar UMP
> antes (ver bloqueos).

## Respuestas base

- La app recopila datos: **Si**.
- La app comparte datos con terceros: **Si**. Groq, Firebase, RevenueCat y
  Railway actuan como encargados del tratamiento; Play cuenta como
  "compartido" la transferencia a Groq y a Firebase Crashlytics.
- Datos cifrados en transito: **Si**, TLS en todos los endpoints.
- Solicitud de eliminacion: **Si**, en la app (`Ajustes -> Eliminar cuenta y
  datos`) y en `https://samael2626.github.io/Arcanum/account-deletion.html`.
- Cuenta obligatoria: **Si**.

## Inventario real

| Tipo Play | Datos reales | Evidencia | Recopilado | Compartido | Finalidad | Obligatorio |
|---|---|---|---:|---:|---|---:|
| Info personal — correo, nombre, ID de usuario | `users.email`, `display_name`, `revenuecat_customer_id` | `app/models/user.py:12-23` | Si | RevenueCat (solo el ID de cliente); **Groq recibe `display_name`** (`oracle_context.py:118`) | Gestion de cuenta, compras, fraude, generar la lectura | Si |
| Info personal — otra (fecha de nacimiento) | `birth_date`, `birth_time` | `app/models/user.py:15-16` | Si | Groq recibe el contexto astral derivado | Calculo de carta natal | Si |
| Ubicacion — aproximada | `birth_city`, `birth_lat/lon`, `birth_timezone` del **lugar de nacimiento**, no de la ubicacion actual | `app/models/user.py:17-20` | Si | Groq recibe el contexto derivado | Calculo de carta natal | Si |
| Info financiera — historial de compras | `credit_ledger`, `revenuecat_events`, `subscription_tier` | `app/models/credit_ledger.py` | Si | RevenueCat, Google Play | Compras, saldo, reembolsos, fraude | Si al comprar |
| Actividad de la app — interacciones | Cuotas, `usage_operations`, sesiones de adivinacion. **Solo en nuestro servidor**: no salen a Firebase | `app/models/usage_operation.py` | Si | No | Funcionalidad y limites de uso | Parcial |
| Contenido generado por usuario — otro | Preguntas al Oraculo (`oracle_conversations.messages`, **en claro**), preguntas de tirada (cifradas), grimorio (cuerpo **cifrado en dispositivo**; titulo y etiquetas en claro), denuncias de contenido | `app/models/oracle_conversation.py:13`, `divination_session.py:16`, `grimoire_entry.py:15`, `content_report.py` | Si | Groq recibe la pregunta y las cartas; **no** recibe el grimorio | Generar la lectura, atender denuncias | Si al usar esas funciones |
| Info y rendimiento — fallos y diagnosticos | Crashlytics, excepciones, rendimiento | `main.dart` (Firebase) | Si | Firebase | Estabilidad | Si en release |
| Identificadores de dispositivo | Firebase Installation ID (Core + Crashlytics) | Firebase Core | Si | Firebase | Diagnostico | Si |
| Info de autenticacion | `hashed_password`, `refresh_tokens` | `app/models/user.py:13`, `refresh_token.py` | Si | No sale a ningun tercero | Seguridad de la cuenta | Si |
| ~~Ubicacion aproximada por IP para anuncios~~ | — | — | **NO APLICA HOY** | — | — | — |
| ~~Ad ID / App Set ID~~ | — | — | **NO APLICA HOY** | — | — | — |
| ~~Interacciones y diagnosticos publicitarios~~ | — | — | **NO APLICA HOY** | — | — | — |

Precisiones que Play exige marcar bien y suelen fallarse:

- **La ubicacion es la del NACIMIENTO, no la del usuario.** La app no pide
  permiso de localizacion y no lee GPS. Se declara como dato aportado por el
  usuario, no como ubicacion recogida del dispositivo.
- **El grimorio no esta del todo cifrado.** El cuerpo si, en el dispositivo; el
  titulo y las etiquetas viajan en claro. La politica lo dice con esas mismas
  palabras y el formulario debe declarar el contenido de usuario como recogido.
- **Las conversaciones del Oraculo se guardan en claro.** No marcar cifrado en
  reposo para ese contenido.

## Datos NO recogidos

Sin acceso en codigo a contactos, calendario, SMS, llamadas, fotos, video,
audio, archivos del usuario, salud, actividad fisica ni ubicacion del
dispositivo. No hay permisos peligrosos en el manifiesto para ninguno de ellos.

## Proveedores y evidencia

- **Groq** — recibe pregunta, contexto astral y cartas. `claude_service.py:131`
  arma el mensaje: sin correo, sin `user_id`, sin grimorio. Declara no entrenar
  con entradas ni salidas; **retiene hasta 30 dias por fiabilidad y abuso
  mientras ZDR no este activo**: https://console.groq.com/docs/your-data
- **Firebase Crashlytics** — https://firebase.google.com/support/privacy/
  **Analytics NO esta en uso ni empaquetado.** La dependencia
  `firebase_analytics` se retiro de `pubspec.yaml`; no hay ninguna llamada en
  `lib/`. No declarar analitica de uso.
- **RevenueCat** — https://www.revenuecat.com/docs/platform-resources/google-platform-resources/google-plays-data-safety
- **Railway** — aloja API y base de datos; trata en Estados Unidos; subencargados
  en https://trust.railway.com/item/subprocessors
- **Definiciones del formulario** — https://support.google.com/googleplay/android-developer/answer/10787469

## Bloqueos antes de enviar

1. **Firmar el DPA de Railway** (DocuSign, Seccion 14). Es el unico proveedor que
   exige acto de firma y el que custodia toda la base.
2. **Activar ZDR en Groq Data Controls.** Mientras no lo este, la politica debe
   seguir declarando la retencion de 30 dias; al activarlo, corregir la frase.
3. **Pedir a RevenueCat aviso previo de subencargados** por escrito (borrador en
   el vault). Su DPA solo lo ofrece a peticion.
4. Publicar y probar las URLs de privacidad, terminos y eliminacion.
5. Confirmar que `arcanum.magick.app@gmail.com` recibe correo y fijar el SLA de
   eliminacion que promete la politica.
6. Confirmar la identidad legal que aparece en Play y que coincide con el
   responsable declarado en la politica.
7. Documentar el plazo de retencion de los backups de PostgreSQL en Railway. La
   politica promete borrado; un backup que sobrevive meses lo contradice.
8. **No activar `ADS_ENABLED` sin UMP.** `main.dart` lleva el TODO puesto. Si se
   activa, hay que rehacer las tres filas tachadas de la tabla y volver a enviar
   el formulario. Gradle solo exige `ADMOB_APP_ID` cuando `ADS_ENABLED=true`:
   el build de lanzamiento sale sin anuncios y sin esa credencial.
9. **`display_name` viaja a Groq** (`oracle_context.py:118`). Declarado en la
   politica publicada y en el dialogo de consentimiento. Al marcar el formulario,
   el nombre cuenta como dato personal COMPARTIDO, no solo recogido.

## Coherencia

Estos tres textos deben decir lo mismo, y se revisan juntos:

- rama `gh-pages`: `privacy-policy.md`, `terms-of-service.md`, `account-deletion.md` (**la fuente**)
- `arcanum_app/lib/features/settings/privacy_screen.dart`
- `ReleaseConfig.policyVersion` y las tres URLs de `release_config.dart`
- este inventario

No debe existir ninguna otra copia de los textos legales en este repositorio.
Ver `legal-site/README.md`.
