"""Cuanto cuesta una lectura, en creditos, segun cuantas cartas tiene.

POR QUE UNA FORMULA Y NO UNA TABLA. Con una tabla habria que tocar codigo cada
vez que se anada una tirada, y la de cinco cartas o la de doce se quedarian sin
precio hasta que alguien se acordase. La formula ya tiene precio para todas.

EL DIVISOR SALE DE LO MEDIDO, no de una intuicion. Comparadas las dos tiradas
reales contra el modelo el 26-sep-2026:

| | tres cartas | Cruz Celta | ratio |
|---|---|---|---|
| tokens pedidos | 3.806 | 4.824 | 1,27x |
| texto devuelto | ~1.000 | 2.188 | 2,2x |
| coste real con reintento | ~5.700 | ~9.600 | 1,7x |

En dinero no hay debate: una Cruz Celta cuesta unos $0,002. Lo que de verdad
escasea es el TECHO DIARIO de Groq --200.000 tokens para toda la app-- donde
una Cruz Celta con reintento se lleva el 5% del dia entero. El 26-sep el
Oraculo se quedo sin cupo a media tarde con trafico normal.

Con divisor 4 las dos tiradas que existen caen donde tienen que caer: tres
cartas 1 credito, diez cartas 3. Y las que no existen todavia quedan
razonables: cinco 2, doce 3.
"""
from __future__ import annotations

# Cartas que cubre un credito. Cambiarlo cambia el precio de TODAS las tiradas
# a la vez, que es justo lo que se queria al elegir formula.
CARTAS_POR_CREDITO = 4

# Ninguna lectura sale gratis, ni siquiera la de una carta.
COSTE_MINIMO = 1


def coste_en_creditos(card_count: int) -> int:
    """Creditos que cuesta interpretar una tirada de `card_count` cartas.

    Solo cobra la INTERPRETACION. Sacar las cartas no gasta IA y sigue
    costando lo de siempre: es `tarot`, otra accion.

    Un `card_count` de cero o negativo --una consulta sin tirada, solo con el
    cielo-- cuesta el minimo: sigue siendo una llamada al modelo.
    """
    if card_count <= 0:
        return COSTE_MINIMO
    return max(COSTE_MINIMO, -(-card_count // CARTAS_POR_CREDITO))
