# Privacidad del onboarding y perfil natal

Revisión técnica: 2026-10-09. Alcance: registro, consentimiento de datos sensibles, borrador local, reintento del perfil natal y revocación. Fuentes: código y pruebas de esta rama. El cambio no está en producción hasta integrarlo en `main`.

## Veredicto

Se cerraron las rutas que permitían guardar datos natales sin consentimiento vigente y reenviar un perfil pendiente a otra cuenta. **Sigue abierto el alcance de la revocación sobre el historial y las entradas de práctica**: esta acción borra el perfil y la carta natal, pero no elimina el Grimorio, las lecturas históricas ni las conversaciones del Oráculo. La interfaz ahora lo dice expresamente.

| Hallazgo | Evidencia | Cambio o estado |
|---|---|---|
| El borrador natal se escribía en `SharedPreferences` y no se rehidrataba. | [Controlador](../../arcanum_app/lib/features/onboarding/application/onboarding_controller.dart) | Solo vive en memoria. Al arrancar se borran las claves heredadas. |
| El perfil pendiente era texto JSON sin dueño y podía reintentarse después de entrar con otra cuenta. | [Almacén](../../arcanum_app/lib/features/onboarding/application/pending_profile_store.dart), [inicio](../../arcanum_app/lib/main.dart) | Ahora se guarda en `FlutterSecureStorage` con ID de usuario; solo se lee para esa cuenta. El pendiente antiguo sin dueño verificable se descarta. Si alguien dependía de ese reintento, deberá completar de nuevo sus datos natales. |
| La API aceptaba datos natales en el registro y en `PUT /users/me` sin comprobar consentimiento. | [Registro](../../arcanum-api/app/routers/auth.py), [esquema](../../arcanum-api/app/schemas/user.py), [perfil](../../arcanum-api/app/routers/users.py) | El registro solo acepta correo, contraseña y nombre. La escritura de datos natales o tradición preferida exige consentimiento vigente `datos-sensibles-v1`; si falta, responde 403. Los borrados con valores `null` siguen permitidos. |
| La revocación dependía de dos llamadas: podía quedar registrada sin que se borrara el perfil; la carta natal calculada permanecía aparte. | [Consentimientos](../../arcanum-api/app/routers/consents.py), [carta natal](../../arcanum-api/app/models/natal_chart.py) | La misma transacción revoca, borra campos natales y tradición preferida, y elimina la carta natal calculada. Después invalida la caché del contexto del Oráculo. |
| Un reintento podía conservar datos después de un 403 por consentimiento revocado. | [Controlador](../../arcanum_app/lib/features/onboarding/application/onboarding_controller.dart), [errores de API](../../arcanum_app/lib/core/auth/auth_repository.dart) | El 403 borra el pendiente y no lo reencola. La revocación también limpia el pendiente local. |
| La autorización se presenta como referida a datos natales **y de práctica**, pero el botón de revocación no elimina historiales ni entradas. | [Consentimiento](../../arcanum_app/lib/features/onboarding/presentation/steps/sensitive_data_consent_step.dart), [Ajustes](../../arcanum_app/lib/features/settings/sensitive_data_consent_settings_card.dart), [historial](../../arcanum-api/app/models/horoscope_reading.py) | **Abierto.** Decidir y documentar la base y el alcance de conservación de cada historial, más el camino de borrado correspondiente. No afirmar que la revocación elimina toda la práctica. |

## Límites de los datos

- El servidor conserva el perfil natal sin cifrado adicional por campo. La protección del pendiente local mediante `FlutterSecureStorage` no cambia esto ni convierte el perfil en cifrado de extremo a extremo.
- El cuerpo del Grimorio tiene otro cifrado y otra clave. No se borra al revocar el consentimiento natal; sí se borra al eliminar la cuenta.
- El indicador `onboarding_completed` sigue en `SharedPreferences`. El borrador natal no se escribe allí.
- Android declara `allowBackup="false"`. [Android documenta](https://developer.android.com/identity/data/autobackup) que las preferencias entran en Auto Backup por defecto y que, en algunos dispositivos Android 12+, desactivar backup puede no desactivar la transferencia directa entre dispositivos. El dato natal pendiente queda cifrado con el almacén seguro del cliente.
- El [RGPD oficial](https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng) trata las convicciones religiosas o filosóficas como categoría especial (art. 9) y exige medidas apropiadas según el riesgo (art. 32). Esta revisión describe medidas técnicas; no certifica cumplimiento jurídico global.

## Verificación

- Backend: pruebas dirigidas de consentimiento y autenticación, con PostgreSQL real. La suite principal pasó **1040**, con **1 saltada**. Los **98 tests_pg** pasaron sobre una base aislada creada y migrada hasta la cabeza 016 de esta rama; la base compartida estaba en 017 y no servía para esta revisión.
- Flutter: **22 pruebas** dirigidas pasaron, incluidas separación de cuentas, limpieza del legado, borrado del pendiente tras 403 y revocación. `flutter analyze` de los archivos afectados no informó problemas.
- Pendiente: recorrido en Android de registro, corte de red, revocación y nueva sesión. No usar los tests como prueba de ese recorrido.
