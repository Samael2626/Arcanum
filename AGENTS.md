# ARCANUM — App móvil de práctica mágica

## Stack
- Flutter + Riverpod (mobile)
- FastAPI + PostgreSQL (backend)
- RevenueCat (pagos)
- Claude API / Groq (oracle IA)
- AES-256 (grimorio cifrado)
- Supabase (base de datos)

## Proyecto
Monorepo con `arcanum_app/` (Flutter) y `arcanum-api/` (FastAPI).
Deploy: Firebase (frontend), Railway (backend).

## Convenciones
- Riverpod con `@riverpod` annotation + code generation
- FastAPI routers async con Pydantic v2
- SQLAlchemy async + Alembic migrations
- JWT stateless con refresh tokens

## Skills disponibles
- arcanum-dev: arquitectura general
- arcanum-astrologer: cálculos astrológicos
- arcanum-chaos: generador de sigilos
- arcanum-clarividente: contenido esotérico
- arcanum-kabbalist: gematría y Árbol de la Vida
- arcanum-tarot: tiradas e interpretación

## Reglas
- No debatir stack canónico (Riverpod, PostgreSQL, RevenueCat)
- Escribir tests para nuevas features
- Mantener cifrado AES-256 en contenido del grimorio
