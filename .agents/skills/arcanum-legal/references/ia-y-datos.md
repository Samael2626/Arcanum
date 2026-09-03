# IA, terceros y datos

## Qué sale del dispositivo hacia un LLM

El oráculo, el tarot y el astral envían contexto del usuario a Groq. Ese contexto puede incluir carta natal (fecha/hora/lugar de nacimiento = dato personal preciso), la consulta escrita (que suele contener salud, relaciones, dinero: categorías especiales) y fragmentos de práctica.

Reglas para cualquier feature que llame a un LLM:

1. **Minimizar el prompt.** No mandar identificadores de usuario, email, ni el grimorio completo. Mandar solo lo que la respuesta necesita. Si el contexto puede reconstruirse desde IDs internos, mandar el símbolo, no el dato crudo.
2. **Consentimiento explícito antes del primer envío**, nombrando al proveedor (hoy: Groq). Exigido por Apple 5.1.2(i) y por GDPR art. 9 cuando el contenido es sensible.
3. **Aviso de IA en la primera interacción** del chat (AI Act art. 50).
4. **Nunca loggear el prompt ni la respuesta con el user_id al lado.** Si hay que depurar, log agregado o hasheado, con retención declarada. Verificado 2026-08-24: `claude_service.py` no loggea prompts — mantenerlo así.
5. **El output no es consejo.** Ver `disclaimers.md`. Avisar al usuario final de que las afirmaciones fácticas del output pueden ser falsas o incompletas y no deben usarse sin verificar.

## Subencargados a documentar

| Tercero | Para qué | Qué recibe | Pendiente |
|---|---|---|---|
| Groq | oráculo, tarot, interpretación (único proveedor de IA en uso) | prompt: contexto natal resumido, cartas y consulta (**el nombre visible ya no se envía**, commit `c59e6cc`) | firmar DPA; **ZDR activado el 03/09/2026** |
| RevenueCat | suscripciones | app user id, eventos de compra | DPA; borrado en cascada al eliminar cuenta |
| Google AdMob | anuncios | identificadores de publicidad, señales de dispositivo | UMP/consentimiento — **gap abierto** |
| Firebase Analytics + Crashlytics | métricas y errores | instance id, eventos, stack traces | consentimiento en EEE; desactivar recolección hasta que se dé |
| Railway / Postgres | hosting y base de datos | todo lo persistido | ubicación de la región y SCC |

Groq (verificado 2026-08-24, https://console.groq.com/docs/your-data y Services Agreement): no retiene inferencias por defecto; no puede usar inputs ni outputs para entrenar salvo permiso expreso del cliente; puede loggear temporalmente inputs/outputs para fiabilidad y abuso, hasta 30 días; **ZDR activable por cualquier cliente en Data Controls**. **Activado el 03/09/2026 para las APIs de inferencia**, así que ese plazo ya no aplica; dicho en la política y en la página de borrado.

Si algún día vuelve a entrar Anthropic (hoy NO está en uso, pese al nombre `claude_service.py`): sus commercial terms dicen "Anthropic may not train models on Customer Content from Services", y la sección D.3 obliga contractualmente a avisar al usuario final de que las afirmaciones fácticas del output pueden ser falsas. Los plazos de retención concretos: **NO COMPROBADO**.

## Gap abierto: consentimiento de ads (UMP)

Verificado 2026-08-24: `arcanum_app/lib/main.dart:29` llama a `MobileAds.instance.initialize()` y no existe ninguna referencia a `ConsentInformation`, `ConsentForm` ni `canRequestAds` en todo `lib/`. Publicar con ads en EEE/UK así infringe la política de consentimiento de Google y el GDPR.

Forma correcta (fuente: https://developers.google.com/admob/flutter/privacy, vía Context7):

```dart
// Al arrancar, ANTES de inicializar MobileAds o pedir cualquier anuncio.
final params = ConsentRequestParameters();
ConsentInformation.instance.requestConsentInfoUpdate(
  params,
  () async {
    ConsentForm.loadAndShowConsentFormIfRequired((loadAndShowError) async {
      if (loadAndShowError != null) return;
      if (await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.initialize();
      }
    });
  },
  (FormError error) {},
);
```

Además, en Ajustes: entrada permanente "Opciones de privacidad" visible cuando
`await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required`,
que abra `ConsentForm.showPrivacyOptionsForm(...)`. Sin ese punto de entrada el consentimiento no es revocable y la política de Google no se cumple.

## iOS: ATT y privacy manifest

- Anuncios personalizados en iOS requieren `AppTrackingTransparency` además del UMP, con `NSUserTrackingUsageDescription` en el Info.plist.
- Privacy manifest (`PrivacyInfo.xcprivacy`) con los tipos de datos recolectados y las *required reason APIs*; los SDKs de terceros deben aportar el suyo firmado. Verificar al preparar el build de iOS. NO COMPROBADO en este repo: la app aún no tiene target iOS auditado.

## Cifrado del grimorio

La política afirma que el contenido del grimorio viaja cifrado con clave en el dispositivo (`privacy_screen.dart`). Antes de repetir esa frase en cualquier documento, auditar que sea cierto en el código actual — es la afirmación con mayor coste si resulta falsa: pasa de imprecisión a declaración engañosa ante la tienda y ante la SIC.
