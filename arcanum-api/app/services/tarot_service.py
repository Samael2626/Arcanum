"""Servicio para el manejo de la baraja de tarot y tiradas."""
import random
from typing import List, Dict, Any

# 22 Arcanos Mayores
TAROT_DECK = [
    {"id": 0, "slug": "el-loco", "name": "El Loco", "meaning_upright": "Nuevos comienzos, espontaneidad, fe en lo desconocido.", "meaning_reversed": "Imprudencia, riesgo necio, miedo a dar el salto."},
    {"id": 1, "slug": "el-mago", "name": "El Mago", "meaning_upright": "Manifestación, poder, voluntad de crear.", "meaning_reversed": "Manipulación, talento desperdiciado, engaño."},
    {"id": 2, "slug": "la-sacerdotisa", "name": "La Sacerdotisa", "meaning_upright": "Intuición, misterio, conocimiento oculto.", "meaning_reversed": "Secretos, desconexión de la voz interior."},
    {"id": 3, "slug": "la-emperatriz", "name": "La Emperatriz", "meaning_upright": "Abundancia, fertilidad, creatividad, cuidado.", "meaning_reversed": "Dependencia, bloqueo creativo, descuido."},
    {"id": 4, "slug": "el-emperador", "name": "El Emperador", "meaning_upright": "Autoridad, estructura, control, estabilidad.", "meaning_reversed": "Tiranía, rigidez, autoridad mal usada."},
    {"id": 5, "slug": "el-hierofante", "name": "El Hierofante", "meaning_upright": "Tradición, enseñanza, guía espiritual.", "meaning_reversed": "Dogma, rebeldía, romper convenciones."},
    {"id": 6, "slug": "los-enamorados", "name": "Los Enamorados", "meaning_upright": "Amor, unión, elección desde el corazón.", "meaning_reversed": "Desarmonía, conflicto de valores, mala elección."},
    {"id": 7, "slug": "el-carro", "name": "El Carro", "meaning_upright": "Voluntad, victoria, avance con control.", "meaning_reversed": "Descontrol, rumbo perdido, derrota."},
    {"id": 8, "slug": "la-fuerza", "name": "La Fuerza", "meaning_upright": "Coraje, dominio interior, compasión.", "meaning_reversed": "Duda, debilidad, fuerza mal dirigida."},
    {"id": 9, "slug": "el-ermitano", "name": "El Ermitaño", "meaning_upright": "Introspección, búsqueda de verdad, guía interior.", "meaning_reversed": "Aislamiento, evasión, soledad estéril."},
    {"id": 10, "slug": "la-rueda", "name": "La Rueda de la Fortuna", "meaning_upright": "Ciclos, destino, cambio de suerte.", "meaning_reversed": "Mala racha, resistencia al cambio."},
    {"id": 11, "slug": "la-justicia", "name": "La Justicia", "meaning_upright": "Verdad, equidad, causa y efecto.", "meaning_reversed": "Injusticia, deshonestidad, evadir la responsabilidad."},
    {"id": 12, "slug": "el-colgado", "name": "El Colgado", "meaning_upright": "Nueva perspectiva, entrega, pausa fértil.", "meaning_reversed": "Estancamiento, sacrificio inútil, resistencia."},
    {"id": 13, "slug": "la-muerte", "name": "La Muerte", "meaning_upright": "Transformación, fin de un ciclo, renacimiento.", "meaning_reversed": "Aferrarse, miedo al cambio, estancamiento."},
    {"id": 14, "slug": "la-templanza", "name": "La Templanza", "meaning_upright": "Equilibrio, moderación, alquimia interior.", "meaning_reversed": "Desequilibrio, exceso, impaciencia."},
    {"id": 15, "slug": "el-diablo", "name": "El Diablo", "meaning_upright": "Apego, sombra, materialismo, atadura.", "meaning_reversed": "Liberación, romper cadenas, recuperar el poder."},
    {"id": 16, "slug": "la-torre", "name": "La Torre", "meaning_upright": "Ruptura súbita, revelación, derrumbe de lo falso.", "meaning_reversed": "Evitar el desastre, miedo al colapso."},
    {"id": 17, "slug": "la-estrella", "name": "La Estrella", "meaning_upright": "Esperanza, inspiración, sanación, fe.", "meaning_reversed": "Desánimo, fe perdida, desconexión."},
    {"id": 18, "slug": "la-luna", "name": "La Luna", "meaning_upright": "Intuición, inconsciente, ilusión, miedo.", "meaning_reversed": "La confusión se disipa, verdad que emerge."},
    {"id": 19, "slug": "el-sol", "name": "El Sol", "meaning_upright": "Éxito, vitalidad, alegría, claridad.", "meaning_reversed": "Negatividad pasajera, ego, brillo opacado."},
    {"id": 20, "slug": "el-juicio", "name": "El Juicio", "meaning_upright": "Despertar, llamado interior, renovación, perdón.", "meaning_reversed": "Autocrítica, duda, ignorar el llamado."},
    {"id": 21, "slug": "el-mundo", "name": "El Mundo", "meaning_upright": "Culminación, plenitud, integración, logro.", "meaning_reversed": "Cierre pendiente, meta a medio camino."},
]

SPREAD_POSITIONS = {
    "three_card": ["Pasado", "Presente", "Futuro"],
    "celtic_cross": [
        "Situación actual", "El desafío", "Fundamento (raíz)", "Pasado reciente",
        "Lo que corona (posible futuro)", "Futuro inmediato", "Tu actitud",
        "Entorno e influencias", "Esperanzas y miedos", "Resultado",
    ],
}


def get_tarot_deck() -> List[Dict[str, Any]]:
    """Devuelve una copia de la baraja de tarot."""
    return TAROT_DECK.copy()


def draw_cards(deck: List[Dict[str, Any]], count: int = 3, spread_type: str = "three_card") -> List[Dict[str, Any]]:
    """
    Extrae cartas sin repetir y marca su orientación.
    Si spread_type tiene posiciones nombradas, estas mandan sobre count.
    Cada carta incluye: id, slug, name, position, drawn_upright,
    meaning_upright, meaning_reversed, meaning (según orientación).
    """
    positions = SPREAD_POSITIONS.get(spread_type)
    if positions is not None:
        count = len(positions)
    if count > len(deck):
        count = len(deck)

    chosen = random.sample(deck, count)
    result = []
    for i, card in enumerate(chosen):
        upright = random.choice([True, False])
        meaning = card["meaning_upright"] if upright else card["meaning_reversed"]
        result.append({
            "id": card["id"],
            "slug": card["slug"],
            "name": card["name"],
            "position": positions[i] if positions is not None else None,
            "drawn_upright": upright,
            "meaning_upright": card["meaning_upright"],
            "meaning_reversed": card["meaning_reversed"],
            "meaning": meaning,
        })
    return result
