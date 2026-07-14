---
name: arcanum-astrologer
description: >
  Astrólogo técnico clásico para ARCANUM. Calcula posiciones planetarias reales, aspectos, fases lunares, voids of course, dignidades esenciales y cartas natales usando efemérides suizas (Swiss Ephemeris / ephem / astropy). Activa SIEMPRE que Samuel necesite: calcular posición de planetas para una fecha, determinar aspectos planetarios activos, diseñar el módulo de calendario astral de ARCANUM, escribir lógica Python de efemérides, interpretar una configuración natal, o generar contenido astrológico para la app. Trigger también ante: "luna en qué signo", "aspectos de hoy", "calendario astral", "efemérides", "carta natal", "void of course", "dignidad esencial", "planetas clásicos", "ephemeris". No esperar términos exactos — si hay astrología técnica o diseño del módulo astral, este skill responde.
---

# ARCANUM Astrologer

> Astrología clásica con cálculos reales. Sin vaguedad New Age. Efemérides suizas, planetas helénicos, interpretación técnica.

---

## CORPUS TÉCNICO

### Planetas clásicos (v1 ARCANUM)
Solo los 7 clásicos pre-Urano: Sol, Luna, Mercurio, Venus, Marte, Júpiter, Saturno.
Urano/Neptuno/Plutón: v2 si el usuario los pide explícitamente.

### Aspectos mayores
| Aspecto | Ángulo | Orbe máx | Naturaleza |
|---------|--------|----------|-----------|
| Conjunción | 0° | 8° | Fusión — depende de planetas |
| Sextil | 60° | 4° | Oportunidad |
| Cuadratura | 90° | 6° | Tensión activa |
| Trígono | 120° | 6° | Flujo |
| Oposición | 180° | 8° | Polaridad |

### Dignidades esenciales (Ptolomeo)
| Planeta | Domicilio | Exaltación | Caída | Detrimento |
|---------|-----------|------------|-------|------------|
| Sol | Leo | Aries | Libra | Acuario |
| Luna | Cáncer | Tauro | Escorpio | Capricornio |
| Mercurio | Géminis/Virgo | Virgo | Piscis | Sagitario/Piscis |
| Venus | Tauro/Libra | Piscis | Virgo | Aries/Escorpio |
| Marte | Aries/Escorpio | Capricornio | Cáncer | Tauro/Libra |
| Júpiter | Sagitario/Piscis | Cáncer | Capricornio | Géminis/Virgo |
| Saturno | Capricornio/Acuario | Libra | Aries | Cáncer/Leo |

---

## LIBRERÍA RECOMENDADA: flatlib (Python)

```python
pip install flatlib
```

Flatlib usa Swiss Ephemeris internamente. Ideal para ARCANUM backend.

### Calcular posición lunar actual
```python
from flatlib.datetime import Datetime
from flatlib.geopos import GeoPos
from flatlib import const
from flatlib.chart import Chart

def get_moon_position(date_str: str, time_str: str, lat: float, lon: float) -> dict:
    """
    date_str: 'YYYY/MM/DD'
    time_str: 'HH:MM'
    Retorna signo, grado, fase, void_of_course
    """
    dt = Datetime(date_str, time_str, '+00:00')
    pos = GeoPos(lat, lon)
    chart = Chart(dt, pos, IDs=const.LIST_SEVEN_PLANETS)
    
    moon = chart.getObject(const.MOON)
    return {
        "sign": moon.sign,
        "degree": round(moon.signlon, 2),
        "speed": round(moon.lonspeed, 4),  # neg = retrógrado
        "retrograde": moon.lonspeed < 0,
    }
```

### Calcular aspectos activos entre planetas
```python
from flatlib.aspects import getAspect

def get_active_aspects(chart: Chart) -> list[dict]:
    planets = [chart.getObject(p) for p in const.LIST_SEVEN_PLANETS]
    aspects = []
    
    for i, p1 in enumerate(planets):
        for p2 in planets[i+1:]:
            aspect = getAspect(p1, p2, const.MAJOR_ASPECTS)
            if aspect.type != const.NO_ASPECT:
                aspects.append({
                    "planet1": p1.id,
                    "planet2": p2.id,
                    "aspect": aspect.type,
                    "orb": round(aspect.orb, 2),
                    "applying": aspect.active,
                })
    return aspects
```

### Void of Course lunar
La luna está VOC cuando no forma más aspectos mayores antes de cambiar de signo.

```python
def is_moon_void_of_course(chart: Chart) -> bool:
    """Simplificado: detecta si la luna tiene aspectos aplicativos activos."""
    moon = chart.getObject(const.MOON)
    other_planets = [chart.getObject(p) for p in const.LIST_SEVEN_PLANETS if p != const.MOON]
    
    for planet in other_planets:
        asp = getAspect(moon, planet, const.MAJOR_ASPECTS)
        if asp.type != const.NO_ASPECT and asp.active:  # applying
            return False
    return True
```

### Fase lunar (8 fases)
```python
def get_moon_phase(sun_lon: float, moon_lon: float) -> str:
    diff = (moon_lon - sun_lon) % 360
    phases = [
        (0, 45, "Nueva"),
        (45, 90, "Creciente Cóncava"),
        (90, 135, "Cuarto Creciente"),
        (135, 180, "Creciente Convexa"),
        (180, 225, "Llena"),
        (225, 270, "Menguante Convexa"),
        (270, 315, "Cuarto Menguante"),
        (315, 360, "Menguante Cóncava"),
    ]
    for start, end, name in phases:
        if start <= diff < end:
            return name
    return "Nueva"
```

---

## MÓDULO CALENDARIO ASTRAL — DISEÑO ARCANUM

### Endpoint FastAPI
```python
# GET /astral/today?lat={lat}&lon={lon}
@router.get("/astral/today", response_model=AstralDayResponse)
async def get_astral_day(
    lat: float = Query(default=0.0),
    lon: float = Query(default=0.0),
    astral_service: AstralService = Depends(get_astral_service),
) -> AstralDayResponse:
    return await astral_service.get_day_summary(lat=lat, lon=lon)
```

### Schema de respuesta
```python
class PlanetPosition(BaseModel):
    planet: str
    sign: str
    degree: float
    retrograde: bool
    dignity: str  # domicilio | exaltación | peregrine | caída | detrimento

class AstralDayResponse(BaseModel):
    date: date
    moon_phase: str
    moon_sign: str
    moon_void_of_course: bool
    active_aspects: list[AspectInfo]
    planets: list[PlanetPosition]
    power_day: bool  # lunación, equinoccio, solsticio
    power_day_name: str | None
```

---

## CONTENIDO APP — VOZ ASTROLÓGICA

### Textos para UI (estilo ARCANUM)

| Fase lunar | Texto en app |
|------------|-------------|
| Nueva | "Luna nueva en {signo}. Tiempo de intención." |
| Cuarto Creciente | "La luna crece. Lo iniciado gana impulso." |
| Llena | "Plenitud en {signo}. El trabajo se ve." |
| Cuarto Menguante | "La luna mengua. Tiempo de soltar." |
| VOC | "La luna no aplica. Espera para actuar." |

### Dignidades en la app
- **Domicilio/Exaltación**: "El planeta habla con autoridad."
- **Peregrine**: "El planeta opera sin ventaja ni obstáculo."
- **Caída/Detrimento**: "El planeta trabaja contra su naturaleza."

---

## REGLAS DE INTERPRETACIÓN CLÁSICA

1. **Planetas en dignidad esencial** tienen más fuerza — sus efectos son más puros
2. **Aspectos aplicativos** (que se están formando) pesan más que separativos
3. **Saturno y Marte** son maléficos por naturaleza — no "energía intensa", son maléficos
4. **Júpiter y Venus** son benéficos — no "energía positiva", son benéficos
5. **VOC lunar** = no iniciar, no comprar, no firmar. Tiempo de conclusión, no inicio.
6. La **cuadratura** no es "desafío" — es fricción real entre principios incompatibles

**NO usar lenguaje New Age en ARCANUM**: sin "energía", sin "vibraciones", sin "manifestar". Usar el vocabulario técnico helénico.
