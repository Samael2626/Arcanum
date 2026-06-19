"""Tarot — Arcanos Mayores (22) y lógica de tirada.

MVP con los 22 Mayores (mazo de Mayores, válido y profundo). Los 56 Menores
quedan como contenido futuro.
"""
import random

MAJOR_ARCANA: list[dict] = [
    {"number": 0, "slug": "el-loco", "name": "El Loco",
     "upright": "Comienzos, espontaneidad, fe en lo desconocido.",
     "reversed": "Imprudencia, riesgo necio, miedo a dar el salto."},
    {"number": 1, "slug": "el-mago", "name": "El Mago",
     "upright": "Manifestación, voluntad, poder de crear.",
     "reversed": "Manipulación, talento desperdiciado, engaño."},
    {"number": 2, "slug": "la-sacerdotisa", "name": "La Sacerdotisa",
     "upright": "Intuición, misterio, conocimiento oculto.",
     "reversed": "Secretos, desconexión de tu voz interior."},
    {"number": 3, "slug": "la-emperatriz", "name": "La Emperatriz",
     "upright": "Abundancia, fertilidad, nutrición, creatividad.",
     "reversed": "Dependencia, bloqueo creativo, descuido."},
    {"number": 4, "slug": "el-emperador", "name": "El Emperador",
     "upright": "Autoridad, estructura, control, estabilidad.",
     "reversed": "Tiranía, rigidez, autoridad mal usada."},
    {"number": 5, "slug": "el-hierofante", "name": "El Hierofante",
     "upright": "Tradición, enseñanza, guía espiritual.",
     "reversed": "Dogma, rebeldía, romper convenciones."},
    {"number": 6, "slug": "los-enamorados", "name": "Los Enamorados",
     "upright": "Unión, amor, elección desde el corazón.",
     "reversed": "Desarmonía, mala elección, conflicto de valores."},
    {"number": 7, "slug": "el-carro", "name": "El Carro",
     "upright": "Voluntad, victoria, avance con control.",
     "reversed": "Descontrol, rumbo perdido, derrota."},
    {"number": 8, "slug": "la-fuerza", "name": "La Fuerza",
     "upright": "Coraje, dominio interior, compasión.",
     "reversed": "Duda, debilidad, fuerza mal dirigida."},
    {"number": 9, "slug": "el-ermitano", "name": "El Ermitaño",
     "upright": "Introspección, búsqueda, guía interior.",
     "reversed": "Aislamiento, evasión, soledad estéril."},
    {"number": 10, "slug": "la-rueda", "name": "La Rueda de la Fortuna",
     "upright": "Ciclos, destino, cambio de suerte.",
     "reversed": "Mala racha, resistencia al cambio."},
    {"number": 11, "slug": "la-justicia", "name": "La Justicia",
     "upright": "Verdad, equidad, causa y efecto.",
     "reversed": "Injusticia, deshonestidad, evadir la responsabilidad."},
    {"number": 12, "slug": "el-colgado", "name": "El Colgado",
     "upright": "Entrega, nueva perspectiva, pausa fértil.",
     "reversed": "Estancamiento, sacrificio inútil, resistencia."},
    {"number": 13, "slug": "la-muerte", "name": "La Muerte",
     "upright": "Fin, transformación, renacimiento.",
     "reversed": "Aferrarse, miedo al cambio, estancamiento."},
    {"number": 14, "slug": "la-templanza", "name": "La Templanza",
     "upright": "Equilibrio, moderación, alquimia interior.",
     "reversed": "Desequilibrio, exceso, impaciencia."},
    {"number": 15, "slug": "el-diablo", "name": "El Diablo",
     "upright": "Apego, sombra, materialismo, atadura.",
     "reversed": "Liberación, romper cadenas, recuperar el poder."},
    {"number": 16, "slug": "la-torre", "name": "La Torre",
     "upright": "Ruptura súbita, revelación, derrumbe necesario.",
     "reversed": "Evitar el desastre, miedo al colapso."},
    {"number": 17, "slug": "la-estrella", "name": "La Estrella",
     "upright": "Esperanza, inspiración, sanación, fe.",
     "reversed": "Desánimo, fe perdida, desconexión."},
    {"number": 18, "slug": "la-luna", "name": "La Luna",
     "upright": "Inconsciente, intuición, ilusión, miedo.",
     "reversed": "La confusión se disipa, verdad que emerge."},
    {"number": 19, "slug": "el-sol", "name": "El Sol",
     "upright": "Éxito, vitalidad, alegría, claridad.",
     "reversed": "Negatividad pasajera, ego, brillo opacado."},
    {"number": 20, "slug": "el-juicio", "name": "El Juicio",
     "upright": "Despertar, llamado, renovación, perdón.",
     "reversed": "Autocrítica, duda, ignorar el llamado."},
    {"number": 21, "slug": "el-mundo", "name": "El Mundo",
     "upright": "Culminación, plenitud, integración, logro.",
     "reversed": "Cierre pendiente, meta a medio camino."},
]

SPREADS: dict[str, list[str]] = {
    "single": ["El mensaje"],
    "three": ["Pasado", "Presente", "Futuro"],
}


def draw(spread: str) -> list[dict]:
    """Tira las cartas de un spread: sin repeticiones, orientación al azar."""
    positions = SPREADS[spread]
    cards = random.sample(MAJOR_ARCANA, len(positions))
    result = []
    for position, card in zip(positions, cards):
        reversed_ = random.random() < 0.5
        result.append({
            "position": position,
            "number": card["number"],
            "name": card["name"],
            "slug": card["slug"],
            "orientation": "reversed" if reversed_ else "upright",
            "meaning": card["reversed" if reversed_ else "upright"],
        })
    return result
