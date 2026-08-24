# Auditoría del repo — lo que el código hace de verdad

Correr esto ANTES de redactar o actualizar cualquier documento legal. Salida esperada: tabla `hallazgo | evidencia archivo:línea | riesgo | fix`.

## 1. Inventario de datos personales

```bash
# Campos persistidos
grep -rn "Column(" arcanum-api/app/db/models.py arcanum-api/app/adapters/ 2>/dev/null | head -60
# Entidades del dominio
grep -rn "class .*:" arcanum-api/app/domain/entities.py
# Lo que la app guarda en el dispositivo
grep -rn "SharedPreferences\|FlutterSecureStorage\|Hive\|sqflite" arcanum_app/lib --include=*.dart | head -30
```
Todo campo que identifique o describa a una persona va a la tabla de la política. Especial atención a fecha/hora/lugar de nacimiento (dato preciso) y a texto libre del usuario (puede contener categorías especiales).

## 2. Qué sale hacia terceros

```bash
grep -rn "httpx\|requests\.\|anthropic\|groq\|api\.groq\|messages.create" arcanum-api/app --include=*.py | head -30
grep -rn "prompt\|system=" arcanum-api/app/services/claude_service.py | head -40
```
Verificar: qué campos exactos entran al prompt; que no viaje email, user_id ni el grimorio.

## 3. Logging de datos sensibles

```bash
grep -rn "logger\.\|logging\.\|print(" arcanum-api/app --include=*.py | grep -iE "prompt|message|content|user|email|token" | head -30
```
Cualquier log que combine identificador + contenido de consulta es hallazgo alto.

## 4. Borrado de cuenta real

```bash
sed -n '30,80p' arcanum-api/app/routers/users.py
grep -rn "cascade\|ondelete" arcanum-api/app --include=*.py | head -20
```
Comprobar: borra usuario, lecturas, grimorio, créditos; propaga a RevenueCat; qué queda retenido y si está declarado.

## 5. Consentimiento

```bash
grep -rn "ConsentInformation\|ConsentForm\|canRequestAds\|AppTrackingTransparency\|consent" arcanum_app/lib --include=*.dart | head -20
grep -rn "consent\|accepted_terms\|policy_version" arcanum-api/app --include=*.py | head -20
```
Estado verificado 2026-08-24: **cero resultados en el lado Flutter** → gap UMP abierto (ver `references/ia-y-datos.md`). Y no hay persistencia de versión de política aceptada → en Colombia la autorización no es probatoria. Ambos son bloqueantes.

## 6. Reporte de contenido generado por IA

```bash
grep -rn "report\|flag\|denunci" arcanum_app/lib/features/oraculo arcanum_app/lib/features/lecturas --include=*.dart | head -20
```
Si no hay affordance de reporte → incumple la política AI-Generated Content de Play.

## 7. Aviso de IA en el chat

```bash
grep -rn "IA\|inteligencia artificial\|modelo" arcanum_app/lib/features/oraculo --include=*.dart | head -20
```
Debe aparecer en la primera interacción (AI Act art. 50).

## 8. Cifrado del grimorio

```bash
grep -rn "encrypt\|AES\|cipher\|Fernet\|secure_storage" arcanum_app/lib arcanum-api/app | head -20
```
La política afirma que la clave permanece en el dispositivo. Si no es cierto en el código actual, **corregir la política en el mismo commit**.

## 9. Coherencia entre documentos

```bash
diff -r legal-site docs/privacy docs/account-deletion 2>&1 | head -20
diff legal-site/privacy/index.html docs/privacy/index.html
diff legal-site/account-deletion/index.html docs/account-deletion/index.html
```
Deben ser idénticos. Y contrastar contra `docs/ARCANUM-Data-Safety.md` y contra `privacy_screen.dart`: tres textos que dicen cosas distintas es el hallazgo más común.

## 10. Secretos y claves

```bash
grep -rniE "api_key|secret|token" arcanum_app/lib arcanum-api/app --include=*.dart --include=*.py | grep -v "os.environ\|String.fromEnvironment\|ReleaseConfig" | head -20
git log --oneline -S"sk-" -- . | head -5
```
Una clave del LLM filtrada es incidente de seguridad y, si permite acceder a datos de usuarios, brecha notificable en 72 h.
