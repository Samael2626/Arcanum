# Auditoría de seguridad previa a ampliar la beta — 2026-10-05

## Alcance y evidencia

- Revisión de rutas FastAPI, autenticación, autorización, pagos, almacenamiento móvil y empaquetado Docker.
- Ataques reproducidos con `TestClient` y dos cuentas aisladas en PostgreSQL de pruebas; sin datos de usuarios reales ni carga agresiva sobre producción.
- Comprobaciones de solo lectura en producción: `/health` respondió 200, `/admin/migrate/status` 404, `/grimoire` sin sesión 401 y `/docs` 200.
- Escaneo `pip-audit` del entorno instalado antes y después de actualizar dependencias.

## Hallazgos corregidos en esta rama

1. **Cerrar todas las sesiones dejaba vivos los access tokens.** Se añadió `users.auth_epoch`, incluido en cada access token y comparado en cada petición. `/auth/logout-all` incrementa la época y revoca los refresh tokens en la misma transacción. Los tokens anteriores quedan inválidos; un login nuevo funciona. Migración `018` (nació como `017`; se renumeró el 6-oct porque `017_add_grimoire_preview` entró antes en `main` desde el taller de sigilos y dos `017` sobre la `016` son dos cabezas en Alembic).
2. **Un usuario autenticado podía revocar el refresh token de otra cuenta si conocía el valor.** `/auth/logout` ahora comprueba el propietario antes de borrarlo. La prueba reproduce el fallo anterior y pasa con la corrección.
3. **La imagen Docker podía incluir archivos locales ajenos al backend.** `COPY . .` abarcaba la carpeta Android, donde existen un keystore y un archivo local de contraseñas. Se limita la copia a `arcanum-api/` y `start.sh`; `.dockerignore` usa lista de archivos permitidos y excluye secretos. Esto prueba un riesgo del proceso de build, no que la imagen actualmente desplegada haya contenido esos archivos.
4. **Dependencias antiguas con avisos de seguridad.** Se actualizaron FastAPI, `python-multipart`, `python-dotenv` y pytest. Se sustituyó `python-jose` por PyJWT manteniendo HS256 y el formato JWT existente. `pip-audit` pasó de avisar en 7 paquetes del entorno local a «No known vulnerabilities found». La imagen Docker también actualiza `pip`.

## Pruebas superadas

- 1.412 tests pasados y 4 saltados con las nuevas dependencias, ambas bases PostgreSQL y el catálogo editorial montado. Los cuatro saltos son tres casos sin JSON ingerido y uno sin `wordfreq`; `tests_pg` pasó completo: 131 de 131.
- Ciclo completo de migraciones hasta `017` y vuelta: correcto.
- Pruebas nuevas: aislamiento de lectura, edición y borrado de Grimorio entre dos cuentas; registro sin autoasignarse premium ni créditos; revocación de access/refresh; rechazo de webhook sin secreto.
- `pip check`: sin dependencias rotas. `pip-audit` sobre el entorno actualizado: sin vulnerabilidades conocidas.
- Build Docker completo desde la rama basada en `main`: correcto; contexto de 1,82 MB. Inspección dentro de la imagen: cero `.env`, `key.properties`, `.jks`, `.p12` o `.pem` bajo `/app`; no existe el árbol Android, sí el backend. La API importa y `pip check` pasa en el contenedor.
- Una prueba adicional confirmó que guardar un perfil cargado antes de `/auth/logout-all` no restaura la época de autenticación revocada. Tokens sin firma o firmados con otra clave devolvieron 401. Se ejecutaron siete pruebas dirigidas en una base aislada: siete pasaron.
- El Android Manifest de `main` desactiva backup; los tokens móviles están en `FlutterSecureStorage`; la URL de API en release usa HTTPS.

## Segunda pasada: concurrencia y caída de Redis

- Se reprodujo un canje doble del mismo refresh token contra PostgreSQL real: dos peticiones simultáneas recibían dos pares nuevos. La consulta y el borrado estaban separados; el segundo borrado no encontraba fila, pero aun así emitía credenciales. El consumo ahora usa `DELETE ... RETURNING` en una operación atómica. La prueba de carrera exige exactamente un canje exitoso y pasó tras la corrección.
- Se modeló un `refresh` ya iniciado que inserta su token después de `logout-all`. Antes ese token recuperaba la sesión. Los refresh tokens nuevos incluyen `auth_epoch` y la rotación lo compara con el usuario actual; los tokens antiguos sin esa reclamación solo son válidos mientras la época siga en cero. La prueba pasó tras el cambio.
- Se reprodujo que una caída de Redis en producción desactivaba el límite de intentos y la comprobación de blacklist. Ahora esos controles responden 503 en producción cuando Redis no está disponible; desarrollo conserva el comportamiento permisivo. La indisponibilidad temporal es preferible a dar por válido un token cuya revocación no puede consultarse.
- La primera corrida de los tests PostgreSQL dio falsos fallos porque `arcanum_migration_test` marcaba revisión 017 pero carecía de `users.auth_epoch`. Se cambió a la base de pruebas aislada `arcanum_migration_test_security`, cuya revisión 017 y columna se comprobaron. En esa base, los 59 tests dirigidos de mesa de tarot y webhook RevenueCat pasaron.
- Se inspeccionó el APK debug local: firma Android Debug, `debuggable=true`, tráfico claro permitido y backup desactivado. Esas propiedades son esperables para debug y no prueban cómo quedará el AAB release.
- Suite completa tras las correcciones, con ambas bases PostgreSQL aisladas y `ARCANUM_DATA_DIR` montado: **1.417 pasaron, 4 saltaron**. Los saltos son tres JSON de ingesta no presentes y `wordfreq` opcional. Se ejecutó sin otra prueba concurrente sobre esas bases. La corrida anterior tuvo una roja causada por dos procesos de pruebas sobre la misma base; el caso pasó aislado y la corrida final pasó completa.
- Se construyó un AAB release local desde esta rama: `arcanum_app/build/app/outputs/bundle/release/app-release.aab`, 90.159.525 bytes, SHA-256 `F89D81DA0693CBCE4E7BAA2B9D2C7273298679AC26D1A77A31A5CB55C9A4D57D`. `bundletool validate` pasó y `jarsigner -verify` confirmó firma de upload; el certificado autofirmado y sin timestamp generó avisos esperables. El manifiesto declara paquete `com.arcanum.magick`, versión 15 / 1.0.7, `allowBackup=false`, sin `debuggable` ni `usesCleartextTraffic`. El APK universal generado desde el AAB mostró lo mismo; bundletool lo firmó con clave debug solo para inspección, no para Play.
- Se revisaron las 891 entradas del AAB: sin nombres de `.env`, `key.properties`, keystore o `google-services.json`; ninguna entrada contiene los marcadores `gsk_`, clave privada PEM, `"private_key"` o `SERVICE_ROLE_KEY`. Esto es una búsqueda de marcadores, no una garantía de ausencia de cualquier secreto imaginable. Los tres archivos locales necesarios para compilar se retiraron del worktree al terminar.
- Del AAB se generó un APK universal con bundletool para inspección: mantiene `allowBackup=false` y no declara `debuggable` ni `usesCleartextTraffic`. Las 7 pruebas Flutter de configuración de red y cifrado del grimorio pasaron. No había dispositivo conectado para instalar y probar el flujo real.
- Comprobación de Railway (solo lectura): `railway status --json` muestra únicamente el servicio `Arcanum-Code`; los nombres de variables de producción no incluyen ninguna `REDIS_*`. El código usa `REDIS_HOST=localhost` por defecto. **Inferencia:** Redis no está configurado en ese despliegue. No se pudo hacer `PING` dentro del contenedor porque Railway SSH respondió «No registered SSH keys found». El commit vivo consultado seguía en `84ed3f6`, anterior al PR. Con la política nueva de cierre seguro, mezclar ahora el PR probablemente haría responder 503 a rutas protegidas. Resolver la infraestructura antes del merge.

## Pendiente antes de ampliar testers

- Comparar el SHA-256 del AAB que se subirá a Play con el artefacto local auditado. Si se recompila o cambia la rama, repetir la inspección. No había dispositivo conectado para una prueba dinámica móvil.
- Aplicar estos cambios en producción después de revisar la rama y verificar el despliegue vivo. Los códigos HTTP comprobados en producción corresponden a la versión anterior.
- Configurar Redis en Railway y enlazar sus variables al backend; verificar conectividad real antes de mezclar este PR. La nueva política devuelve 503 para las rutas protegidas si Redis falla. La revocación global vive en PostgreSQL y no depende de Redis.
- La copia de `key.properties` guardada junto al keystore en Drive sigue pendiente de separación según `docs/ARCANUM-Pendiente-Seguridad-Keystore.md`.

## Fuentes

- [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [Aviso oficial de python-multipart](https://github.com/advisories/GHSA-pp6c-gr5w-3c5g)
- [Avisos oficiales de Starlette](https://github.com/Kludex/starlette/security/advisories)
- [Versiones FastAPI y compatibilidad con Starlette](https://fastapi.tiangolo.com/release-notes/)
- [PyJWT en PyPI](https://pypi.org/project/PyJWT/)

## Ejecución aislada del 7-oct-2026

- Rama del PR #11: `codex/security-beta-2026-10-05`, último commit `d918c0a`. La rama no se mezcló con `main`.
- Entorno Railway aislado `pentest-2026-10-06`: Postgres y Redis propios, backend `Arcanum-Pentest`; despliegue verificado en `d918c0a850591f1a5665950d68116dea500f4a4e`. No se copiaron secretos de producción. El entorno permanece encendido y facturable para completar la prueba móvil.
- Suite del hook: 1291 aprobadas, 3 saltadas por el JSON local opcional de Culpeper; 133 pruebas PostgreSQL aprobadas. El catálogo privado sí estuvo montado. El ciclo de migraciones hasta `018` y 45 pruebas Flutter relevantes habían pasado en esta rama antes de este commit.
- Prueba con dos cuentas sintéticas: creación, login, lectura propia y lista funcionaron; lectura, edición y borrado cruzados devolvieron 404; lectura anónima 401; `logout-all` invalidó access y refresh tokens anteriores con 401.
- Hallazgo corregido: Railway alternaba pares internos `100.64.0.x` entre peticiones, por lo que el límite basado en `request.client.host` no acumulaba intentos. `d5e586a` usa `X-Real-IP` solo desde el proxy de Railway y falla con 503 si esa cabecera falta o es inválida. En staging, cinco logins erróneos devolvieron 401 y el sexto 429; falsificar `X-Real-IP` y `X-Forwarded-For` no evitó el 429.
- Hallazgo corregido: el manejador global de `HTTPException` eliminaba las cabeceras de la excepción. `d918c0a` las preserva. En staging el 429 incluyó `Retry-After: 58`, y el 401 protegido incluyó `WWW-Authenticate: Bearer`.
- Caída controlada de Redis: con el puerto incorrecto, `/health` siguió 200 y `/auth/login` devolvió 503. Tras restaurar la referencia de Railway y verificar el despliegue, el login volvió a 401. Webhook RevenueCat sin firma o con firma falsa: 401; admin de migraciones: 404; JWT `alg:none` y basura: 401; CORS de origen ajeno: 400 sin `Access-Control-Allow-Origin`.

### Artefacto móvil y MobSF

- AAB release firmado, `com.arcanum.magick` 1.0.7 (`versionCode=15`), SHA-256 `2EFB046B73FFFE2B37493DE93591EAA5D3636AE76EB6A4F40442410D3F31F33C`. Pasó `bundletool validate` y `jarsigner -verify`; `allowBackup=false`, sin `debuggable` ni tráfico claro en el manifiesto. El escaneo de 891 entradas no encontró patrones de claves privadas, Groq ni service role.
- MobSF 4.5.4 terminó el análisis del AAB: SHA-256 del APK interno analizado `6F909DB66D56C951A38468FCD166AED4C733B584A880DE74267FD22F248D97CA`, puntuación 49, 3 alertas altas y 10 advertencias. La alerta de firma ausente no concuerda con `jarsigner` sobre el AAB; MobSF evalúa su APK interno y no demuestra que el bundle entregado esté sin firmar. `minSdk=24` expone compatibilidad con Android 7 sin parches: decisión de soporte pendiente. La alerta CBC señala código legado de `flutter_secure_storage`; su configuración actual predeterminada es GCM y migra los datos antiguos. El grimorio también conserva lectura CBC v1 para entradas previas y escribe GCM v2. No se reprodujo un oráculo de padding remoto.
- MobSF encontró un rastreador real, Crashlytics. Sus 152 cadenas marcadas como posibles secretos incluyeron tres coincidencias de clave pública de Google; no coincidieron con patrones de Groq, RevenueCat o llaves privadas. No copiar el JSON bruto del escáner al repositorio ni al vault.
- APK QA separada `com.arcanum.magick.securityqa`, compilada en modo debug con URL de staging, SHA-256 `EC95F76D8C82A27EB579C4945896A0CF791F6C34A841344667C1EA9169AF09E7`. No sustituye al AAB release ni a su firma. Android perdió la conexión ADB y no hay emulador instalado; instalación, proxy y recorrido móvil quedan pendientes.

### Bloqueos de salida a testers

- El AAB release auditado se compiló sin `REVENUECAT_API_KEY` pública: `ReleaseConfig.validateForStartup` lo detendría al arrancar. Hay que localizar esa clave y recompilar el release final; su SHA-256 cambiará y habrá que repetir la comprobación del artefacto.
- Falta Redis de producción antes de mezclar el PR; `main` despliega automáticamente. También siguen pendientes la prueba móvil del release final, las compras de sandbox, la separación de `key.properties` y keystore en Drive y la comparación del AAB auditado con el que se suba a Play.
