---
name: arcanum-chaos
description: >
  Experto en Chaos Magic para ARCANUM. Cubre el método de sigilos de Austin Osman Spare, paradigmas mágicos, estados de gnosis, el modelo del olvido, y la filosofía del Caos como meta-sistema. Activa SIEMPRE que Samuel necesite: implementar el generador de sigilos de ARCANUM, diseñar el flujo de sigilización (intención → reducción → composición → carga → olvido), crear contenido sobre chaos magic para la app, diseñar el módulo de paradigmas, o cuando diga "sigilo", "gnosis", "paradigma", "Austin Spare", "chaos magic", "olvido", "carga del sigilo", "ZOS KIA", "servitor", "modelo del caos". Activa también ante implementaciones concretas del generador de sigilos en Flutter o Python. No esperar términos exactos — si hay sigilos o chaos magic involucrados, este skill responde.
---

# ARCANUM Chaos

> El caos no es desorden. Es el sistema que contiene todos los sistemas. Opera en paradoja.

---

## FUNDAMENTOS TÉCNICOS DEL CAOS

### El meta-modelo
Chaos magic no tiene dogma. Tiene un método:
1. **Adopt a paradigm** — cualquier sistema es válido si funciona
2. **Believe totally while working** — suspensión del escepticismo durante la operación
3. **Discard it after** — el olvido es parte del mecanismo, no descuido
4. **Result > tradition** — lo que funciona es verdad provisional

### Los 8 rayos del Caos (Peter Carroll)
Cada rayo = un tipo de magia, un color, un modo:
| Rayo | Color | Dominio |
|------|-------|---------|
| Magia de guerra | Rojo | Voluntad, destrucción, defensa |
| Magia de amor | Verde | Deseo, atracción, relación |
| Magia de riqueza | Amarillo/dorado | Prosperidad, intercambio |
| Magia de ego | Naranja | Identidad, presencia, poder personal |
| Magia de pensamiento | Azul | Comunicación, información, conocimiento |
| Magia de muerte | Violeta/negro | Transformación, fin, umbral |
| Magia sexual | Plateado | Gnosis, creación, Eros |
| Magia del caos | Puro negro | Azahar, azar puro, anti-sistema |

---

## SIGILOS — MÉTODO AUSTIN OSMAN SPARE

### El flujo completo
```
1. INTENCIÓN      → Frase en presente positivo afirmativo
2. REDUCCIÓN      → Eliminar vocales + letras repetidas
3. COMPOSICIÓN    → Combinar letras restantes en forma visual
4. CARGA          → Estado de gnosis durante la contemplación
5. OLVIDO         → Destruir/guardar y olvidar conscientemente
6. MANIFESTACIÓN  → Ocurre cuando el ego deja de interferir
```

### Paso 1 — Intención correcta
❌ "Quiero dinero" → ego consciente, resistencia
❌ "No quiero estar enfermo" → negación activa el problema
✅ "Tengo abundancia suficiente" → presente, positivo, específico
✅ "Mi cuerpo funciona con vitalidad" → afirmativo, sensorial

### Paso 2 — Reducción algorítmica
```python
import re

def reduce_statement(intention: str) -> str:
    """
    Elimina vocales y letras repetidas, mantiene orden de aparición.
    'MY WILL IS STRONG' → 'MYWLSTR'
    """
    # Normalizar: mayúsculas, solo letras
    cleaned = re.sub(r'[^A-Z]', '', intention.upper())
    
    # Eliminar vocales
    no_vowels = re.sub(r'[AEIOU]', '', cleaned)
    
    # Eliminar letras repetidas (mantener primera aparición)
    seen = set()
    result = []
    for char in no_vowels:
        if char not in seen:
            seen.add(char)
            result.append(char)
    
    return ''.join(result)

# Ejemplo:
# "I HAVE CREATIVE POWER" → "HVCRTPW"
```

### Paso 3 — Composición visual (Flutter canvas)
El usuario combina las letras resultantes en una forma abstracta:
- Canvas táctil con las letras como elementos arrastrables
- Herramientas: rotar, escalar, superponer, invertir letras
- El objetivo es que el resultado NO parezca letras — forma abstracta
- Guardar como SVG path en el grimorio

```dart
// Estructura del sigilo en base de datos
class Sigil {
  final String id;
  final String intention;        // cifrada AES-256
  final String reducedLetters;   // 'HVCRTPW'
  final String svgPath;          // la forma visual
  final SigilState state;        // draft | charged | forgotten
  final DateTime createdAt;
  final DateTime? chargedAt;
}

enum SigilState { draft, charged, forgotten }
```

### Paso 4 — Gnosis y carga
El estado de gnosis = suspensión del monólogo interno.
Métodos para implementar en ARCANUM:

| Método | Descripción | Implementación UI |
|--------|-------------|------------------|
| Contemplación | Fijar la vista en el sigilo hasta disociarse | Timer + pantalla solo sigilo + fade gradual |
| Respiración | Hiperventilación suave → estado alterado | Guía de respiración animada antes del sigilo |
| Risa | Gnosis por humor absurdo — menos común | Instrucción de texto, sin UI especial |
| Dolor menor | ❌ No implementar en ARCANUM | — |

**Modo carga en ARCANUM:**
```
1. Pantalla full-screen con el sigilo del usuario
2. Guía de respiración opcional (4-7-8 o box breathing)
3. Timer configurable (3-10 min)
4. Al terminar: vibración háptica + opción "Sigilo cargado"
5. Transición suave a la pantalla de olvido
```

### Paso 5 — Olvido
El olvido es el mecanismo activo, no pasivo.
Después de cargar, el usuario elige:
- **Destruir**: quemar virtual (animación de fuego → el sigilo desaparece de la UI)
- **Guardar oculto**: sigilo va al grimorio pero bloqueado — no aparece en la lista principal hasta X días

```dart
// Pantalla de olvido
enum ForgetMethod { destroy, hide }

// Si destroy: eliminación con animación + registro mínimo en bitácora (sin intención)
// Si hide: ocultar por días configurables (default: 28 días = un ciclo lunar)
```

---

## MÓDULO PARADIGMAS — DISEÑO ARCANUM

### Concepto
El practicante puede "equipar" un paradigma activo que colorea la experiencia:
- **Paradigma hermético**: lenguaje de correspondencias, planetas, elementos
- **Paradigma caótico**: lenguaje de probabilidades, memes, resultados
- **Paradigma gnóstico**: lenguaje de Pleroma, Demiurgo, chispas divinas
- **Paradigma personal**: el usuario define el suyo

El paradigma activo afecta:
- El tono del oracle
- Las metáforas usadas en el grimorio
- Los colores y símbolos del calendario astral

```python
# En el system prompt del oracle
PARADIGM_CONTEXT = {
    "hermetic": "Hablas en términos de planetas, elementos y correspondencias.",
    "chaos": "Hablas en términos de probabilidades, resultados y paradigmas provisionales.",
    "gnostic": "Hablas en términos de luz, oscuridad, Pleroma y despertar.",
    "custom": "{user_paradigm_description}",
}
```

---

## SERVITORS (v2)

Un servitor es una entidad construida conscientemente para una función específica.
Estructura básica:
- **Nombre**: generado o elegido por el usuario
- **Función**: una sola, específica
- **Apariencia**: descripción o imagen generada
- **Alimentación**: qué refuerza al servitor (atención, resultados)
- **Condición de disolución**: cuándo termina

En ARCANUM v2: módulo de creación y seguimiento de servitors, vinculado al grimorio.

---

## CONTENIDO APP — VOZ CHAOS

| Contexto | Texto ARCANUM |
|----------|--------------|
| Inicio sigilización | "La intención entra. Las letras que sobran son la forma." |
| Post-composición | "La forma está hecha. Ahora viene el olvido activo." |
| Modo carga activo | "Aquí. Solo esto. El resto no existe." |
| Post-olvido | "Hecho. Suéltalo. El trabajo ocurre sin tí." |
| Paradigma activo | "Operas desde {paradigma}. Cambia cuando necesites." |

---

## REGLAS TÉCNICAS

1. **El olvido no es opcional** — es el mecanismo central. La UI debe facilitarlo activamente
2. **El sigilo no debe "significar" conscientemente** — si el usuario puede leer su intención en el sigilo, no funcionó la composición
3. **No mezclar paradigmas sin intención** — elegir uno y operar desde ahí
4. **Resultados > fe** — en chaos magic, si no funciona, se cambia el método, no se aumenta la creencia
5. Fuentes: Peter Carroll (*Liber Null & Psychonaut*), Austin Osman Spare (*The Book of Pleasure*), Phil Hine (*Condensed Chaos*)
