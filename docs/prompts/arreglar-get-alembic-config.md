# Prompt — `get_alembic_config()` esta roto y el fallo sale disfrazado de resultado

## Objetivo

`app/db/migrate.py` no puede construir su configuracion de Alembic: importa un
nombre que ya no existe. Todo lo que dependa de el falla, y falla **en
silencio**, porque un `except Exception` convierte la excepcion en un
diccionario con cara de respuesta legitima.

Hay que arreglar la importacion, quitar el disfraz, y dejar el camino de
migraciones bajo prueba.

Rama de partida: `fix/corte-bogota-produccion` (HEAD en `cb3daaf`).
Commit aparte. No mezclar con el corte de Bogotá ni con el gate de `tests_pg`.

## El fallo, reproducido

```
python -c "from app.db.migrate import get_alembic_config; get_alembic_config()"
-> ImportError: cannot import name 'SQLALCHEMY_DATABASE_URL' from 'app.db.session'
```

La causa, en `app/db/migrate.py:22-29`:

```python
def get_alembic_config() -> Config:
    """Retorna Config de Alembic con DATABASE_URL del env."""
    from app.db.session import SQLALCHEMY_DATABASE_URL   # <- ya no existe
```

`app/db/session.py` dejo de exportar esa constante: ahora la URL se lee dentro
de `get_session_factory()`, con `os.getenv("DATABASE_URL")`, y el engine se
construye perezosamente. Nadie actualizo `migrate.py`.

## Por que importa mas de lo que parece

### 1. El fallo va envuelto en un `{"status": "..."}`

`migrate.py:54` y `migrate.py:100`:

```python
except Exception as e:
    return {"status": "error", "message": f"Error en migraciones: {str(e)}"}
```

Una excepcion de importacion —un bug de programa, no una condicion
esperable— sale como un valor de retorno normal. Quien llame a esto recibe un
diccionario, no un estallido, y el llamador decide si mirarlo. **Falla en
silencio con cara de resultado.**

Es la tercera variante del mismo patron en este proyecto, despues del `except`
de `_sky_snapshot` que no habria atrapado unas coordenadas `None` y del fixture
de `tests_pg` que reventaba en vez de saltar. Merece la pena nombrarlo al
arreglarlo.

### 2. Esta en el arranque de la aplicacion

`app/main.py:22-25`:

```python
async def lifespan(app: FastAPI):
    if settings.RUN_STARTUP_MIGRATIONS:
        run_migrations(engine)
```

El `lifespan` **descarta el valor de retorno**. Si el flag esta activo, cada
arranque intenta migrar, falla, y la app levanta como si nada.

> **No comprobado:** el default es `RUN_STARTUP_MIGRATIONS: bool = False`
> (`app/core/config.py:35`), pero no se ha verificado que valor tiene en
> Railway. **Averiguarlo es parte del encargo**, porque decide si esto es un
> arranque roto en produccion o solo una bomba armada. No asumir ninguno de los
> dos.

### 3. Los endpoints de admin lo exponen siempre

`app/routers/admin.py`, independientes de cualquier flag:

```
GET  /migrate/status    -> check_migration_status(engine)
POST /migrate           -> run_migrations(engine)
POST /migrate-direct    -> run_migrations(custom_engine)
```

Los tres devuelven hoy `{"status": "error", "message": "... cannot import name
..."}` con HTTP 200. Un error de servidor servido como exito.

### 4. Ya causo dano observable

`scripts/verify_migrations.py` no se podia ejecutar por esta misma razon, y es
el paso que crea el esquema real de pruebas. Por eso la base de `tests_pg` nunca
se habia levantado en esta maquina y sus 58 tests llevaban sin correrse lo
suficiente como para que nadie supiera si pasaban. Se arreglo ahi construyendo
una `Config` propia — **eso resolvio el sintoma en un script, no la causa.**

## Trabajo

1. **Arreglar `get_alembic_config()` en la fuente.** La URL debe salir del mismo
   sitio del que sale para el resto de la aplicacion, no de una copia. Si
   `verify_migrations.py` acabo con su propia `Config` como parche, unificar:
   dos formas de resolver la URL de la base son dos formas de que diverjan.

2. **Que el fallo deje de ir disfrazado.** Un `ImportError` o un fallo de
   configuracion no es un `{"status": "error"}`: es un error de programa y debe
   estallar. Distinguir explicitamente:
   - error de programa (importacion, configuracion ausente) -> excepcion,
   - fallo operativo esperable (la base no responde) -> resultado manejado.

   Si se conserva el diccionario para los endpoints, que **el codigo HTTP
   acompane**: un fallo de migracion no puede seguir devolviendo 200.

3. **El arranque no puede tragarse el resultado.** `main.py` descarta lo que
   devuelve `run_migrations`. Decidir y dejar escrito el criterio: o las
   migraciones de arranque son criticas y su fallo impide levantar, o son
   opcionales y su fallo se registra ruidosamente. Lo que no vale es lo de hoy,
   que es no enterarse. **Fallar ruidoso, nunca silencioso.**

4. **Averiguar el valor real de `RUN_STARTUP_MIGRATIONS` en Railway** y anotarlo.
   Cambia el diagnostico por completo.

5. **Tests que fijen las tres cosas**, en `tests_unit/`:
   - `get_alembic_config()` construye una `Config` utilizable;
   - un fallo de configuracion levanta, no devuelve un diccionario;
   - el camino de arranque no se traga un fallo de migracion.

   Verificar que **pescan**: con el arreglo revertido tienen que ponerse rojos.
   Que pasen en verde no demuestra nada si no se demuestra que saben fallar.

## Lo que NO se toca

- **Ninguna migracion nueva.** La prohibicion sigue vigente. Esto arregla el
  codigo que EJECUTA migraciones, no el conjunto de migraciones.
- **No ejecutar migraciones contra produccion** para comprobar el arreglo. Base
  local. `arcanum-svc-test` en el 55434 ya existe y esta migrada a 006.
- **El cortafuegos de `tests_pg/conftest.py`** (`_guard()`, que aborta si la URL
  huele a `supabase`, `railway`, `pooler` o `6543`). Se queda.
- Produccion, Railway, Firebase, RevenueCat, AdMob, `release/p0a-beta`.
- El corte de Bogotá (`fb1812c`, `c6e2975`) y el gate de `tests_pg` (`297878e`).
- Nunca `ARCANUM_SKIP_HOOKS=1`. Si el hook bloquea, el bloqueo es el dato.
- El job de Flutter del CI sigue rojo por `dart format` en 22 archivos. Es
  previo y mecanico: **no entra aqui**.

## Aviso de infraestructura

- El hook necesita `arcanum-test-db` en el **5434** (el 5433 lo ocupa
  `botlaw-pg`) y `arcanum-svc-test` en el **55434**, migrada a 006. Las dos.
- `arcanum-libfix-db` disputa puerto con `arcanum-svc-test`: si esta arriba, el
  gate no puede levantar su base.
- Push SOLO a `fix/corte-bogota-produccion`.

## Entrega final

- SHA y rama.
- La reproduccion del fallo ANTES y su ausencia DESPUES, con la salida cruda.
- El valor real de `RUN_STARTUP_MIGRATIONS` en Railway, y que implica.
- Los tres endpoints de `admin.py` respondiendo como deben, con su codigo HTTP.
- La demostracion de que los tests nuevos pescan: rojos con el arreglo revertido.
- Numeros de la suite antes y despues, incluidos los 58 de `tests_pg`.
- Si el arranque cambia de comportamiento, decirlo explicitamente: es lo unico
  de este commit que puede afectar a un despliegue.
- Cualquier hallazgo lateral, declarado y sin arreglar dentro de este commit.
