# Auditoría de seguridad previa a ampliar la beta — 2026-10-05

## Alcance y evidencia

- Revisión de rutas FastAPI, autenticación, autorización, pagos, almacenamiento móvil y empaquetado Docker.
- Ataques reproducidos con `TestClient` y dos cuentas aisladas en PostgreSQL de pruebas; sin datos de usuarios reales ni carga agresiva sobre producción.
- Comprobaciones de solo lectura en producción: `/health` respondió 200, `/admin/migrate/status` 404, `/grimoire` sin sesión 401 y `/docs` 200.
- Escaneo `pip-audit` del entorno instalado antes y después de actualizar dependencias.

## Hallazgos corregidos en esta rama

1. **Cerrar todas las sesiones dejaba vivos los access tokens.** Se añadió `users.auth_epoch`, incluido en cada access token y comparado en cada petición. `/auth/logout-all` incrementa la época y revoca los refresh tokens en la misma transacción. Los tokens anteriores quedan inválidos; un login nuevo funciona. Migración `016`.
2. **Un usuario autenticado podía revocar el refresh token de otra cuenta si conocía el valor.** `/auth/logout` ahora comprueba el propietario antes de borrarlo. La prueba reproduce el fallo anterior y pasa con la corrección.
3. **La imagen Docker podía incluir archivos locales ajenos al backend.** `COPY . .` abarcaba la carpeta Android, donde existen un keystore y un archivo local de contraseñas. Se limita la copia a `arcanum-api/` y `start.sh`; `.dockerignore` usa lista de archivos permitidos y excluye secretos. Esto prueba un riesgo del proceso de build, no que la imagen actualmente desplegada haya contenido esos archivos.
4. **Dependencias antiguas con avisos de seguridad.** Se actualizaron FastAPI, `python-multipart`, `python-dotenv` y pytest. Se sustituyó `python-jose` por PyJWT manteniendo HS256 y el formato JWT existente. `pip-audit` pasó de avisar en 7 paquetes del entorno local a «No known vulnerabilities found». La imagen Docker también actualiza `pip`.

## Pruebas superadas

- 1.135 tests pasados y 2 saltados con las nuevas dependencias y ambas bases PostgreSQL configuradas.
- Ciclo completo de migraciones hasta `016` y vuelta: correcto.
- Pruebas nuevas: aislamiento de lectura, edición y borrado de Grimorio entre dos cuentas; registro sin autoasignarse premium ni créditos; revocación de access/refresh; rechazo de webhook sin secreto.
- `pip check`: sin dependencias rotas. `pip-audit` sobre el entorno actualizado: sin vulnerabilidades conocidas.
- Build Docker completo: correcto; contexto de 5,27 MB. Inspección dentro de la imagen: cero `.env`, `key.properties`, `.jks`, `.p12` o `.pem` bajo `/app`; no existe el árbol Android, sí el backend. La API importa y `pip check` pasa en el contenedor.
- Una prueba adicional confirmó que guardar un perfil cargado antes de `/auth/logout-all` no restaura la época de autenticación revocada. Tokens sin firma o firmados con otra clave devolvieron 401. Se ejecutaron siete pruebas dirigidas en una base aislada: siete pasaron.
- El Android Manifest de `main` desactiva backup; los tokens móviles están en `FlutterSecureStorage`; la URL de API en release usa HTTPS.

## Pendiente antes de ampliar testers

- Revisar el AAB **release** exacto que se subirá a Play. Solo hay APK de debug local; no se puede inferir el contenido del release a partir de ella.
- Aplicar estos cambios en producción después de revisar la rama y verificar el despliegue vivo. Los códigos HTTP comprobados en producción corresponden a la versión anterior.
- Verificar en Railway que Redis esté disponible: el límite de intentos y la blacklist por token hacen `fail-open` cuando Redis falla. La revocación global nueva vive en PostgreSQL y no depende de Redis.
- La copia de `key.properties` guardada junto al keystore en Drive sigue pendiente de separación según `docs/ARCANUM-Pendiente-Seguridad-Keystore.md`.

## Fuentes

- [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [Aviso oficial de python-multipart](https://github.com/advisories/GHSA-pp6c-gr5w-3c5g)
- [Avisos oficiales de Starlette](https://github.com/Kludex/starlette/security/advisories)
- [Versiones FastAPI y compatibilidad con Starlette](https://fastapi.tiangolo.com/release-notes/)
- [PyJWT en PyPI](https://pypi.org/project/PyJWT/)
