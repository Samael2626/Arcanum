# Auditoría de seguridad previa a ampliar la beta — 2026-10-05

## Alcance y evidencia

- Revisión de rutas FastAPI, autenticación, autorización, pagos, almacenamiento móvil y empaquetado Docker.
- Ataques reproducidos con `TestClient` y dos cuentas aisladas en PostgreSQL de pruebas; sin datos de usuarios reales ni carga agresiva sobre producción.
- Comprobaciones de solo lectura en producción: `/health` respondió 200, `/admin/migrate/status` 404, `/grimoire` sin sesión 401 y `/docs` 200.
- Escaneo `pip-audit` del entorno instalado antes y después de actualizar dependencias.

## Hallazgos corregidos en esta rama

1. **Cerrar todas las sesiones dejaba vivos los access tokens.** Se añadió `users.auth_epoch`, incluido en cada access token y comparado en cada petición. `/auth/logout-all` incrementa la época y revoca los refresh tokens en la misma transacción. Los tokens anteriores quedan inválidos; un login nuevo funciona. Migración `017` sobre la `016` de la mesa de tarot que ya está en `main`.
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
