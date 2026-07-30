# ARCANUM — App movil premium de practica magica

## Stack
- Flutter + Riverpod (mobile), Firebase (frontend)
- FastAPI + PostgreSQL (backend en Railway)
- RevenueCat (pagos)
- Claude API / Groq (oracle IA)
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

## Flujo
1. Revisar vault 30-Esoterismo/ y skills antes de implementar
2. Elegir skill ARCANUM segun modulo
3. Integracion backend primero, luego UI
4. Testear en dev antes de merge
5. Commit + push automatico + doc en vault
