# ARCANUM — App movil premium de practica magica

## Stack
- Flutter + Riverpod (mobile), Firebase (frontend)
- FastAPI + PostgreSQL (backend en Railway)
- RevenueCat (pagos)
- Groq `openai/gpt-oss-120b` (oracle y horoscopo IA). NO es la Claude API,
  pese a que el fichero se llame `claude_service.py`. El nombre del modelo NO se
  escribe en el codigo: sale de `ORACLE_MODEL_FREE` / `ORACLE_MODEL_PREMIUM` en
  `arcanum-api/app/core/config.py`. Ver "Groq: modelo, limites y coste" abajo
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
- Oracle (Groq gpt-oss-120b, respuestas con contexto usuario)
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

## Groq: modelo, limites y coste

El modelo vivo en produccion es **`openai/gpt-oss-120b`**, para oraculo y para
horoscopo. Sale de `arcanum-api/app/core/config.py:48-49`:

```python
ORACLE_MODEL_FREE: str = "openai/gpt-oss-120b"
ORACLE_MODEL_PREMIUM: str = "openai/gpt-oss-120b"
```

Comprobado el 24/09/2026: **ninguna variable de Railway pisa esos dos valores**,
asi que lo que corre es el default del codigo. Gratis y premium usan el MISMO
modelo; la diferencia entre planes no esta en el modelo.

**El nombre del modelo no se escribe en el codigo de servicio.** Entra por
parametro desde `settings`. Hay un test que lo vigila
(`tests_unit/test_oracle_output_guard.py`) porque una constante hardcodeada ya
tumbo produccion con un 404 una vez.

### `llama-3.3-70b-versatile` ya no se usa

Fue el modelo anterior. Lo que esta **comprobado** hoy:

- Nuestra clave recibe `404 model_not_found` al pedirlo.
- En el catalogo de Groq figura como Production/Enterprise, con "Contact Sales".
- **No** aparece en la lista de modelos permitidos de nuestra organizacion.

Lo que **NO** esta comprobado: que Groq lo retirase el 2026-08-16. Esa fecha sale
de blogs de terceros y la pagina oficial de deprecaciones no lo lista. Para
nosotros el efecto practico es el mismo (no hay acceso), pero no es lo mismo
"retirado del catalogo" que "movido a Enterprise". No repetir la fecha como hecho.

### Limites de cuota (consola de Groq, 24/09/2026)

Leidos en Organization Limits para `openai/gpt-oss-120b`, y **confirmados por la
cabecera `x-ratelimit-limit-tokens` de una llamada real**:

| Limite | Valor |
|---|---|
| Peticiones / minuto | 30 |
| Peticiones / dia | 1.000 |
| Tokens / minuto | **8.000** |
| Tokens / dia | 200.000 |

Los **8.000 TPM son de `gpt-oss-120b`**, no una herencia de Llama. La cuenta esta
en plan gratuito: la consola sigue ofreciendo "On Developer plan, you get higher
limits".

El techo que aprieta es TPM, no RPM: una tirada de Cruz Celta ronda los 2.300
tokens, asi que 8.000 TPM son ~3 lecturas por minuto aunque el limite de
peticiones permita 30.

### Precio (docs oficiales de Groq, 24/09/2026)

- Entrada: **$0.15 por millon de tokens**
- Salida: **$0.60 por millon de tokens**

Coste estimado de una Cruz Celta: **~$0.003**. **NO MEDIDA** — es aritmetica sobre
el recuento de tokens, no una factura desglosada por lectura.

Gasto real: **$0.16 en 30 dias**. El coste de IA no es hoy un problema de margen.

## Tests

La suite entera necesita DOS bases con credenciales DISTINTAS:

```
TEST_DATABASE_URL            postgresql://postgres:postgres@localhost:5434/arcanum_test
MIGRATION_TEST_DATABASE_URL  postgresql://postgres:test@localhost:55434/arcanum_migration_test
```

Sin ellas la suite **no falla: salta 172 tests en silencio** y parece verde. Ojo
a la contrasena, que no es la misma en las dos.

### Que contenedor es cada uno

Los nombres enganan, asi que van escritos: **el que se llama `-svc-test` es el de
MIGRACIONES**, no el de la suite.

| Contenedor | Puerto | Base | Para que |
|---|---|---|---|
| `arcanum-test-db` | **5434** | `arcanum_test` | la suite entera (`TEST_DATABASE_URL`) |
| `arcanum-svc-test` | **55434** | `arcanum_migration_test` | solo migraciones (`MIGRATION_TEST_DATABASE_URL`) |

Se levantan con:

```
docker start arcanum-test-db arcanum-svc-test
```

> **`arcanum-migration-test` es un duplicado OBSOLETO. No lo levantes.**
> Publica el mismo puerto 55434 que `arcanum-svc-test`, asi que arrancarlo falla
> con `Bind for 0.0.0.0:55434 failed: port is already allocated` — o peor, si
> gana la carrera, la suite de migraciones acaba hablando con una base vacia que
> nadie ha migrado. Se deja ahi a proposito, sin borrar, pero no se usa.

Comprobar que estan sirviendo lo que se espera, antes de fiarse de un verde:

```
docker exec arcanum-test-db psql -U postgres -lqt   | cut -d'|' -f1
docker exec arcanum-svc-test psql -U postgres -lqt  | cut -d'|' -f1
```

Referencia de una pasada buena (25-sep-2026): **1020 pasan, 1 saltado**. Si ves
~172 saltados, las bases no estan conectadas y ese verde no vale.

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
