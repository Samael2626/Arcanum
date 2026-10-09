# Privacidad del onboarding y perfil natal

Revisión técnica: 2026-10-09. Alcance: registro, consentimiento de datos sensibles, borrador local, reintento del perfil natal y revocación. Fuentes: código y pruebas de esta rama. El cambio no está en producción hasta integrarlo en `main`.

## Veredicto

Se cerraron las rutas que permitían guardar datos natales sin consentimiento vigente y reenviar un perfil pendiente a otra cuenta. La revocación ahora borra en una transacción el perfil natal y el historial de práctica almacenado en el servidor. Los saldos y movimientos contables permanecen, sin respuestas de lecturas en `usage_operations.result`.

| Hallazgo | Evidencia | Cambio o estado |
|---|---|---|
| El borrador natal se escribía en `SharedPreferences` y no se rehidrataba. | [Controlador](../../arcanum_app/lib/features/onboarding/application/onboarding_controller.dart) | Solo vive en memoria. Al arrancar se borran las claves heredadas. |
| El perfil pendiente era texto JSON sin dueño y podía reintentarse después de entrar con otra cuenta. | [Almacén](../../arcanum_app/lib/features/onboarding/application/pending_profile_store.dart), [inicio](../../arcanum_app/lib/main.dart) | Ahora se guarda en `FlutterSecureStorage` con ID de usuario; solo se lee para esa cuenta. El pendiente antiguo sin dueño verificable se descarta. Si alguien dependía de ese reintento, deberá completar de nuevo sus datos natales. |
| La API aceptaba datos natales en el registro y en `PUT /users/me` sin comprobar consentimiento. | [Registro](../../arcanum-api/app/routers/auth.py), [esquema](../../arcanum-api/app/schemas/user.py), [perfil](../../arcanum-api/app/routers/users.py) | El registro solo acepta correo, contraseña y nombre. La escritura de datos natales o tradición preferida exige consentimiento vigente `datos-sensibles-v1`; si falta, responde 403. Los borrados con valores `null` siguen permitidos. |
| La revocación dependía de dos llamadas: podía quedar registrada sin que se borrara el perfil; la carta natal calculada permanecía aparte. | [Consentimientos](../../arcanum-api/app/routers/consents.py), [carta natal](../../arcanum-api/app/models/natal_chart.py) | La misma transacción revoca, borra campos natales y tradición preferida, y elimina la carta natal calculada. Después invalida la caché del contexto del Oráculo. |
| Un reintento podía conservar datos después de un 403 por consentimiento revocado. | [Controlador](../../arcanum_app/lib/features/onboarding/application/onboarding_controller.dart), [errores de API](../../arcanum_app/lib/core/auth/auth_repository.dart) | El 403 borra el pendiente y no lo reencola. La revocación también limpia el pendiente local. |
| La autorización cubre datos natales **y de práctica**, pero la revocación conservaba historiales y entradas. | [Consentimientos](../../arcanum-api/app/routers/consents.py), [Ajustes](../../arcanum_app/lib/features/settings/sensitive_data_consent_settings_card.dart) | La misma transacción borra horóscopos, conversaciones del Oráculo, tiradas, Grimorio, pasajes, marcadores y progreso de lectura, Sendero e informes de contenido. Vacía también los resultados duplicados en `usage_operations`, conservando la contabilidad de créditos. La app exige confirmación explícita y borra solo el progreso local de Sendero de esa cuenta. |

## Límites de los datos

- El servidor conserva el perfil natal sin cifrado adicional por campo. La protección del pendiente local mediante `FlutterSecureStorage` no cambia esto ni convierte el perfil en cifrado de extremo a extremo.
- El cuerpo del Grimorio tiene otro cifrado y otra clave. La revocación borra sus entradas en el servidor. La clave local no se elimina en este flujo porque actualmente es compartida por las cuentas que usan el mismo dispositivo; borrarla impediría descifrar entradas de otra cuenta. Una instalación antigua puede conservar datos locales hasta abrir la versión nueva; no se ha probado el recorrido en todos los dispositivos.
- El borrado no elimina el saldo, los movimientos de crédito ni la cuenta. `usage_operations` conserva metadatos contables y huellas de solicitud, pero su campo `result` queda vacío. En copias de seguridad anteriores, el tiempo de purga sigue sin verificar.
- Una operación de lectura que intenta terminar tras la revocación se rechaza en `UsageService.capture`. Las escrituras del Grimorio, biblioteca personal, Sendero e informes también se rechazan mientras siga revocado el consentimiento. Las escrituras previas al primer consentimiento conservan el comportamiento anterior; revisar esa decisión de producto antes de afirmar que toda práctica exige consentimiento previo.
- El indicador `onboarding_completed` sigue en `SharedPreferences`. El borrador natal no se escribe allí.
- Android declara `allowBackup="false"`. [Android documenta](https://developer.android.com/identity/data/autobackup) que las preferencias entran en Auto Backup por defecto y que, en algunos dispositivos Android 12+, desactivar backup puede no desactivar la transferencia directa entre dispositivos. El dato natal pendiente queda cifrado con el almacén seguro del cliente.
- El [RGPD oficial](https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng) trata las convicciones religiosas o filosóficas como categoría especial (art. 9) y exige medidas apropiadas según el riesgo (art. 32). Esta revisión describe medidas técnicas; no certifica cumplimiento jurídico global.

## Verificación

- Backend: **1140 pasadas y 2 saltadas** en `tests`, `tests_unit` y `tests_pg` con PostgreSQL de pruebas y base aislada de migraciones. Las seis pruebas de `tests/test_consents.py` pasaron, incluidas separación de cuentas, limpieza de copias en contabilidad y bloqueo de lecturas en curso.
- Flutter: las **2 pruebas** de `settings_screen_test.dart` pasaron tras el ajuste de aislamiento de Sendero, incluida la comprobación de que el progreso local de otra cuenta sigue presente. `flutter analyze` de los archivos modificados no informó problemas.
- Pendiente: recorrido en Android de registro, corte de red, revocación y nueva sesión. No usar los tests como prueba de ese recorrido.
