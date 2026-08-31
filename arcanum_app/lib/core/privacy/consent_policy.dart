/// Versiones del texto de consentimiento que se le ensena a la persona.
///
/// POR QUE ES UNA PANTALLA Y NO UNA LINEA EN LOS TERMINOS
///
/// - Apple 5.1.2(i), desde el 13-nov-2025: "You must clearly disclose where
///   personal data will be shared with third parties, including with
///   third-party AI, and obtain explicit permission before doing so".
/// - Google Play, anuncio del 15-jul-2026: las integraciones con IA de terceros
///   quedan sujetas a los requisitos de User Data.
/// - RGPD art. 9(1) leido con C-184/20 y las Directrices CEPD 8/2020: una app
///   de practica magica trata datos que REVELAN convicciones filosoficas o
///   religiosas, aunque la persona no las declare. Eso es categoria especial y
///   pide consentimiento explicito del art. 9(2)(a), separado del general.
/// - Ley 1581/2012 (Colombia) arts. 5, 6 y 9: los datos que revelan
///   convicciones son sensibles; su tratamiento exige autorizacion explicita y
///   hay un deber correlativo de INFORMAR que no esta obligada a darla.
///
/// De ahi las DOS versiones separadas y ninguna premarcada. Marcar por defecto
/// no es consentimiento: es la ausencia de una negativa.
///
/// EL PROVEEDOR ES GROQ, no Anthropic. El fichero del backend se llama
/// `claude_service.py` por herencia, y ese nombre ya indujo el error una vez en
/// la investigacion legal. Nombrar aqui a la empresa equivocada seria decirle a
/// la persona que sus datos van a donde no van.
///
/// POR QUE SE GUARDA EN EL SERVIDOR Y NO SOLO EN EL DISPOSITIVO
///
/// Hubo una implementacion previa (`core/consent/ai_consent.dart`) que guardaba
/// la aceptacion solo en SharedPreferences. Su propio docstring declaraba la
/// limitacion: se pierde al desinstalar y no se puede consultar desde el
/// servidor, asi que NO era prueba auditable. En Colombia la autorizacion hay
/// que poder demostrarla; una preferencia local no demuestra nada.
///
/// `AiConsentService` persiste contra `POST /consents`, que escribe en la tabla
/// `user_consents` con (kind, policy_version, granted, granted_at, revoked_at).
/// El dispositivo mantiene una copia solo como cache para no volver a
/// preguntar. Al unificar las dos implementaciones (2026-08-30) se elimino la
/// local y se quedo esta.
///
/// Si cambia lo que se le cuenta a la persona, la version sube y se vuelve a
/// preguntar: un consentimiento vale para lo que se leyo, no para siempre.
library;

/// Tercero real al que viajan los datos del Oraculo.
const String kAiProvider = 'Groq, Inc.';
const String kAiProviderCountry = 'Estados Unidos';

const aiConsentPolicyVersion = 'groq-ia-v1';
const sensitiveDataConsentPolicyVersion = 'datos-sensibles-v1';
