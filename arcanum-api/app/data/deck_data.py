"""Dataset estático legacy de Arcanos Mayores para tests y entornos sin BD."""

from typing import Any, Optional

LEGACY_STATIC_DECK: list[dict] = [
    {"slug": "el-loco", "name": "El Loco",
     "meaning_upright": "Nuevos comienzos, espontaneidad, fe en lo desconocido.",
     "meaning_reversed": "Imprudencia, riesgo necio, miedo a dar el salto.",
     "number": 0, "id": 0},
    {"slug": "el-mago", "name": "El Mago",
     "meaning_upright": "Manifestación, poder, voluntad de crear.",
     "meaning_reversed": "Manipulación, talento desperdiciado, engaño.",
     "number": 1, "id": 1},
    {"slug": "la-sacerdotisa", "name": "La Sacerdotisa",
     "meaning_upright": "Intuición, misterio, conocimiento oculto.",
     "meaning_reversed": "Secretos, desconexión de la voz interior.",
     "number": 2, "id": 2},
    {"slug": "la-emperatriz", "name": "La Emperatriz",
     "meaning_upright": "Abundancia, fertilidad, creatividad, cuidado.",
     "meaning_reversed": "Dependencia, bloqueo creativo, descuido.",
     "number": 3, "id": 3},
    {"slug": "el-emperador", "name": "El Emperador",
     "meaning_upright": "Autoridad, estructura, control, estabilidad.",
     "meaning_reversed": "Tiranía, rigidez, autoridad mal usada.",
     "number": 4, "id": 4},
    {"slug": "el-hierofante", "name": "El Hierofante",
     "meaning_upright": "Tradición, enseñanza, guía espiritual.",
     "meaning_reversed": "Dogma, rebeldía, romper convenciones.",
     "number": 5, "id": 5},
    {"slug": "los-enamorados", "name": "Los Enamorados",
     "meaning_upright": "Amor, unión, elección desde el corazón.",
     "meaning_reversed": "Desarmonía, conflicto de valores, mala elección.",
     "number": 6, "id": 6},
    {"slug": "el-carro", "name": "El Carro",
     "meaning_upright": "Voluntad, victoria, avance con control.",
     "meaning_reversed": "Descontrol, rumbo perdido, derrota.",
     "number": 7, "id": 7},
    {"slug": "la-fuerza", "name": "La Fuerza",
     "meaning_upright": "Coraje, dominio interior, compasión.",
     "meaning_reversed": "Duda, debilidad, fuerza mal dirigida.",
     "number": 8, "id": 8},
    {"slug": "el-ermitano", "name": "El Ermitaño",
     "meaning_upright": "Introspección, búsqueda de verdad, guía interior.",
     "meaning_reversed": "Aislamiento, evasión, soledad estéril.",
     "number": 9, "id": 9},
    {"slug": "la-rueda", "name": "La Rueda de la Fortuna",
     "meaning_upright": "Ciclos, destino, cambio de suerte.",
     "meaning_reversed": "Mala racha, resistencia al cambio.",
     "number": 10, "id": 10},
    {"slug": "la-justicia", "name": "La Justicia",
     "meaning_upright": "Verdad, equidad, causa y efecto.",
     "meaning_reversed": "Injusticia, deshonestidad, evadir la responsabilidad.",
     "number": 11, "id": 11},
    {"slug": "el-colgado", "name": "El Colgado",
     "meaning_upright": "Nueva perspectiva, entrega, pausa fértil.",
     "meaning_reversed": "Estancamiento, sacrificio inútil, resistencia.",
     "number": 12, "id": 12},
    {"slug": "la-muerte", "name": "La Muerte",
     "meaning_upright": "Transformación, fin de un ciclo, renacimiento.",
     "meaning_reversed": "Aferrarse, miedo al cambio, estancamiento.",
     "number": 13, "id": 13},
    {"slug": "la-templanza", "name": "La Templanza",
     "meaning_upright": "Equilibrio, moderación, alquimia interior.",
     "meaning_reversed": "Desequilibrio, exceso, impaciencia.",
     "number": 14, "id": 14},
    {"slug": "el-diablo", "name": "El Diablo",
     "meaning_upright": "Apego, sombra, materialismo, atadura.",
     "meaning_reversed": "Liberación, romper cadenas, recuperar el poder.",
     "number": 15, "id": 15},
    {"slug": "la-torre", "name": "La Torre",
     "meaning_upright": "Ruptura súbita, revelación, derrumbe de lo falso.",
     "meaning_reversed": "Evitar el desastre, miedo al colapso.",
     "number": 16, "id": 16},
    {"slug": "la-estrella", "name": "La Estrella",
     "meaning_upright": "Esperanza, inspiración, sanación, fe.",
     "meaning_reversed": "Desánimo, fe perdida, desconexión.",
     "number": 17, "id": 17},
    {"slug": "la-luna", "name": "La Luna",
     "meaning_upright": "Intuición, inconsciente, ilusión, miedo.",
     "meaning_reversed": "La confusión se disipa, verdad que emerge.",
     "number": 18, "id": 18},
    {"slug": "el-sol", "name": "El Sol",
     "meaning_upright": "Éxito, vitalidad, alegría, claridad.",
     "meaning_reversed": "Negatividad pasajera, ego, brillo opacado.",
     "number": 19, "id": 19},
    {"slug": "el-juicio", "name": "El Juicio",
     "meaning_upright": "Despertar, llamado interior, renovación, perdón.",
     "meaning_reversed": "Autocrítica, duda, ignorar el llamado.",
     "number": 20, "id": 20},
    {"slug": "el-mundo", "name": "El Mundo",
     "meaning_upright": "Culminación, plenitud, integración, logro.",
     "meaning_reversed": "Cierre pendiente, meta a medio camino.",
     "number": 21, "id": 21},
]


def attr(card: Any, key: str, default: Any = None) -> Any:
    """Accede a un campo de card ya sea dict o modelo SQLAlchemy."""
    if isinstance(card, dict):
        return card.get(key, default)
    return getattr(card, key, default)


def derive_name_es(card: Any) -> Optional[str]:
    """Nombre en español LIMPIO, sin el descriptor bilingüe."""
    name_es = attr(card, "name_es")
    if name_es:
        return name_es
    title = attr(card, "title_book_t")
    if not title:
        return None
    if " / " in title:
        return title.split(" / ")[-1].strip()
    return title
