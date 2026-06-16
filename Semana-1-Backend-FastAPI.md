# ARCANUM - Semana 1: Backend FastAPI

## Objetivo
Implementar el backend FastAPI con estructura básica, modelos de base de datos y autenticación JWT con refresh tokens.

## Tareas Detalladas

### 1. Estructura del Proyecto
- Crear directorio `arcanum-api/`
- Estructura de carpetas:
  ```
  app/
  ├── core/         # seguridad, excepciones, middleware
  ├── routers/      # auth, users, astral, grimoire, traditions, materia, divination, oracle, subscriptions
  ├── models/       # SQLAlchemy ORM (8 tablas)
  ├── schemas/      # Pydantic v2 request/response
  └── services/     # servicios auxiliares
  migrations/       # Alembic
  pyproject.toml    # Poetry configuration
  ```

### 2. Configuración Inicial
- Inicializar proyecto con Poetry
- Configurar dependencias:
  - fastapi
  - uvicorn[standard]
  - sqlalchemy[postgresql]
  - alembic
  - pydantic[email]
  - python-jose[cryptography]
  - passlib[bcrypt]
  - python-multipart
  - redis
  - pytest (para testing)
- Configurar variables de entorno (.env)
- Configurar logging básico

### 3. Modelos de Base de datos (SQLAlchemy ORM)
Implementar las 8 tablas definidas en el schema:
1. `users` - tabla principal de usuarios
2. `refresh_tokens` - para manejo de refresh tokens JWT
3. `natal_charts` - cache de cartas natales
4. `grimoire_entries` - entradas del grimorio (cifrado lado cliente)
5. `traditions` - información de las tradiciones
6. `materia_items` - materia arcana (hierbas, piedras, etc.)
7. `divination_sessions` - sesiones de adivinación
8. `oracle_conversations` - historial de conversaciones con IA

### 4. Autenticación JWT
- Implementar security.py con:
  - Funciones para crear access tokens (15 min de expiración)
  - Funciones para crear refresh tokens (30 días de expiración)
  - Funciones para verificar tokens
  - Manejo de blacklist de tokens (usando Redis)
- Implementar endpoints de auth:
  - POST /auth/register - registro de usuarios
  - POST /auth/login - login y generación de tokens
  - POST /auth/refresh - refresh de access token usando refresh token
  - POST /auth/logout - invalidar refresh token
- Seguridad:
  - Hash de contraseñas con bcrypt
  - Validación de email único
  - Manejo adecuado de excepciones

### 5. Migraciones con Alembic
- Configurar Alembic para gestionar migraciones de base de datos
- Crear migración inicial para todas las tablas
- Configurar conexión a PostgreSQL (para desarrollo local)
- Scripts para upgrade/downgrade de base de datos

### 6. Endpoints Básicos de Usuarios
- GET /users/me - obtener información del usuario actual
- PUT /users/me - actualizar perfil de usuario
- GET /users/{id} - obtener información de usuario público (limitado)

### 7. Configuración de Base de Datos
- Configurar conexión a PostgreSQL mediante SQLAlchemy
- Implementar dependency para obtener sesión de DB en endpoints
- Configurar engine y sessionmaker
- Pruebas de conexión básica

### 8. Testing Básico
- Crear estructura de tests
- Escribir pruebas unitarias para:
  - Creación y verificación de tokens JWT
  - Registro y login de usuarios
  - Funciones de seguridad
- Configurar pytest

## Criterios de Aceptación
- [x] Proyecto estructurado correctamente con todas las carpetas necesarias
- [x] Modelo de Usuario implementado con todos los campos del schema
- [x] Modelo de Refresh Tokens implementado
- [x] Sistema de autenticación JWT funcionando (access + refresh tokens) — código completo
- [x] Endpoints de auth/register y auth/login operativos (en código)
- [x] Endpoint de auth/refresh funcionando (en código)
- [x] Migraciones de Alembic configuradas y ejecutables (env.py, script.py.mako, versions/)
- [ ] Conexión a PostgreSQL establecida — no verificable en este entorno (sin Postgres corriendo)
- [ ] Pruebas básicas de autenticación pasando — no verificable en este entorno (sin Python/pytest instalado)
- [x] Documentación básica de API generada por FastAPI (en /docs) — vía Swagger automático, código listo

## Estado Final (cierre Semana 1)

La sesión anterior dejó varios archivos corruptos por interrupciones del clasificador de seguridad
(sintaxis rota, imports inválidos). Se revisó y corrigió todo el código:

- `app/core/security.py`: error de sintaxis en `create_access_token` (`Optional[timedelta]'t None`)
  y faltaba `get_current_user`. Corregido + añadida función completa con `OAuth2PasswordBearer`.
- `app/models/user.py`: `updated_at` no tenía valor inicial → rompía la respuesta de `/auth/register`
  porque el schema `UserResponse` exige `datetime` no nulo. Se añadió `server_default=func.now()`.
- `app/models/oracle_conversation.py` y `divination_session.py`: importaban `JSONB` desde el paquete
  base de `sqlalchemy` (no existe ahí, solo en `sqlalchemy.dialects.postgresql`) → `ImportError`.
  Además tenían comentarios estilo SQL (`--`) en medio de código Python → `SyntaxError`/`TypeError`.
- `app/models/natal_chart.py`, `tradition.py`, `materia_item.py`: mismo problema de import de `JSONB`
  desde el paquete base; `natal_chart.py` además le faltaba importar `String`.
- `app/models/grimoire_entry.py`: paréntesis sin cerrar en `created_at`.
- `app/models/refresh_token.py`: faltaba importar `String` (usado en `token_hash`).
- `migrations/`: faltaba la carpeta `versions/` y `script.py.mako` (requeridos por Alembic).

**Limitación de este entorno:** no hay Python ni PostgreSQL/Redis instalados aquí, así que la
corrección fue por revisión estática exhaustiva del código (lectura completa de cada archivo,
verificación de imports y sintaxis), no por ejecución real del servidor. Antes de continuar con la
Semana 2 se recomienda, en una máquina con Python/Docker:
```
cd arcanum-api
pip install -r requirements.txt
uvicorn app.main:app --reload
# luego probar /docs, /auth/register, /auth/login, /users/me
```

## Próximos Pasos
Una vez completada la Semana 1, continuar con:
- Semana 2: Motor astral (AstroVisor API + horas planetarias + fases lunares)