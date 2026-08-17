# Checkpoint — `get_alembic_config()` y el fallo disfrazado de resultado

- **Fecha:** 2026-08-16
- **Rama:** `fix/corte-bogota-produccion`
- **SHA:** `082d6c8 fix(migraciones): que get_alembic_config funcione y deje de fallar disfrazado`
- **Worktree:** `D:/tmp/corte-bogota`
- **Alcance:** el codigo que EJECUTA migraciones. Ninguna migracion nueva.

## Antes y despues

```
ANTES
  python -c "from app.db.migrate import get_alembic_config; get_alembic_config()"
  ImportError: cannot import name 'SQLALCHEMY_DATABASE_URL' from 'app.db.session'

  check_migration_status(eng) -> {'status': 'error', 'message': "Error verificando
                                  migraciones: cannot import name 'SQLALCHEMY_...'"}
  run_migrations(eng)         -> {'status': 'error', 'message': "Error en
                                  migraciones: cannot import name 'SQLALCHEMY_...'"}

DESPUES
  get_alembic_config(url) -> Config apuntando a 127.0.0.1:55434/arcanum_migration_test
  check_migration_status  -> success   rev: 006   tablas: 17
  run_migrations          -> {'status': 'success', 'message': 'Migraciones ejecutadas
                              correctamente'}
```

`app/db/session.py` dejo de exportar la constante cuando la URL paso a leerse
dentro de `get_session_factory()`. Nadie actualizo `migrate.py`.

## La regla que faltaba escrita

Lo grave no era el ImportError, era el disfraz: un error de PROGRAMA salia como
valor de retorno, y el llamador decidia si mirarlo. El arranque no lo miraba.

    error de programa (importacion, configuracion ausente) -> excepcion
    fallo operativo esperable (la base no responde)        -> resultado manejado

`MigrationConfigError` para lo primero. El `except` se estrecha a
`SQLAlchemyError` y `CommandError` para lo segundo. La construccion de la Config
sale del `try` a proposito: si no se puede construir, eso no es un fallo de
migracion, es un bug.

Es la tercera variante del mismo patron en este proyecto, y por eso se nombra al
arreglarlo: el `except` de `_sky_snapshot` que no habria atrapado unas
coordenadas `None`, el fixture de `tests_pg` que reventaba en vez de saltar, y
este.

## Dos bugs mas, que el ImportError tapaba

1. **`/admin/migrate-direct` migraba la base equivocada.** Alembic abre su
   propia conexion desde `sqlalchemy.url`, y esa URL salia del ENTORNO — no del
   engine que se le pasa. El endpoint decia migrar la base que llega por query y
   migraba otra, sin dar ningun error. Ahora `run_migrations` toma la URL del
   engine que recibe (`engine_url()`), que es la unica forma de que el endpoint
   signifique lo que promete.
2. **`admin.py` operaba sobre `None`.** Hacia
   `from app.db.session import engine` en tiempo de importacion, cuando ese
   global todavia vale `None`, y nunca se rebinda porque el `import from` copia
   el valor. `/migrate/status` y `/migrate` no podian funcionar **jamas**. Con
   el ImportError delante, no se veia. Pasan a pedir `get_engine()` en cada
   peticion.

## Los tres endpoints

Contra la base local `arcanum-svc-test` (55434), migrada a 006:

```
ANTES
  GET  /admin/migrate/status    HTTP 200  {"status":"error","message":"... cannot import name ..."}
  POST /admin/migrate           HTTP 500  {"detail":"No se pudo verificar estado: ..."}
  POST /admin/migrate-direct    HTTP 500  {"detail":"Error ejecutando migraciones: 500: No se pudo ..."}

DESPUES
  GET  /admin/migrate/status    HTTP 200  {"status":"success","current_revision":"006", ...}
  POST /admin/migrate           HTTP 200  {"status":"success","message":"Migraciones ejecutadas correctamente", ...}
  POST /admin/migrate-direct    HTTP 200  {"status":"success", ...}
```

**Correccion al diagnostico de partida:** solo el primero devolvia 200 con el
error dentro. Los otros dos ya levantaban 500 — mal, pero no en silencio.

De paso, `/migrate-direct` reenvolvia sus propias `HTTPException` en un 500 con
el mensaje `"500: ..."` dentro, perdiendo el codigo original. Se reenvia tal
cual.

## El arranque cambia de comportamiento

`main.py` descartaba lo que devuelve `run_migrations`. Criterio decidido y
escrito en el codigo: **si alguien enciende `RUN_STARTUP_MIGRATIONS`, migrar es
CRITICO** y su fallo impide levantar. Servir trafico contra un esquema que no se
pudo migrar es peor que no levantar: el fallo se convierte en errores dispersos
y dificiles de atribuir, horas despues.

Es lo unico de este commit que puede afectar a un despliegue.

## `RUN_STARTUP_MIGRATIONS` en Railway: NO esta definida

Consultado con el CLI sobre `Arcanum` / `production` / servicio `Arcanum-Code`
(el unico servicio del proyecto). Hay 17 variables y ninguna es esa:

```
ADMIN_TOKEN, DATABASE_URL, ENVIRONMENT, GROQ_API_KEY, RAILWAY_*(11),
REVENUECAT_WEBHOOK_SECRET, SECRET_KEY
```

Toma el default del codigo, `False` (`app/core/config.py:35`). **Era una bomba
armada, no un arranque roto.** El cambio de criterio no altera el arranque de
produccion hoy.

Contexto que lo explica: el `Procfile` corre
`python -m alembic upgrade head` antes de `uvicorn`. Las migraciones se aplican
por CLI en cada despliegue, que es por lo que nadie noto que el camino
programatico llevaba tiempo muerto.

## Pruebas

Once tests en `tests_unit/test_migrate_config.py`. Verificado que **pescan**:
con el arreglo revertido (importacion muerta, `except Exception`, y el arranque
descartando el resultado), **6 de 11 se ponen rojos**.

```
FAILED test_construye_una_config_utilizable
FAILED test_sin_url_toma_la_del_entorno
FAILED test_sin_url_y_sin_entorno_levanta_en_vez_de_devolver_un_diccionario
FAILED test_la_url_sale_del_engine_y_no_del_entorno
FAILED test_un_error_de_configuracion_estalla_y_no_se_devuelve
FAILED test_el_arranque_no_se_traga_un_fallo_de_migracion
6 failed, 5 passed
```

Los 5 que siguen verdes son los del lado operativo, que ya funcionaba: base
caida devolviendo resultado manejado, y el flag apagado no migrando.

**Backend 344 verdes** (333 antes, +11), 3 skipped. **tests_pg 58 verdes**, sin
cambios. El hook corrio los dos paquetes en el commit.

## Unificacion

`scripts/verify_migrations.py` tenia una `Config` propia, puesta como parche
cuando `get_alembic_config()` no servia. Vuelve a la funcion comun: dos formas
de resolver la URL de la base son dos formas de que diverjan.

## Hallazgos laterales — declarados, no arreglados aqui

1. **El mojibake de `admin.py` entro en este commit, obligado.** El hook rechaza
   un archivo con doble codificacion en stage, y este cambio tenia que tocarlo.
   Son las mismas 9 lineas que ya se limpiaron en `7b9edb2` en
   `feat/nombre-y-umbral-foundation`: contenido identico, no diverge.
   `app/core/config.py` sigue sucio en esta rama y no se toco.
2. **`/admin/migrate-direct` acepta cualquier connection string** con solo el
   token de admin, y `ADMIN_TOKEN` esta definido en produccion. Ahora que el
   endpoint funciona de verdad, apunta y migra la base que le digan. Antes era
   inofensivo porque estaba roto. Merece una decision explicita.
3. **El despliegue activo de Railway sale de `release/p0a-beta`**, no de
   `feat/onboarding-5-pasos`:

   ```
   servicio Arcanum-Code · creado 2026-08-12T22:15:11Z
   branch release/p0a-beta · commit 84ad6647
   ```

   Contradice lo que se venia asumiendo sobre que rama despliega, y toca al
   plan del script que anula la hora planetaria de Bogotá: su `--before` debe
   ser el instante del despliegue **de esa** rama, no de la otra. Ademas, el
   despliegue vivo es del 12 de agosto y no contiene ninguno de los arreglos
   de Bogotá. Comprobar y decidir aparte.
