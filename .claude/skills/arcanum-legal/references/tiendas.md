# Tiendas — Google Play y App Store

Verificado contra fuente oficial 2026-08-24. Re-verificar con WebFetch antes de citar: las políticas cambian sin aviso.

## Google Play

### AI-Generated Content (obligatoria para ARCANUM)
Fuente: https://support.google.com/googleplay/android-developer/answer/13985936

Aplica a apps donde interactuar con un chatbot texto-a-texto es función central. El oráculo de ARCANUM entra de lleno.

Exige:
- **Reporte in-app de contenido ofensivo, sin salir de la app.** Verbatim: "report or flag offensive content to developers without needing to exit the app".
- Usar esos reportes para alimentar filtrado y moderación.
- El developer responde por que el modelo no genere contenido prohibido (Inappropriate Content, CSAE, contenido engañoso).

Implicación ARCANUM: cada respuesta del oráculo/tarot necesita un affordance de reporte (long-press o icono en la burbuja) + endpoint que persista el reporte + revisión. **Sin esto, rechazo.**

### Borrado de cuenta
Fuente: https://support.google.com/googleplay/android-developer/answer/13327111

Dos caminos obligatorios: ruta **in-app** y **URL web** pública que no exija instalar la app. La URL debe nombrar la app o el developer tal como aparece en la ficha. Retención parcial permitida solo por seguridad/fraude/regulación y declarada en la política.

ARCANUM ya tiene ambos (`account_deletion_service.dart` + `legal-site/account-deletion/`). Auditar que el `DELETE /users/me` borre de verdad todo lo asociado, incluido el usuario en RevenueCat.

### Data safety
Formulario en Play Console > App content. Debe coincidir dato por dato con lo que hace el código y con la política de privacidad. Mantener sincronizado `docs/ARCANUM-Data-Safety.md`. Incluye las preguntas de eliminación de datos.

### Ads y consentimiento
AdMob en EEE/UK/Suiza exige mensaje de consentimiento certificado por Google (UMP/CMP TCF v2.2) antes de pedir anuncios personalizados, más un **punto de entrada permanente** a "Opciones de privacidad" si `getPrivacyOptionsRequirementStatus() == required`. Código en `ia-y-datos.md`.

### Suscripciones
Pago obligatorio por Google Play Billing (RevenueCat lo encapsula). La ficha y el paywall deben decir precio, periodicidad, renovación automática y cómo cancelar, antes de comprar.

### Contenido esotérico
No existe política de Play que prohíba tarot/astrología como categoría (verificado: no aparece en el Developer Policy Center). El riesgo real está en **Misrepresentation / Deceptive Behavior** y en **Health**: prometer resultados, curas, o predecir hechos verificables. Ver `disclaimers.md`.

## App Store (Apple)

Citas verbatim de https://developer.apple.com/app-store/review/guidelines/ (2026-08-24):

- **5.1.2(i)** — "You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so."
  Implicación ARCANUM: **modal de consentimiento explícito que nombre a Groq y diga qué se les envía, antes del primer envío.** Un párrafo enterrado en la política no basta. Es el gap más caro de la versión iOS.
- **5.1.1(v)** — si hay creación de cuenta, debe haber borrado de cuenta dentro de la app. No pedir datos personales que no sean centrales a la función.
- **5.1.1(i)** — enlace a la política de privacidad en metadata de App Store Connect **y** dentro de la app, accesible.
- **1.2 (UGC)** — filtrado de material objetable, mecanismo de reporte con respuesta oportuna, bloqueo de usuarios abusivos, contacto publicado. El output del LLM se revisa en la práctica con esta vara.
- **4.3(b)** — "fortune telling" está nombrada explícitamente como categoría saturada: no se aceptan envíos nuevos salvo que ofrezcan "a meaningfully different or improved experience". **ARCANUM debe posicionarse en la ficha como instrumento de práctica (grimorio cifrado, materia, calendario astral, taller de sigilos), nunca como una app más de tiradas.** Riesgo #1 de rechazo en iOS.
- **3.1.1** — desbloquear funciones exige IAP de Apple.
- **5.1.4** — menores: COPPA/GDPR; pedir fecha de nacimiento solo para cumplir la ley.
- Age rating: el cuestionario nuevo (13+/16+/18+) obliga a considerar el impacto del chatbot en la frecuencia de contenido sensible. NO COMPROBADO contra fuente primaria: la fecha límite del cuestionario y el detalle de 1.2.1(a) sobre verificación de edad vienen de prensa secundaria — verificar en developer.apple.com/news antes de fijar el rating.

## Protocolo de rechazo

1. Pedir el texto literal del rechazo y la guideline citada.
2. WebFetch de esa guideline. No responder de memoria.
3. Fix mínimo que satisface la letra + evidencia (captura, ruta de código, línea del binario).
4. Nota de respuesta al reviewer: corta, factual, señalando dónde ver el cambio. Sin discutir la política.
