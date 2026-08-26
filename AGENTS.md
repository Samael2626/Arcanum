# ARCANUM — App movil premium de practica magica

## Stack
- Flutter + Riverpod (mobile), Firebase (frontend)
- FastAPI + PostgreSQL (backend en Railway)
- RevenueCat (pagos)
- Groq `llama-3.3-70b-versatile` (oracle y horoscopo IA). NO es la Claude API,
  pese a que el fichero se llame `claude_service.py`
- AES-256 (grimorio cifrado)
- Supabase (base de datos)

## Estructura
Monorepo con `arcanum_app/` (Flutter) y `arcanum-api/` (FastAPI).

## Skills
- arcanum-dev: arquitectura y desarrollo general
- arcanum-astrologer: calculos astrologicos (Swiss Ephemeris)
- arcanum-chaos: generador de sigilos (Austin Osman Spare)
- arcanum-clarividente: contenido esoterico y voz del oracle
- arcanum-kabbalist: gematria y Arbol de la Vida
- arcanum-tarot: tiradas e interpretacion (78 arcanos)
- arcanum-translator: traduccion historica EN-ES, glosario, critica y control MQM

## Convenciones
- Riverpod con @riverpod annotation + code generation
- FastAPI routers async con Pydantic v2
- SQLAlchemy async + Alembic migrations
- JWT stateless con refresh tokens
- UI esoterica: old money oscuro, burgundy/navy/dorado mate

## Reglas
- No debatir stack canonico (Riverpod, PostgreSQL, RevenueCat)
- Escribir tests para nuevas features
- Mantener cifrado AES-256 en contenido del grimorio
- Oracle prompts en .claude/agents/ no hardcodeados en backend
- Calendario astral usa ephem real, no aproximaciones
- Sigilos: intencion -> reduccion -> composicion -> carga -> olvido

## Modulos core
- Grimorio (cifrado AES-256, notas personales)
- Oracle (Claude API, respuestas con contexto usuario)
- Tarot (78 cartas, multiples tiradas)
- Sigilos (generador con paradigma chaos magic)
- Calendario astral (efemerides, aspectos, lunares)
- Bitacora magica (registro de practicas sincronizado)

## Despliegue

### Backend (Railway)

```
git push origin main        # esto YA despliega
```

**Desde el 26/08/2026 la rama de produccion es `main` y el auto-deploy esta
ACTIVO.** Es decir:

> **Todo push a `main` se despliega solo a produccion.** Sin paso manual y sin
> confirmacion. Un PR mezclado sale a produccion en cuanto entra.

Antes era `release/p0a-beta` con despliegue manual. El cambio se hizo con
`railway service source connect --repo Samael2626/Arcanum --branch main
--service Arcanum-Code`, y ese comando **dispara un despliegue por si mismo**
ademas de dejar el auto-deploy encendido.

Consecuencia: `main` deja de ser "lo ultimo estable" y pasa a ser "lo que esta
corriendo". Los dos gates en verde ANTES de mezclar, no despues.

Para desplegar a mano, por ejemplo tras cambiar variables y sin commit nuevo:

```
railway redeploy --service Arcanum-Code --from-source --yes
```

**`railway redeploy` a secas rebota el despliegue EXISTENTE**, o sea el commit
viejo. El flag que trae el nuevo es `--from-source`. Sin el, todo parece ir bien
y se redespliega lo mismo que ya habia.

Comprobar cual es el commit vivo, que es lo unico que prueba que aterrizo:

```
railway status --json    # -> activeDeployments[0].meta.commitHash
```

### Hosting (Firebase), y por que no XAMPP

`arcanum_app/web/app-ads.txt` tiene que quedar servido en la RAIZ del dominio que
figure como sitio web del desarrollador en la ficha de Play. Google exige que sea
publico, con HTTPS de certificado valido y disponible siempre. Un XAMPP local no
sirve: escucha en localhost, su certificado es autofirmado y se cae al apagar el
equipo, y ahi AdMob revoca la verificacion.

## Tests

La suite entera necesita DOS bases con credenciales DISTINTAS:

```
TEST_DATABASE_URL            postgresql://postgres:postgres@localhost:5434/arcanum_test
MIGRATION_TEST_DATABASE_URL  postgresql://postgres:test@localhost:55434/arcanum_migration_test
```

Sin ellas la suite **no falla: salta 172 tests en silencio** y parece verde. Ojo
a la contrasena, que no es la misma en las dos.

Si la base de migraciones trae un `alembic_version` sin tablas (resto de un
`downgrade` a medias), resetearla y volver a migrar:

```
docker exec arcanum-svc-test psql -U postgres -d arcanum_migration_test   -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
MIGRATION_TEST_DATABASE_URL=... python scripts/verify_migrations.py
```

Nunca `ARCANUM_SKIP_HOOKS=1`: si el hook bloquea, el bloqueo es el dato.

## Flujo
1. Revisar vault 30-Esoterismo/ y skills antes de implementar
2. Elegir skill ARCANUM segun modulo
3. Integracion backend primero, luego UI
4. Testear en dev antes de merge
5. Commit + push automatico + doc en vault
