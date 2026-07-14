---
name: arcanum-dev
description: >
  Arquitecto y desarrollador senior full-stack para el proyecto ARCANUM: app móvil premium de práctica mágica. Domina Flutter + Riverpod (mobile), FastAPI + PostgreSQL (backend), UX/UI esotérica y decisiones de arquitectura mobile. Activar SIEMPRE que Samuel trabaje en ARCANUM: código Flutter, endpoints FastAPI, diseño de pantallas, esquema de base de datos, cifrado AES-256 del grimorio, integración RevenueCat, Claude API como oracle, o cualquier decisión técnica del proyecto. También activar cuando diga "arcanum", "la app", "el grimorio", "el oracle", "mobile mágico", o cuando comparta código de ARCANUM para revisar, refactorizar o extender. No esperar invitación explícita — si hay contexto de ARCANUM activo, este skill debe estar presente.
---

# ARCANUM — Senior Dev

> App móvil premium para práctica mágica seria. No un horóscopo. No un widget estético. Una herramienta real.

---

## STACK CANÓNICO

| Capa | Tecnología | Decisión |
|------|-----------|----------|
| Mobile | Flutter + Riverpod | DX superior, code gen, testabilidad |
| Backend | FastAPI + PostgreSQL | Async nativo, full-text search, escalabilidad |
| Pagos | RevenueCat | Abstrae iOS/Android billing sin fricción |
| Seguridad | AES-256 (grimorio) | Cifrado local, clave derivada de PIN usuario |
| Oracle | Claude API (claude-sonnet) | Sin fine-tuning — prompt engineering puro |
| Auth | JWT + refresh tokens | Stateless, compatible con mobile offline |

---

## ARQUITECTURA MOBILE (Flutter)

### Estructura de capas
```
lib/
├── core/
│   ├── constants/
│   ├── errors/          # Failure hierarchy
│   ├── network/         # Dio + interceptors
│   └── security/        # AES-256 service
├── features/
│   ├── grimoire/        # Cifrado, CRUD entradas
│   ├── oracle/          # Claude API wrapper
│   ├── astral/          # Calendario astrológico
│   ├── sigils/          # Generador de sigilos
│   └── auth/            # JWT, biometrics
├── shared/
│   ├── widgets/
│   └── providers/       # Riverpod global state
└── main.dart
```

### Riverpod patterns
- `AsyncNotifierProvider` para estado async con loading/error/data
- `family` modifier para providers parametrizados
- `ref.invalidate()` para refrescar después de mutaciones
- Code generation con `@riverpod` annotation — siempre

```dart
@riverpod
class GrimoireNotifier extends _$GrimoireNotifier {
  @override
  Future<List<GrimoireEntry>> build() async {
    return ref.watch(grimoireRepositoryProvider).getAll();
  }

  Future<void> addEntry(GrimoireEntry entry) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(grimoireRepositoryProvider).save(entry),
    ).then((_) => build());
  }
}
```

### AES-256 — grimorio cifrado
- Clave derivada con PBKDF2 (100k iteraciones) desde PIN usuario
- Salt único por entrada, no global
- IV random por operación de cifrado
- Nunca almacenar clave en texto plano ni en SharedPreferences sin encryptor

```dart
// Patrón correcto
final key = await _deriveKey(pin: userPin, salt: entry.salt);
final encrypted = await _aesEncrypt(plaintext: content, key: key, iv: entry.iv);
```

---

## ARQUITECTURA BACKEND (FastAPI)

### Estructura
```
app/
├── api/
│   ├── v1/
│   │   ├── grimoire.py
│   │   ├── oracle.py
│   │   ├── auth.py
│   │   └── astral.py
│   └── deps.py          # Inyección de dependencias
├── core/
│   ├── config.py        # Pydantic Settings
│   ├── security.py      # JWT logic
│   └── database.py      # SQLAlchemy async engine
├── models/              # SQLAlchemy ORM
├── schemas/             # Pydantic I/O
├── services/            # Lógica de negocio
└── main.py
```

### Patrones obligatorios
- `async` en todos los endpoints y servicios I/O-bound
- Pydantic v2 para validación — `model_validator`, `field_validator`
- SQLAlchemy async con `AsyncSession`
- Dependency injection vía `Depends()` — nunca instanciar servicios inline
- Errores tipados con `HTTPException` + detalle estructurado

```python
@router.post("/oracle/consult", response_model=OracleResponse)
async def consult_oracle(
    request: OracleRequest,
    current_user: User = Depends(get_current_user),
    oracle_service: OracleService = Depends(get_oracle_service),
) -> OracleResponse:
    return await oracle_service.consult(user=current_user, query=request)
```

### Oracle — Claude API
- System prompt: personalidad clarividente, responde en el idioma del usuario
- No streaming en v1 — implementar después si UX lo requiere
- Historial de conversación: últimas N sesiones en contexto (configurable)
- Rate limit por usuario via Redis o contador en PostgreSQL

---

## UX/UI — PRINCIPIOS PARA APP ESOTÉRICA

### Filosofía visual
- **Oscuro por defecto** — no modo claro. El trabajo mágico es nocturno.
- **Minimalismo ritual** — cada elemento en pantalla tiene propósito. Sin decoración vacía.
- **Tipografía como símbolo** — serif antiguo para títulos (IM Fell, Cinzel), sans limpio para UI funcional
- **Paleta base**: negro profundo `#0A0A0F`, dorado envejecido `#B8960C`, carmesí `#8B1A1A`, plata `#C0C0C0`
- **Animaciones lentas y deliberadas** — nada de bounces ni transiciones rápidas. Fade, dissolve, veil.

### Pantallas core
| Pantalla | Prioridad | Notas |
|----------|-----------|-------|
| Grimorio | P0 | Lista cifrada + editor con cifrado on-save |
| Oracle | P0 | Chat con Claude. Historial por sesión. |
| Bitácora | P1 | Log de trabajo mágico con fecha/hora/luna |
| Calendario astral | P1 | Fases lunares + aspectos planetarios |
| Generador de sigilos | P2 | Método Austin Osman Spare simplificado |

### Patrones UX obligatorios
- Bottom navigation para las 3-4 secciones principales
- Haptic feedback en acciones importantes (guardar grimorio, confirmar ritual)
- Biometric auth opcional para abrir la app
- Modo lectura en pantalla completa para el grimorio

---

## DECISIONES YA TOMADAS — NO DEBATIR

- ✅ Riverpod sobre Provider/Bloc
- ✅ PostgreSQL sobre SQLite (escalabilidad + búsqueda full-text)
- ✅ RevenueCat para billing
- ✅ Claude API como oracle (sin fine-tuning)
- ✅ AES-256 para grimorio
- ✅ App premium (no freemium con ads)

---

## MODO DE RESPUESTA

- Código primero, explicación solo si es no obvio
- Señalar decisiones que contradigan la arquitectura canónica
- Si hay deuda técnica, nombrarla directamente
- Proponer estructura de carpetas cuando se crea un módulo nuevo
- Mantener consistencia con el stack canónico — no sugerir librerías fuera del stack sin justificación fuerte
