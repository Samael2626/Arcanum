# arcanum-api

Backend de ARCANUM: FastAPI + PostgreSQL. Carta natal con efemérides locales, oráculo con Groq, grimorio cifrado, créditos y suscripciones.

## El catálogo editorial vive fuera

La Materia Arcana, las interpretaciones del tarot y la voz del Oráculo **no están en este repositorio**. Viven en el repositorio privado **Arcanum-datos**.

El motivo es de licencias: el motor astral usa Swiss Ephemeris, de licencia dual, y la vía elegida es abrir este backend bajo AGPL en vez de comprar la licencia profesional. La AGPL cubre **el programa, no los datos** — el motor se abre, el catálogo no se cede.

Consecuencia práctica: hace falta la variable **`ARCANUM_DATA_DIR`** apuntando a esa carpeta.

```bash
export ARCANUM_DATA_DIR=D:/Proyectos/Arcanum-datos
```

Sin ella:

- los scripts de siembra fallan con un mensaje que dice qué fichero falta y dónde se esperaba;
- el oráculo devuelve **503** en producción, y en desarrollo usa un prompt de respaldo que se declara como tal en su propio texto.

Nunca arranca en silencio con el catálogo a medias. Todo el acceso pasa por `app/core/content.py`, que es el único módulo que conoce rutas de datos.

## Puesta en marcha

```bash
cd arcanum-api
python -m venv .venv && .venv/Scripts/pip install -r requirements.txt
cp .env.example .env          # rellenar DATABASE_URL, GROQ_API_KEY, ARCANUM_DATA_DIR
.venv/Scripts/python.exe -m alembic upgrade head
.venv/Scripts/python.exe -m uvicorn app.main:app --reload
```

## Siembra

Idempotente por slug: repetirla es seguro, y renombrar un slug crea uno nuevo en vez de mover el viejo.

```bash
.venv/Scripts/python.exe scripts/seed_materia.py            # 114 ítems
.venv/Scripts/python.exe scripts/seed_tarot.py              # 22 mayores + 56 menores
.venv/Scripts/python.exe scripts/seed_tarot_golden_dawn.py --env-file .env
```

## Tests

Los de integración necesitan PostgreSQL; sin él se **saltan**, así que un verde sin base de datos no prueba nada.

```bash
TEST_DATABASE_URL="postgresql://postgres@127.0.0.1:5434/arcanum_test" \
  .venv/Scripts/python.exe -m pytest tests/ tests_unit/ -q
```

El hook `pre-commit` corre la suite completa cuando cambia algo de `arcanum-api/` y bloquea el commit si hay rojo. Espera el contenedor `arcanum-test-db`; si está publicado en otro puerto, pásale `TEST_DATABASE_URL` al `git commit`.

## Despliegue

Railway, desde la rama `release/p0a-beta`. **`ARCANUM_DATA_DIR` y el catálogo deben existir en el entorno de despliegue antes de mezclar**, o el oráculo cae con 503 en cuanto arranque.
