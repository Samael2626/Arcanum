# Checkpoint — Los 58 tests_pg que ningun gate ejecutaba

- **Fecha:** 2026-08-16
- **Rama:** `fix/corte-bogota-produccion`
- **SHA:** `297878e test(gates): poner los 58 tests_pg bajo gate y arreglar su fixture`
- **Worktree:** `D:/tmp/corte-bogota`
- **Alcance:** el gate y el fixture. Ningun test relajado, ningun aserto tocado.

## El numero

Es lo primero que habia que poder leer, y la respuesta es buena:

```
58 passed, 53 warnings in 10.50s
58 passed, 53 warnings in  8.58s
58 passed, 53 warnings in  8.47s
58 passed, 53 warnings in  9.05s
```

**Los 58 pasan.** Cero fallos, cero saltos, cuatro corridas. No hay tests
podridos, no hay bug de dinero, no hay fallo de entorno. El paquete estaba
sano — lo que no habia era gate.

Nadie los habia corrido: el hook miraba `tests/ tests_unit/`, el CI corria
`tests_unit` y `tests`, y el barrido por `yml|yaml|sh|ps1|toml|ini|cfg` no
encontraba otro invocador. El guardia de "skipped masivo" del hook tampoco los
cubria: si no se colectan, no entran en el conteo. Vigilaba una puerta por la
que este paquete no pasaba.

## El agujero del fixture — antes y despues

El guardia de revision sabia rechazar una base migrada a OTRA revision, pero no
una base SIN migrar: el `SELECT version_num FROM alembic_version` reventaba
antes de llegar al `if`. Mismo patron que mordio en `_sky_snapshot`: se rechaza
el valor malo, no la ausencia.

Contra la misma base recien creada y sin migrar:

```
ANTES     9 warnings, 58 errors in 25.25s
          sqlalchemy.exc.ProgrammingError: (psycopg2.errors.UndefinedTable)
          relation "alembic_version" does not exist        (conftest.py:42)

DESPUES   58 skipped, 9 warnings in 2.19s
          SKIPPED: la base de pruebas no esta migrada (no existe la tabla
          alembic_version). Levantala y migrala:
            docker run -d --name arcanum-svc-test ...
            MIGRATION_TEST_DATABASE_URL=... python scripts/verify_migrations.py
```

Veinticinco segundos de muro de ruido pasan a dos segundos y un motivo con la
receta dentro. Sin eso, cualquiera que apunte mal la URL vuelve a concluir que
"los tests estan rotos" cuando solo estan mal invocados.

Se pregunta con `to_regclass`, que devuelve NULL en vez de lanzar: se pregunta,
no se tantea con un `except`.

Ocho tests en `tests_unit/test_tests_pg_conftest.py` lo fijan. Viven ahi a
proposito: **un test que vigila el arranque de `tests_pg` no puede depender de
que `tests_pg` arranque**. Verificado que pescan — con el `if` quitado:

```
E  AssertionError: assert 'no esta migrada' in 'la base de pruebas esta en None, se requiere 006'
1 failed, 7 passed
```

Incluyen que el cortafuegos `_guard()` sigue abortando ante `supabase`,
`railway`, `pooler` y `6543`. No se relaja: se fija.

## La receta documentada no funcionaba

`scripts/verify_migrations.py` estaba muerto por doble deriva de firma:

```
TypeError: get_alembic_config() takes 0 positional arguments but 1 was given
ImportError: cannot import name 'SQLALCHEMY_DATABASE_URL' from 'app.db.session'
```

O sea que el paso 2 de la receta del conftest — el que crea el esquema — no se
podia ejecutar. Una receta que no funciona es peor que ninguna: manda a la
gente a un callejon y parece que el problema es suyo. El script construye ahora
su propia `Config` de Alembic, sin pasar por `get_alembic_config()`.

## Comandos verificados de cero

Contenedor **destruido** (`docker rm -f`) y rehecho, desde `arcanum-api/`:

```
docker run -d --name arcanum-svc-test -e POSTGRES_PASSWORD=test \
    -e POSTGRES_DB=arcanum_migration_test -p 55434:5432 postgres:17-alpine
    -> acepta conexiones tras 3s

URL=postgresql://postgres:test@127.0.0.1:55434/arcanum_migration_test

MIGRATION_TEST_DATABASE_URL=$URL python -m pytest tests_pg -q
    -> 58 skipped in 2.24s          (sin migrar: salto con motivo)

MIGRATION_TEST_DATABASE_URL=$URL python scripts/verify_migrations.py
    -> Migraciones 005/006 verificadas.

MIGRATION_TEST_DATABASE_URL=$URL python -m pytest tests_pg -q
    -> 58 passed in 7.76s
```

El conftest documenta ahora esta secuencia entera, no un fragmento.

## El gate: al hook Y al CI

**Nueve segundos.** Ese numero decide: al hook, porque es barato para lo que
cubre. Y tambien al CI, porque el hook es de esta maquina y el verde compartido
tambien mentia.

Base **aparte** en los dos (`arcanum-svc-test` / `arcanum_migration_test`): la
de `tests/` la construye `create_all` y aqui hace falta la de Alembic. Anadir
`tests_pg` a la base existente del CI habria reproducido los 58 errores.

Las dos formas de fallar bloquean, y esta probado que bloquean:

```
sin contenedor      [pre-commit] No se pudo levantar arcanum-svc-test. Commit BLOQUEADO.
                    ...seguido de la receta completa para crearlo.

base sin migrar     58 skipped, 9 warnings in 2.09s
                    [pre-commit] Commit BLOQUEADO: 58 tests_pg saltados.
```

HEAD no se movio en ninguno de los dos casos. Y en el commit real el gate corrio
de verdad: `[pre-commit] tests_pg: verde (esquema Alembic real).`

En el hook cualquier salto bloquea (`> 0`, no `> 10`): aqui un salto solo puede
significar base mal migrada o URL a otro sitio.

## Hallazgos laterales — declarados, no arreglados aqui

1. **`get_alembic_config()` esta roto en produccion.** Importa
   `SQLALCHEMY_DATABASE_URL` de `app.db.session`, que ya no lo exporta. Lo usan
   `run_migrations()` y `check_migration_status()`, o sea `/admin/migrate` y las
   migraciones de arranque. Y ahi lo tapa un `except Exception` que devuelve
   `{"status": "error"}`: falla en silencio, con cara de resultado. Toca el
   camino de migraciones de produccion — commit aparte, y decision de Samuel.
2. **El CI ya estaba en rojo antes de este commit**, y no por el backend: el job
   de Flutter falla en `dart format --set-exit-if-changed` con 22 archivos sin
   formatear. El verde compartido de esta rama no existia. Reformatear 22
   archivos es otro commit.
3. **`arcanum-libfix-db` reclama el mismo puerto 55434.** Esta parado desde hace
   dias, pero si alguien lo arranca, `arcanum-svc-test` deja de poder levantar.
   Dos contenedores de pruebas peleando por un puerto es una trampa futura.
