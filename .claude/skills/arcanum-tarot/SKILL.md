---
name: arcanum-tarot
description: >
  Experto en Tarot técnico para ARCANUM. Cubre los 78 arcanos (22 mayores + 56 menores), sistemas de tirada (Cruz Celta, 3 cartas, Horse Shoe, Year Spread), dignidades de carta, correspondencias herméticas (Rider-Waite-Smith y Thoth), y lógica de interpretación posicional. Activa SIEMPRE que Samuel necesite: diseñar el módulo de Tarot de ARCANUM, implementar lógica de tiradas en Python/Flutter, escribir interpretaciones de cartas para la app, generar system prompts del oracle con contexto de Tarot, o cuando diga "tarot", "arcano", "tirada", "carta", "Cruz Celta", "lectura", "mazo", "mayor", "menor", "palo", "corte". Activa también ante cualquier pedido de interpretación específica de cartas. No esperar términos exactos — si hay Tarot en el contexto, este skill responde.
---

# ARCANUM Tarot

> El Tarot como mapa de estados, no como oráculo de eventos. Cada carta = un principio activo.

---

## ESTRUCTURA DEL MAZO

### Arcanos Mayores (22 cartas)
| # | Carta | Correspondencia | Principio |
|---|-------|----------------|-----------|
| 0 | El Loco | Aleph — Aire | Potencial puro, salto sin red |
| I | El Mago | Beth — Mercurio | Voluntad dirigida, herramientas |
| II | La Sacerdotisa | Gimel — Luna | Conocimiento oculto, umbral |
| III | La Emperatriz | Daleth — Venus | Creación, abundancia, natura |
| IV | El Emperador | Heh — Aries | Estructura, autoridad, orden |
| V | El Hierofante | Vav — Tauro | Tradición, transmisión, rito |
| VI | Los Amantes | Zayin — Géminis | Elección, unión de opuestos |
| VII | El Carro | Chet — Cáncer | Control de fuerzas, victoria |
| VIII | La Fuerza | Teth — Leo | Dominio interior, suavidad |
| IX | El Ermitaño | Yod — Virgo | Soledad fértil, guía interior |
| X | La Rueda | Kaph — Júpiter | Ciclos, cambio inevitable |
| XI | La Justicia | Lamed — Libra | Equilibrio, consecuencia exacta |
| XII | El Colgado | Mem — Agua | Suspensión, perspectiva invertida |
| XIII | La Muerte | Nun — Escorpio | Transformación radical, fin de forma |
| XIV | La Templanza | Samekh — Sagitario | Síntesis, flujo entre opuestos |
| XV | El Diablo | Ayin — Capricornio | Atadura elegida, sombra materializada |
| XVI | La Torre | Peh — Marte | Ruptura súbita, colapso necesario |
| XVII | La Estrella | Tzaddi — Acuario | Esperanza fundada, renovación |
| XVIII | La Luna | Qoph — Piscis | Ilusión, profundidad inconsciente |
| XIX | El Sol | Resh — Sol | Claridad, vitalidad, éxito visible |
| XX | El Juicio | Shin — Fuego | Llamada, renacimiento, evaluación |
| XXI | El Mundo | Tav — Saturno/Tierra | Completitud, integración total |

### Arcanos Menores — Los 4 Palos
| Palo | Elemento | Dominio | Rey | Reina | Caballero | Paje |
|------|----------|---------|-----|-------|-----------|------|
| Bastos/Varitas | Fuego | Voluntad, creatividad, acción | Marte-Sol | Sol-Venus | Marte puro | Mercurio-Fuego |
| Copas | Agua | Emociones, intuición, relaciones | Venus-Agua | Luna pura | Venus-Luna | Mercurio-Agua |
| Espadas | Aire | Intelecto, conflicto, verdad | Júpiter-Aire | Saturno-Mercurio | Mercurio-Aire | Mercurio-Aire |
| Pentáculos/Oros | Tierra | Materia, recursos, cuerpo | Mercurio-Tierra | Saturno-Tierra | Sol-Tierra | Mercurio-Tierra |

---

## DIGNIDADES DE CARTA

### Posición (Reversión)
- **Derecha**: energía fluye libremente, principio activo
- **Invertida**: energía bloqueada, internalizada, o en proceso de integración — NO simplemente "el significado opuesto"

### Dignidades por cartas vecinas (método hermético)
- **Fuego + Fuego**: potencia mutua
- **Agua + Agua**: potencia mutua
- **Fuego + Agua**: debilitan mutuamente
- **Aire + Tierra**: debilitan mutuamente
- **Fuego + Aire**: Fuego fortalece a Aire
- **Agua + Tierra**: Agua fortalece a Tierra

---

## TIRADAS — LÓGICA POSICIONAL

### Tirada de 3 cartas (mínima funcional)
```python
SPREADS = {
    "three_card_time": {
        "name": "Pasado / Presente / Futuro",
        "positions": [
            {"id": 0, "label": "Pasado", "description": "Lo que condujo aquí"},
            {"id": 1, "label": "Presente", "description": "La situación actual"},
            {"id": 2, "label": "Futuro", "description": "La dirección probable"},
        ]
    },
    "three_card_advice": {
        "name": "Situación / Obstáculo / Consejo",
        "positions": [
            {"id": 0, "label": "Situación", "description": "El estado del asunto"},
            {"id": 1, "label": "Obstáculo", "description": "Lo que dificulta"},
            {"id": 2, "label": "Consejo", "description": "La acción recomendada"},
        ]
    },
}
```

### Cruz Celta (10 cartas)
```python
CELTIC_CROSS = {
    "name": "Cruz Celta",
    "positions": [
        {"id": 0, "label": "El Asunto", "description": "La situación central"},
        {"id": 1, "label": "Lo que cruza", "description": "Obstáculo o apoyo inmediato"},
        {"id": 2, "label": "Base", "description": "Fundamento inconsciente"},
        {"id": 3, "label": "Pasado reciente", "description": "Lo que se va"},
        {"id": 4, "label": "Corona", "description": "El mejor resultado posible"},
        {"id": 5, "label": "Futuro próximo", "description": "Lo que se acerca"},
        {"id": 6, "label": "El consultante", "description": "Tu posición subjetiva"},
        {"id": 7, "label": "Entorno", "description": "Influencias externas"},
        {"id": 8, "label": "Esperanzas/miedos", "description": "Lo que proyectás"},
        {"id": 9, "label": "Resultado", "description": "La dirección final"},
    ]
}
```

### Lógica de barajado (Python)
```python
import random
from dataclasses import dataclass
from enum import Enum

class CardOrientation(Enum):
    UPRIGHT = "upright"
    REVERSED = "reversed"

@dataclass
class DrawnCard:
    card_id: int          # 0-77
    orientation: CardOrientation
    position_id: int
    position_label: str

def draw_spread(spread: dict, reversed_probability: float = 0.25) -> list[DrawnCard]:
    """
    Baraja el mazo y saca cartas para una tirada.
    reversed_probability: probabilidad de carta invertida (0.25 = 25%)
    """
    deck = list(range(78))
    random.shuffle(deck)
    
    drawn = []
    for i, position in enumerate(spread["positions"]):
        orientation = (
            CardOrientation.REVERSED
            if random.random() < reversed_probability
            else CardOrientation.UPRIGHT
        )
        drawn.append(DrawnCard(
            card_id=deck[i],
            orientation=orientation,
            position_id=position["id"],
            position_label=position["label"],
        ))
    return drawn
```

---

## SISTEMA DE INTERPRETACIÓN PARA EL ORACLE

### Context injection al system prompt de Claude
```python
def build_tarot_context(reading: TarotReading) -> str:
    cards_context = []
    for card in reading.cards:
        cards_context.append(
            f"Posición '{card.position_label}': {card.name} "
            f"({'invertida' if card.reversed else 'derecha'}) — "
            f"Principio: {card.core_principle}"
        )
    
    return f"""
El practicante ha realizado una tirada de {reading.spread_name}.
Las cartas son:
{chr(10).join(cards_context)}

Interpreta la tirada como un sistema coherente, no carta por carta.
Busca el patrón entre las cartas. Identifica tensiones y flujos.
Responde al tema de la consulta: "{reading.question}".
"""
```

### Reglas de interpretación para el oracle
1. **Leer el sistema, no las cartas aisladas** — el patrón entre cartas importa más que cada una
2. **La carta central domina** — en Cruz Celta, posición 0 colorea todo
3. **Mayoría de palos** = énfasis temático (muchas copas → asunto emocional)
4. **Muchos mayores** = asunto de gran peso, fuerzas impersonales en juego
5. **Muchos invertidos** = energías bloqueadas o internas, trabajo interior necesario
6. **No predecir con certeza** — mostrar tendencias y dinámicas, no hechos futuros

---

## MÓDULO TAROT — DISEÑO ARCANUM

### Features v1
- Tiradas de 3 cartas (dos layouts)
- Vista de carta única con imagen + keywords
- Historial de lecturas en el grimorio
- Integración con oracle: tirada automática como contexto de consulta

### Features v2
- Cruz Celta completa
- Year Spread (12 cartas, una por mes)
- Diario de cartas del día
- Estadísticas: cartas más frecuentes, palos dominantes

### Schema de base de datos
```python
class TarotReading(BaseModel):
    id: str
    user_id: str
    spread_type: str
    question: str | None
    cards: list[DrawnCard]
    oracle_interpretation: str | None  # respuesta de Claude guardada
    created_at: datetime
    moon_phase: str  # contexto astral al momento de la tirada
```

---

## CONTENIDO APP — VOZ TAROT

| Contexto | Texto ARCANUM |
|----------|--------------|
| Inicio tirada | "¿Qué quieres ver?" |
| Post-barajado | "Las cartas están listas." |
| Carta invertida | "La carta habla desde adentro." |
| Muchos mayores | "Fuerzas más grandes que tú están en movimiento." |
| Sin oracle activo | "La tirada habla sola. Lee el patrón." |
| Guardar lectura | "La lectura queda en el grimorio." |

---

## REGLAS TÉCNICAS

1. **Rider-Waite-Smith como base** — es el sistema más documentado y el que el oracle conoce mejor
2. **Thoth como alternativa** — para usuarios avanzados, cambiar en ajustes de paradigma
3. **Las reversiones son opcionales** — el usuario decide si las activa
4. **No hay cartas "malas"** — La Muerte, La Torre, El Diablo son transformaciones, no catástrofes
5. Fuentes: A.E. Waite (*Pictorial Key to the Tarot*), Aleister Crowley (*Book of Thoth*), Rachel Pollack (*Seventy-Eight Degrees of Wisdom*)
