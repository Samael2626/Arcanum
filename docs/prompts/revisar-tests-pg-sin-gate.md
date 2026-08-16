# Prompt — Los 58 tests de Postgres que ningun gate ejecuta

## Objetivo

`arcanum-api/tests_pg/` tiene 58 tests que cubren dinero y concurrencia. Ni el
hook de pre-commit ni el CI los corren. Nunca. Hay que averiguar en que estado
estan de verdad, ponerlos bajo un gate, y arreglar el agujero del fixture que
convierte una base mal apuntada en 58 tracebacks en vez de 58 saltos con motivo.

Rama de partida: `fix/corte-bogota-produccion` (commits `c6e2975` y `fb1812c`).
Commit aparte. No mezclar con el corte de la hora planetaria.

## Estado verificado hoy

### Nadie los ejecuta

```
.githooks/pre-commit:86   pytest tests/ tests_unit/          <- tests_pg no esta
.github/workflows/ci.yml  pytest tests_unit -q
.github/workflows/ci.yml  pytest tests -q                    <- tampoco
```

Barrido sobre todo el repo buscando cualquier otro invocador
(`yml`, `yaml`, `sh`, `ps1`, `toml`, `ini`, `cfg`): **ni uno**.

Y el hook incluso tiene un guardia contra el verde dormido:

```sh
# Un "skipped" masivo significa que los tests de integracion no corrieron.
if [ "${SKIPPED:-0}" -gt 10 ]; then
  fail "Commit BLOQUEADO: $SKIPPED tests saltados"
```

No sirve de nada aqui: estos 58 ni se colectan, asi que no entran en el conteo.
El guardia vigila una puerta por la que este paquete no pasa.

### Que hay dentro

| Archivo | Tests | Que cubre |
|---|---|---|
| `test_routes_p0a_pg.py` | 17 | contrato idempotente p0a |
| `test_revenuecat_webhook_pg.py` | 15 | webhook de pagos |
| `test_routes_transactions_pg.py` | 11 | transacciones |
| `test_usage_service_pg.py` | 11 | concurrencia y doble debito de cuota |
| `test_library_index_pg.py` | 4 | indice de biblioteca |

Se escribieron contra Postgres real a proposito: SQLite no reproduce las
carreras ni crea UUID, JSONB, ARRAY ni `gen_random_uuid()`.

### La base que piden no existe

`tests_pg/conftest.py` documenta levantar:

```
docker run -d --name arcanum-svc-test -e POSTGRES_PASSWORD=test \
    -e POSTGRES_DB=arcanum_migration_test -p 55434:5432 postgres:17-alpine
```

`docker ps -a` en esta maquina: solo `arcanum-test-db` y `arcanum-libfix-db`.
**`arcanum-svc-test` no esta.** Es una base distinta a proposito: `tests/`
construye el esquema con `Base.metadata.create_all`, y aqui hace falta el
esquema REAL que produce Alembic 001->006, que es lo que corre en produccion.

### El agujero del fixture

```python
revision = c.execute(text("SELECT version_num FROM alembic_version")).scalar()
if revision != "006":
    pytest.skip(f"la base de pruebas esta en {revision}, se requiere 006")
```

Cubre "base migrada a otra revision" -> salto ordenado. **No cubre "base sin
migrar"**: ahi el `SELECT` revienta con `UndefinedTable` antes de llegar al
`if`. Apuntar `TEST_DATABASE_URL` a la base equivocada da esto:

```
sin URL                    ->  58 skipped, 9 warnings in 2.19s
con la URL de arcanum_test ->  9 warnings, 58 errors in 42.79s
                               psycopg2.errors.UndefinedTable:
                               relation "alembic_version" does not exist
```

Mismo patron que ya mordio en `_sky_snapshot`: el guardia sabe rechazar el valor
malo pero no la ausencia. Cuarenta segundos de tracebacks donde deberia haber
dos segundos y un motivo legible.

## Lo que NO se sabe todavia, y hay que averiguar

**Si esos 58 pasan.** No se han corrido contra la base correcta en esta sesion.
Es la pregunta central del encargo, no un detalle: llevan sin gate lo suficiente
como para que cualquier cosa haya podido pudrirse debajo. **No asumir que estan
verdes ni que estan rojos. Medirlo.**

## Trabajo

1. **Levantar la base y correrlos por primera vez.** El contenedor documentado,
   migrado a 006 con `scripts/verify_migrations.py`. Capturar la salida cruda,
   pase lo que pase. Ese numero es el entregable principal.

2. **Arreglar el agujero del fixture antes de interpretar nada.** Que una base
   sin `alembic_version` de un skip con motivo — "la base no esta migrada" — y
   no 58 tracebacks. Un `ProgrammingError`/`UndefinedTable` atrapado, o un
   `to_regclass` previo. Test que lo fije: base sin la tabla -> skip, no error.
   Sin esto, cualquiera que apunte mal vuelve a ver el mismo muro de ruido y a
   concluir que "los tests estan rotos" cuando solo estan mal invocados.

3. **Si salen rojos: no arreglar nada todavia.** Diagnosticar y reportar. Un
   test de dinero en rojo puede significar un bug de dinero en produccion, y eso
   se decide con Samuel antes de tocarlo. Distinguir explicitamente tres casos,
   porque el tratamiento es distinto:
   - test podrido (el codigo cambio y el test no),
   - bug real,
   - fallo de entorno.

4. **Ponerlos bajo gate, con el coste medido primero.** Cronometrar la corrida
   completa antes de decidir donde van. Si el hook aguanta el tiempo, al hook;
   si no, al CI con su servicio de Postgres migrado. Lo que NO puede quedar es
   como hoy: cero cobertura y la ilusion de que la suite verde los incluye.
   - Si van al CI: el step de integracion actual define `TEST_DATABASE_URL`
     apuntando a una base de `create_all`. Anadir `tests_pg` ahi sin migrarla
     reproduce exactamente los 58 errores. La base de `tests_pg` necesita
     Alembic aplicado.
   - Si van al hook: que la ausencia de la base **bloquee**, como ya hace con
     `arcanum-test-db`. Un salto silencioso aqui es el verde mentiroso que el
     propio hook dice combatir.

5. **Actualizar la documentacion del conftest** si el contenedor o el puerto
   reales acaban siendo otros. Una receta que no funciona es peor que ninguna:
   manda a la gente a un callejon y parece que el problema es suyo.

## Lo que NO se toca

- **Ningun test se relaja para que pase.** Si un test de concurrencia falla, el
  hallazgo es el fallo. Aflojar el aserto es convertir el gate en decorado.
- **El cortafuegos `_guard()`** que aborta si la URL huele a `supabase`,
  `railway`, `pooler` o `6543`. Se queda, y si se toca es para endurecerlo.
  Ningun test toca produccion.
- **Produccion, Railway, Firebase, RevenueCat, AdMob, migraciones nuevas ni
  `release/p0a-beta`.** Aplicar Alembic sobre la base LOCAL de pruebas no es
  crear una migracion; crear una si lo seria, y esta prohibido.
- **El corte de la hora planetaria** (`fb1812c`). Commit aparte.
- Nunca `ARCANUM_SKIP_HOOKS=1`. Si el hook bloquea, el bloqueo es el dato.

## Entrega final

- SHA y rama.
- **El numero:** cuantos de los 58 pasan, fallan o se saltan, con la salida
  cruda de pytest pegada. Es lo primero que hay que poder leer.
- Desglose por archivo de lo que falle, con el diagnostico de cual de los tres
  casos del punto 3 es cada uno.
- Cuanto tarda la corrida completa, y la decision de gate justificada con ese
  numero.
- La demostracion del punto 2: base sin migrar -> skip con motivo, no traceback.
  Antes y despues.
- Los comandos exactos para levantar la base, verificados de cero en una maquina
  sin ese contenedor.
- Cualquier hallazgo lateral, declarado y sin arreglar dentro de este commit.
