# ARCANUM

App movil de practica magica: tarot, carta natal, transitos, materia arcana y un
grimorio cifrado. Monorepo con la app Flutter y la API FastAPI.

> **No es un horoscopo.** El proyecto lo tiene declarado como anti-objetivo: la
> app muestra el cielo real calculado con efemerides y ensena a leerlo, no
> predice. Si un texto valdria para cualquier otra persona, esta mal.

---

## Empezar

### 1. Activar los hooks — ANTES del primer commit

```bash
git config core.hooksPath .githooks
```

**Un clon nuevo no lo hace solo.** Sin esto los hooks no corren y los commits se
saltan las comprobaciones de caracteres CJK y de codificacion. No es opcional.

### 2. Estructura

```
arcanum_app/     Flutter + Riverpod
arcanum-api/     FastAPI + PostgreSQL + Alembic
docs/            play-ficha.md y demas
AGENTS.md        despliegue, tests y convenciones -- leelo
```

### 3. Backend

```bash
cd arcanum-api
python -m pip install -r requirements.txt      # Python 3.12
cp .env.example .env                           # rellenar las claves
uvicorn app.main:app --reload
```

### 4. App

```bash
cd arcanum_app
flutter pub get
flutter run
```

En release la app apunta **siempre** a produccion: el override `API_BASE_URL`
solo se respeta en debug, a proposito. Una compilacion de tienda que apunte a
otro sitio por una bandera de linea de comandos es una forma silenciosa de
publicar contra el servidor equivocado.

---

## Ramas

| Rama | Que es |
|---|---|
| `main` | Rama por defecto. Lo ultimo estable y verde. Se parte de aqui |
| `release/p0a-beta` | **Produccion.** Lo que corre en Railway ahora mismo |
| `gh-pages` | Paginas legales publicadas. Se editan **aqui**, no en `arcanum_app/web/` |
| `feat/*`, `fix/*` | Trabajo sin integrar. Entran a `main` por Pull Request |

Hay ramas de agosto con trabajo real todavia sin fusionar. No las borres: se van
integrando de una en una.

`feature/semana-3-flutter` es una **historia huerfana**: no comparte ancestro con
`main`. Un `git diff main...feature/semana-3-flutter` falla con "no merge base" y
puede parecer que la rama esta vacia cuando tiene 532 ficheros propios. Comparala
con dos puntos (`git diff main feature/semana-3-flutter`).

---

## Tests

Los dos gates, y los dos tienen que estar verdes antes de un merge.

```bash
cd arcanum-api
export TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5434/arcanum_test"
export MIGRATION_TEST_DATABASE_URL="postgresql://postgres:test@localhost:55434/arcanum_migration_test"
python -m pytest -q          # 669 passed, 3 skipped

cd ../arcanum_app
flutter analyze              # 0 issues
flutter test                 # 345 passed, 1 skipped
```

**Sin esas dos variables la suite no falla: salta 172 tests en silencio y parece
verde.** Ojo tambien a la contrasena, que no es la misma en las dos bases.

El test saltado de Flutter es el capturador de pantallas, que va por tag:

```bash
flutter test test/capturas --update-goldens --run-skipped
```

**Nunca `ARCANUM_SKIP_HOOKS=1`.** Si el hook bloquea, el bloqueo es el dato.

---

## Que NO se commitea, nunca

```
android/key.properties            claves de firma
android/app/google-services.json  configuracion de Firebase
*.jks                             el keystore
.env                              claves de API
```

Estan en `.gitignore`. Si alguno entra en un commit, **hay que rotar las claves**:
el repositorio es publico y el historial no se olvida.

---

## Idioma

Una regla, y se aplica sola: **acento solo en texto que lee una persona.**

| Donde | Idioma | Acentos |
|---|---|---|
| Identificadores, funciones, variables | Ingles | no |
| Comentarios de codigo | Espanol | **no** |
| Commits, ramas, nombres de fichero | Espanol | **no** |
| Textos de la app que ve quien la usa | Espanol | **si** |
| Documentacion y notas | Espanol | **si** |

Y **nunca caracteres CJK** (chinos, japoneses, coreanos) en ningun sitio. El hook
de pre-commit lo comprueba y para el commit.

---

## Stack

```
Flutter + Riverpod          app
FastAPI + SQLAlchemy        API, Python 3.12
PostgreSQL (Supabase)       datos
Redis                       rate limiting y sesiones
Swiss Ephemeris             calculo astronomico
Groq llama-3.3-70b          oraculo y horoscopo
RevenueCat                  suscripciones
Google AdMob                anuncios bonificados
Railway                     despliegue del backend
AES-256 en el dispositivo   grimorio
```

> El oraculo va por **Groq**, no por la API de Claude, pese a que el fichero se
> llame `claude_service.py` por herencia.
