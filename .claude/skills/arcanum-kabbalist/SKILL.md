---
name: arcanum-kabbalist
description: >
  Cabalista técnico para ARCANUM. Maneja el Árbol de la Vida, las 10 Sephiroth, los 22 senderos, correspondencias planetarias y elementales, Gematría hebrea y la estructura de los cuatro mundos (Atziluth, Beriah, Yetzirah, Assiah). Activa SIEMPRE que Samuel necesite: calcular Gematría de palabras/frases, mapear correspondencias del Árbol de la Vida, diseñar el módulo cabalístico de ARCANUM, generar contenido sobre sephiroth o senderos, o integrar estructura cabalística en los módulos de sigilos, grimorio u oracle. Trigger ante: "sephiroth", "árbol de la vida", "gematría", "sendero", "kether", "malkuth", "qlipha", "correspondencias cabalísticas", "cuatro mundos", "letra hebrea". No esperar términos exactos — si hay estructura cabalística involucrada, este skill responde.
---

# ARCANUM Kabbalist

> El Árbol como mapa. Cada sephirah una función. Cada sendero una transición. Nada decorativo.

---

## LAS 10 SEPHIROTH

| # | Nombre | Planeta | Mundo | Principio | Color |
|---|--------|---------|-------|-----------|-------|
| 1 | Kether | Primer Motor | Atziluth | Corona, Unidad pura | Blanco brillante |
| 2 | Chokmah | Urano/Zodíaco | Atziluth | Sabiduría, Fuerza pura | Gris |
| 3 | Binah | Saturno | Atziluth | Entendimiento, Forma | Negro |
| 4 | Chesed | Júpiter | Briah | Misericordia, Expansión | Azul |
| 5 | Geburah | Marte | Briah | Severidad, Fuerza activa | Rojo |
| 6 | Tiphareth | Sol | Briah | Belleza, Equilibrio | Amarillo/dorado |
| 7 | Netzach | Venus | Yetzirah | Victoria, Deseo | Verde |
| 8 | Hod | Mercurio | Yetzirah | Esplendor, Intelecto | Naranja |
| 9 | Yesod | Luna | Yetzirah | Fundamento, Astral | Violeta |
| 10 | Malkuth | Tierra/4 elementos | Assiah | Reino, Manifestación | Amarillo/olivo/rojo/negro |

### Los 4 Mundos
- **Atziluth** — Emanación. Arquetipo puro. Sephiroth 1-3.
- **Briah** — Creación. Diseño, intención. Sephiroth 4-6.
- **Yetzirah** — Formación. Proceso, movimiento. Sephiroth 7-9.
- **Assiah** — Acción. Materia, resultado. Sephirah 10.

---

## LOS 22 SENDEROS

Cada sendero conecta dos sephiroth y corresponde a una letra hebrea y un arcano mayor del Tarot.

| Sendero | De → A | Letra | Tarot | Elemento/Planeta |
|---------|--------|-------|-------|-----------------|
| 11 | Kether → Chokmah | Aleph (א) | El Loco | Aire |
| 12 | Kether → Binah | Beth (ב) | El Mago | Mercurio |
| 13 | Kether → Tiphareth | Gimel (ג) | Sacerdotisa | Luna |
| 14 | Chokmah → Binah | Daleth (ד) | La Emperatriz | Venus |
| 15 | Chokmah → Tiphareth | Heh (ה) | El Emperador | Aries |
| 16 | Chokmah → Chesed | Vav (ו) | El Hierofante | Tauro |
| 17 | Binah → Tiphareth | Zayin (ז) | Los Amantes | Géminis |
| 18 | Binah → Geburah | Chet (ח) | El Carro | Cáncer |
| 19 | Chesed → Geburah | Teth (ט) | La Fuerza | Leo |
| 20 | Chesed → Tiphareth | Yod (י) | El Ermitaño | Virgo |
| 21 | Chesed → Netzach | Kaph (כ) | Rueda Fortuna | Júpiter |
| 22 | Geburah → Tiphareth | Lamed (ל) | La Justicia | Libra |
| 23 | Geburah → Hod | Mem (מ) | El Colgado | Agua |
| 24 | Tiphareth → Netzach | Nun (נ) | La Muerte | Escorpio |
| 25 | Tiphareth → Yesod | Samekh (ס) | La Templanza | Sagitario |
| 26 | Tiphareth → Hod | Ayin (ע) | El Diablo | Capricornio |
| 27 | Netzach → Hod | Peh (פ) | La Torre | Marte |
| 28 | Netzach → Yesod | Tzaddi (צ) | La Estrella | Acuario |
| 29 | Netzach → Malkuth | Qoph (ק) | La Luna | Piscis |
| 30 | Hod → Yesod | Resh (ר) | El Sol | Sol |
| 31 | Hod → Malkuth | Shin (ש) | El Juicio | Fuego |
| 32 | Yesod → Malkuth | Tav (ת) | El Mundo | Saturno/Tierra |

---

## GEMATRÍA — CÁLCULOS

### Valores estándar (Mispar Hechrachi)
```python
HEBREW_VALUES = {
    'א': 1,  'ב': 2,  'ג': 3,  'ד': 4,  'ה': 5,
    'ו': 6,  'ז': 7,  'ח': 8,  'ט': 9,  'י': 10,
    'כ': 20, 'ל': 30, 'מ': 40, 'נ': 50, 'ס': 60,
    'ע': 70, 'פ': 80, 'צ': 90, 'ק': 100,'ר': 200,
    'ש': 300,'ת': 400,
    # Finales
    'ך': 500,'ם': 600,'ן': 700,'ף': 800,'ץ': 900,
}

def gematria(word: str) -> int:
    """Calcula valor numérico de palabra hebrea."""
    return sum(HEBREW_VALUES.get(char, 0) for char in word)

def find_equivalences(value: int, word_list: list[str]) -> list[str]:
    """Encuentra palabras con el mismo valor numérico."""
    return [w for w in word_list if gematria(w) == value]
```

### Transliteración latina → gematría
Para usuarios que no escriben hebreo — mapeo aproximado por sonido:
```python
LATIN_TO_HEBREW = {
    'a': 'א', 'b': 'ב', 'g': 'ג', 'd': 'ד', 'h': 'ה',
    'v': 'ו', 'w': 'ו', 'z': 'ז', 'ch': 'ח', 't': 'ט',
    'i': 'י', 'y': 'י', 'k': 'כ', 'l': 'ל', 'm': 'מ',
    'n': 'נ', 's': 'ס', 'o': 'ע', 'p': 'פ', 'tz': 'צ',
    'q': 'ק', 'r': 'ר', 'sh': 'ש', 'th': 'ת',
}
```

---

## MÓDULO ÁRBOL DE LA VIDA — DISEÑO ARCANUM

### Feature: Navegador del Árbol
- Canvas interactivo con los 10 nodos y 22 senderos
- Tap en sephirah → card con: nombre, planeta, principio, correspondencias
- Tap en sendero → carta de Tarot asociada + descripción del proceso
- Modo "Mi posición": usuario indica en qué sephirah siente que trabaja actualmente

### Feature: Gematría en el Grimorio
- Al guardar una entrada, calcular valor numérico de la intención
- Mostrar sephirah cuya numerología coincide
- Ejemplo: intención con valor 6 → Tiphareth (sol, equilibrio, belleza)

### Endpoint FastAPI
```python
# POST /kabbalah/gematria
class GematriaRequest(BaseModel):
    text: str
    method: Literal["standard", "reduced", "ordinal"] = "standard"

class GematriaResponse(BaseModel):
    text: str
    value: int
    reduced: int          # valor reducido a un dígito
    sephirah: str | None  # sephirah asociada si aplica
    path: str | None      # sendero asociado si aplica

@router.post("/kabbalah/gematria", response_model=GematriaResponse)
async def calculate_gematria(request: GematriaRequest) -> GematriaResponse:
    ...
```

### Correspondencias para el oracle
Cuando el oracle responde, puede incluir la sephirah relevante al tema:
- Pregunta de amor/deseo → Netzach (Venus)
- Pregunta de comunicación/intelecto → Hod (Mercurio)
- Pregunta de equilibrio/identidad → Tiphareth (Sol)
- Pregunta de base/estabilidad → Yesod (Luna) o Malkuth

---

## CONTENIDO APP — VOZ CABALÍSTICA

| Contexto | Texto ARCANUM |
|----------|--------------|
| Sephirah Kether | "En el principio, unidad sin nombre." |
| Sephirah Malkuth | "Aquí el árbol toca la tierra. Aquí el trabajo se ve." |
| Sendero 13 (Gimel) | "El sendero de la Luna: descenso hacia el corazón." |
| Gematría igual | "Dos palabras, un valor. El árbol las vincula." |
| Sin equivalencia | "Este número no tiene eco conocido. Nuevo territorio." |

---

## REGLAS TÉCNICAS

1. **Árbol de la Vida ≠ psicología** — no traducir sephiroth a arquetipos jungianos en ARCANUM
2. **Gematría es operativa** — se usa para encontrar conexiones, no para dar significados fijos
3. **Los 4 mundos son niveles de manifestación** — útil para el grimorio: ¿en qué mundo opera esta intención?
4. **Qliphoth** (el reverso del Árbol) — disponible como contenido avanzado, no en onboarding
5. Fuentes de referencia: Sepher Yetzirah, Zohar, Dion Fortune (*El árbol místico de la vida*), Israel Regardie
