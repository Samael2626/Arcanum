"""Siembra el módulo Tarot: 22 Arcanos Mayores + 56 Arcanos Menores (Book T / GD).

El dataset de los Menores es VERBATIM del bloque MINOR_ARCANA documentado en
D:\\Brain\\40-Esoterismo\\Tarot\\56-Arcanos-Menores.md (curado contra Cunliffe
y Greer 2008). NO se regenera ni reinterpreta — solo se proyecta a la fila de
SQLAlchemy.

Uso: cd arcanum-api && venv\\Scripts\\python.exe scripts/seed_tarot.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db.session import SessionLocal  # noqa: E402
from app.models.tarot import TarotCard  # noqa: E402


# ── Arcanos Mayores ──────────────────────────────────────────────────────────
# Mínimo viable para que /tarot/cards devuelva 78 cartas (22 mayores + 56 menores).
# Los significados provienen del Tarot Rider–Waite clásico (referencia general).
# Para contenido premium sobre los Mayores, consultar el vault de Obsidian
# (40-Esoterismo/Tarot) en una fase posterior.
MAJOR_ARCANA: list[dict] = [
    {"slug": "el-loco", "arcana": "major", "number": 0, "element": None,
     "sephirah": "Kether", "title_book_t": "The Fool / El Loco"},
    {"slug": "el-mago", "arcana": "major", "number": 1, "element": "aire",
     "sephirah": "Kether", "title_book_t": "The Magus / El Mago"},
    {"slug": "la-sacerdotisa", "arcana": "major", "number": 2, "element": "agua",
     "sephirah": "Chokmah", "title_book_t": "The Priestess / La Sacerdotisa"},
    {"slug": "la-emperatriz", "arcana": "major", "number": 3, "element": "tierra",
     "sephirah": "Binah", "title_book_t": "The Empress / La Emperatriz"},
    {"slug": "el-emperador", "arcana": "major", "number": 4, "element": "fuego",
     "sephirah": "Chesed", "title_book_t": "The Emperor / El Emperador"},
    {"slug": "el-hierofante", "arcana": "major", "number": 5, "element": "tierra",
     "sephirah": "Chesed", "title_book_t": "The Hierophant / El Hierofante"},
    {"slug": "los-enamorados", "arcana": "major", "number": 6, "element": "aire",
     "sephirah": "Tiphareth", "title_book_t": "The Lovers / Los Enamorados"},
    {"slug": "el-carro", "arcana": "major", "number": 7, "element": "agua",
     "sephirah": "Binah", "title_book_t": "The Chariot / El Carro"},
    {"slug": "la-fuerza", "arcana": "major", "number": 8, "element": "fuego",
     "sephirah": "Geburah", "title_book_t": "Strength / La Fuerza"},
    {"slug": "el-ermitano", "arcana": "major", "number": 9, "element": "tierra",
     "sephirah": "Chokmah", "title_book_t": "The Hermit / El Ermitaño"},
    {"slug": "la-rueda", "arcana": "major", "number": 10, "element": "fuego",
     "sephirah": "Malkuth", "title_book_t": "Wheel of Fortune / La Rueda de la Fortuna"},
    {"slug": "la-justicia", "arcana": "major", "number": 11, "element": "aire",
     "sephirah": "Tiphareth", "title_book_t": "Justice / La Justicia"},
    {"slug": "el-colgado", "arcana": "major", "number": 12, "element": "agua",
     "sephirah": "Hod", "title_book_t": "The Hanged Man / El Colgado"},
    {"slug": "la-muerte", "arcana": "major", "number": 13, "element": "agua",
     "sephirah": "Netzach", "title_book_t": "Death / La Muerte"},
    {"slug": "la-templanza", "arcana": "major", "number": 14, "element": "fuego",
     "sephirah": "Yesod", "title_book_t": "Temperance / La Templanza"},
    {"slug": "el-diablo", "arcana": "major", "number": 15, "element": "tierra",
     "sephirah": "Chesed", "title_book_t": "The Devil / El Diablo"},
    {"slug": "la-torre", "arcana": "major", "number": 16, "element": "fuego",
     "sephirah": "Hod", "title_book_t": "The Tower / La Torre"},
    {"slug": "la-estrella", "arcana": "major", "number": 17, "element": "aire",
     "sephirah": "Binah", "title_book_t": "The Star / La Estrella"},
    {"slug": "la-luna", "arcana": "major", "number": 18, "element": "agua",
     "sephirah": "Malkuth", "title_book_t": "The Moon / La Luna"},
    {"slug": "el-sol", "arcana": "major", "number": 19, "element": "fuego",
     "sephirah": "Tiphareth", "title_book_t": "The Sun / El Sol"},
    {"slug": "el-juicio", "arcana": "major", "number": 20, "element": "fuego",
     "sephirah": "Chokmah", "title_book_t": "Judgement / El Juicio"},
    {"slug": "el-mundo", "arcana": "major", "number": 21, "element": "tierra",
     "sephirah": "Malkuth", "title_book_t": "The World / El Mundo"},
]

# Significados sintéticos por defecto (la app puede añadirlos desde el vault).
_MEANING_FALLBACK_UP = "Mira al consultante desde la integridad de su arquetipo. Cuando esta carta aparece, el cosmos pone su principio en juego: invita a abrirse, no a defenderse."
_MEANING_FALLBACK_REV = "La energía del arquetipo se invierte: bloquea, distorsiona o pide revisión. La invitación es interna — reconocer el modo en que se ha resistido el principio."


def _enrich_majors() -> list[dict]:
    """Añade meanings y suit a los mayores."""
    out: list[dict] = []
    for c in MAJOR_ARCANA:
        row = dict(c)
        row["suit"] = None
        row["zodiac"] = None
        row["decan"] = None
        row["title_book_t"] = c.get("title_book_t") or c["slug"].replace("-", " ").title()
        row["meaning_upright"] = _MEANING_FALLBACK_UP
        row["meaning_reversed"] = _MEANING_FALLBACK_REV
        out.append(row)
    return out


# ── Arcanos Menores (VERBATIM desde el .md) ──────────────────────────────────
# Curado contra Cunliffe y Greer 2008. NO regenerar — solo proyectar.
MINOR_ARCANA: list[dict] = [
    # ── BASTOS — Fuego ──────────────────────────────────────────────────────
    {"slug": "as-de-bastos", "suit": "bastos", "number": 1, "element": "fuego",
     "sephirah": "Kether", "zodiac": None, "decan": None,
     "title_book_t": "Root of the Powers of Fire / Raíz de los Poderes del Fuego",
     "meaning_upright": "La voluntad en su estado primordial, anterior a todo objeto. Kether del Fuego: no es aún empresa ni plan, es el impulso que precede al pensamiento mismo. Una chispa capaz de incendiar el mundo si encuentra combustible. Actúa ahora, sin deliberación.",
     "meaning_reversed": "Energía represada que no encuentra salida: el fuego que se vuelve hacia adentro y quema al portador. Falso arranque, proyecto abortado en el umbral, frustración crónica por voluntad no ejercida."},
    {"slug": "dos-de-bastos", "suit": "bastos", "number": 2, "element": "fuego",
     "sephirah": "Chokmah", "zodiac": "Aries 0°–10°", "decan": "Marte en Aries",
     "title_book_t": "Lord of Dominion / Señor del Dominio",
     "meaning_upright": "Marte en Aries, primer decanato: el guerrero en su signo propio. El territorio ya está conquistado — quien sostiene el globo terrestre en la mano ha tomado el mundo. Ahora mira el horizonte desde la altura. Planificación de la expansión, dominio consolidado que busca nuevo alcance.",
     "meaning_reversed": "Dominio que se sostiene por inercia, no por visión. Ambición que se devora a sí misma, poder sin dirección. El conquistador que no sabe qué hacer con su conquista; soberbia que aísla."},
    {"slug": "tres-de-bastos", "suit": "bastos", "number": 3, "element": "fuego",
     "sephirah": "Binah", "zodiac": "Aries 10°–20°", "decan": "Sol en Aries",
     "title_book_t": "Lord of Established Strength / Señor de la Fuerza Establecida",
     "meaning_upright": "Sol en Aries, segundo decanato: la empresa lanzada ha tomado forma y aguarda su retorno. El fuego solar da estructura duradera a la iniciativa marcial. Comercio exterior, expansión en curso, esperar con confianza el fruto de lo sembrado. La fuerza no necesita demostrar nada — ya existe.",
     "meaning_reversed": "Proyectos a medias, retrasos en lo que debería estar materializado. La estructura existe pero algo falta por completar; también: soberbia de quien cree que lo establecido es permanente sin mantenimiento."},
    {"slug": "cuatro-de-bastos", "suit": "bastos", "number": 4, "element": "fuego",
     "sephirah": "Chesed", "zodiac": "Aries 20°–30°", "decan": "Venus en Aries",
     "title_book_t": "Lord of Perfected Work / Señor del Trabajo Perfeccionado",
     "meaning_upright": "Venus en Aries, tercer decanato: el amor y la belleza cierran el ciclo del fuego cardinal. Chesed (misericordia) recibe la obra consumada. Cosecha, celebración, hogar o comunidad que festeja el logro. El ciclo se cierra con alegría genuina — no hay nada más que hacer aquí excepto agradecer.",
     "meaning_reversed": "Celebración prematura sobre cimientos todavía frágiles. La fiesta tapa la conversación difícil que falta. Estabilidad aparente que no ha sido probada por el tiempo."},
    {"slug": "cinco-de-bastos", "suit": "bastos", "number": 5, "element": "fuego",
     "sephirah": "Geburah", "zodiac": "Leo 0°–10°", "decan": "Saturno en Leo",
     "title_book_t": "Lord of Strife / Señor de la Discordia",
     "meaning_upright": "Saturno en Leo, primer decanato: la restricción saturnina aplaca el ego solar. Geburah introduce el conflicto como principio de discriminación. Múltiples voluntades que no ceden, competencia dispersa, energía que necesita ordenarse antes de poder avanzar. El caos es la condición previa al orden real.",
     "meaning_reversed": "Conflicto suprimido que esperará peor momento para estallar. También: resolución genuina, las voluntades en pugna finalmente se articulan. Agotamiento del combate que abre paso a la negociación."},
    {"slug": "seis-de-bastos", "suit": "bastos", "number": 6, "element": "fuego",
     "sephirah": "Tiphareth", "zodiac": "Leo 10°–20°", "decan": "Júpiter en Leo",
     "title_book_t": "Lord of Victory / Señor de la Victoria",
     "meaning_upright": "Júpiter en Leo, segundo decanato: la expansión joviana amplifica la gloria solar. Tiphareth, centro del Árbol, recibe el triunfo en su plenitud. El éxito llega con reconocimiento público, el liderazgo se afirma naturalmente. La victoria no es solo personal: inspira a quienes presencian.",
     "meaning_reversed": "Orgullo inflado que convierte el triunfo en trampa. La victoria pírrica donde el coste supera al beneficio. El reconocimiento llega tarde o viene de los motivos equivocados; caída del pedestal."},
    {"slug": "siete-de-bastos", "suit": "bastos", "number": 7, "element": "fuego",
     "sephirah": "Netzach", "zodiac": "Leo 20°–30°", "decan": "Marte en Leo",
     "title_book_t": "Lord of Valour / Señor del Valor",
     "meaning_upright": "Marte en Leo, tercer decanato: el guerrero defiende la posición desde la altura con coraje leonino. Netzach (victoria instintiva) bajo la energía marcial. Se tiene ventaja del terreno pero la presión es real; resistir exige voluntad sostenida. El valor aquí no es ausencia de miedo sino acción a pesar de él.",
     "meaning_reversed": "Ceder terreno por agotamiento o por duda interna, no por derrota real. La posición se pierde desde adentro. También: rigidez defensiva que impide aprovechar el cambio, defensa convertida en paranoia."},
    {"slug": "ocho-de-bastos", "suit": "bastos", "number": 8, "element": "fuego",
     "sephirah": "Hod", "zodiac": "Sagitario 0°–10°", "decan": "Mercurio en Sagitario",
     "title_book_t": "Lord of Swiftness / Señor de la Rapidez",
     "meaning_upright": "Mercurio en Sagitario, primer decanato: el mensajero del zodíaco vuela en el signo de las grandes distancias. Hod (esplendor mercurial) en el fuego mutable. Todo avanza al mismo tiempo: noticias, viajes, comunicaciones, proyectos que se aceleran sin aviso. La ventana está abierta — actúa antes de que se cierre.",
     "meaning_reversed": "La velocidad sin dirección genera caos. Noticias malas o que llegan tarde, comunicaciones cruzadas, precipitación que dispersa en vez de concentrar. Demasiadas cosas en movimiento simultáneo sin coordinación."},
    {"slug": "nueve-de-bastos", "suit": "bastos", "number": 9, "element": "fuego",
     "sephirah": "Yesod", "zodiac": "Sagitario 10°–20°", "decan": "Luna en Sagitario",
     "title_book_t": "Lord of Great Strength / Señor de la Gran Fuerza",
     "meaning_upright": "Luna en Sagitario, segundo decanato: la memoria lunar imprime en el cuerpo las heridas pasadas. Yesod (fundamento astral) sostiene la resistencia instintiva. Quien ha sido golpeado y permanece de pie ha acumulado una fuerza que no se ve pero se siente. Proteger lo ganado con vigilancia sin abandonar la visión sagitariana.",
     "meaning_reversed": "La guardia se convierte en prisión: paranoia, rigidez defensiva que no deja avanzar. Seguir protegiéndose de un peligro que ya pasó. El herido que no puede dejar de serlo, obstinación que agota."},
    {"slug": "diez-de-bastos", "suit": "bastos", "number": 10, "element": "fuego",
     "sephirah": "Malkuth", "zodiac": "Sagitario 20°–30°", "decan": "Saturno en Sagitario",
     "title_book_t": "Lord of Oppression / Señor de la Opresión",
     "meaning_upright": "Saturno en Sagitario, tercer decanato: el planeta más pesado aplasta el signo más libre. Malkuth recibe el fuego sagitariano en su forma más gravosa. El fuego de la visión se ha convertido en una carga de responsabilidades que nadie más carga. La opresión viene de no poder soltar, de cargar solo lo que debería ser colectivo.",
     "meaning_reversed": "El momento de soltar: delegar, redistribuir, dejar caer lo que aplasta. También, en su faceta negativa: abandonar la responsabilidad de manera irresponsable, tirar la carga sobre otros sin consciencia."},
    {"slug": "sota-de-bastos", "suit": "bastos", "number": 11, "element": "fuego",
     "sephirah": None, "zodiac": "Tierra de Fuego — Reina del Cuadrante Septentrional-Occidental",
     "decan": None,
     "title_book_t": "Princess of the Shining Flame / Princesa de la Llama Brillante",
     "meaning_upright": "Tierra de Fuego: el entusiasmo encarnado en lo concreto. Mensajera de noticias apasionantes, energía desbordante que necesita canalización práctica. Cuando aparece, algo está por comenzar y el primer paso requiere audacia sin garantías.",
     "meaning_reversed": "Entusiasmo vacío que consume sin producir. Proyectos que nunca arrancan, noticias falsas o exageradas. Caprichosa, superficial, el fuego que deslumbra un momento y se apaga."},
    {"slug": "caballero-de-bastos", "suit": "bastos", "number": 12, "element": "fuego",
     "sephirah": None, "zodiac": "Sagitario 20°–Capricornio 20° (Fuego de Fuego — Caballero GD)",
     "decan": None,
     "title_book_t": "Knight of Wands / Caballero de Bastos — Fuego de Fuego",
     "meaning_upright": "Fuego de Fuego puro: la acción más impulsiva del mazo. Movimiento sin freno, aventura, carisma irresistible. Cuando este caballero llega, algo cambia rápido. Su virtud es la velocidad y el coraje; su riesgo es quemar lo que no debía.",
     "meaning_reversed": "Imprudencia que destruye lo que empezó. El aventurero que abandona a mitad del camino o quema puentes innecesariamente. Energía sin cauce que se convierte en violencia o caos."},
    {"slug": "reina-de-bastos", "suit": "bastos", "number": 13, "element": "fuego",
     "sephirah": None, "zodiac": "Piscis 20°–Aries 20° (Agua de Fuego — Reina GD)", "decan": None,
     "title_book_t": "Queen of the Thrones of Flame / Reina de los Tronos de Llama",
     "meaning_upright": "Agua de Fuego: el fuego que alimenta en vez de consumir. Magnética, apasionada y práctica en igual medida. Lidera con presencia y calidez genuina, no con imposición. Creativa, fértil, capaz de hacer crecer lo que toca sin perder su propio centro.",
     "meaning_reversed": "El calor se convierte en quemadura: dominante, celosa, volátil. La confianza en sí misma se colapsa en arrogancia. El fuego deja de nutrir y empieza a consumir a quienes están cerca."},
    {"slug": "rey-de-bastos", "suit": "bastos", "number": 14, "element": "fuego",
     "sephirah": None, "zodiac": "Cáncer 20°–Leo 20° (Aire de Fuego — Príncipe GD)", "decan": None,
     "title_book_t": "Prince of the Chariot of Fire / Príncipe del Carro del Fuego",
     "meaning_upright": "Aire de Fuego: el visionario que convierte ideas en empresas con autoridad natural. Carismático, decidido, tiene la visión y la capacidad de arrastrar a otros hacia ella. Emprendedor nato que no espera permiso para actuar.",
     "meaning_reversed": "El carisma al servicio del ego: autocrático, egocéntrico, incapaz de escuchar. La visión sin empatía que quema al entorno. El líder que trata a las personas como combustible."},

    # ── COPAS — Agua — He — Briah ──────────────────────────────────────────
    {"slug": "as-de-copas", "suit": "copas", "number": 1, "element": "agua",
     "sephirah": "Kether", "zodiac": None, "decan": None,
     "title_book_t": "Root of the Powers of Water / Raíz de los Poderes del Agua",
     "meaning_upright": "El amor en su estado primordial, antes de tener objeto. Kether del Agua: la copa desbordante no tiene destinatario todavía, pero la gracia ya fluye. Apertura emocional radical, intuición que se activa, posibilidad de conexión que aún no se ha manifestado.",
     "meaning_reversed": "El corazón cerrado a cal y canto, o desbordado sin forma. Amor bloqueado o derramado en vacío. La gracia reprimida por miedo o por pérdida que no se ha procesado."},
    {"slug": "dos-de-copas", "suit": "copas", "number": 2, "element": "agua",
     "sephirah": "Chokmah", "zodiac": "Cáncer 0°–10°", "decan": "Venus en Cáncer",
     "title_book_t": "Lord of Love / Señor del Amor",
     "meaning_upright": "Venus en Cáncer, primer decanato: el amor que se siente como hogar. Chokmah (sabiduría como impulso primario) expresado en el elemento más receptivo. Vínculo genuino, reciprocidad emocional, dos personas que se reconocen. No es deseo: es acuerdo del alma.",
     "meaning_reversed": "Desequilibrio en la relación: uno da más de lo que recibe, o la reciprocidad se ha roto. El amor que se convierte en dependencia unilateral, o la separación después del reconocimiento."},
    {"slug": "tres-de-copas", "suit": "copas", "number": 3, "element": "agua",
     "sephirah": "Binah", "zodiac": "Cáncer 10°–20°", "decan": "Mercurio en Cáncer",
     "title_book_t": "Lord of Abundance / Señor de la Abundancia",
     "meaning_upright": "Mercurio en Cáncer, segundo decanato: las emociones encuentran voz y se celebran en comunidad. Binah (entendimiento, la Gran Madre) recibe la comunicación del corazón. Amistad profunda, fiesta genuina, abundancia que se comparte. La tribu que se alegra junta forja lazos que duran.",
     "meaning_reversed": "La celebración como máscara del vacío. Exceso hedonista, frivolidad que erosiona el vínculo real. Amistades superficiales que desaparecen cuando la fiesta termina."},
    {"slug": "cuatro-de-copas", "suit": "copas", "number": 4, "element": "agua",
     "sephirah": "Chesed", "zodiac": "Cáncer 20°–30°", "decan": "Luna en Cáncer",
     "title_book_t": "Lord of Blended Pleasure / Señor del Placer Mezclado",
     "meaning_upright": "Luna en Cáncer, tercer decanato: la luna en su domicilio propio lleva la abundancia emocional al límite de la saciedad. Chesed (misericordia estable) en el agua que ya no puede recibir más. Contemplación, retiro interior necesario. Una nueva copa se ofrece desde el exterior — ¿hay espacio para verla?",
     "meaning_reversed": "Apatía profunda, oportunidades perdidas por ensimismamiento. El estancamiento emocional que se cronifica. O bien: romper el letargo y abrir los ojos a lo que se ofrece."},
    {"slug": "cinco-de-copas", "suit": "copas", "number": 5, "element": "agua",
     "sephirah": "Geburah", "zodiac": "Escorpio 0°–10°", "decan": "Marte en Escorpio",
     "title_book_t": "Lord of Loss in Pleasure / Señor de la Pérdida en el Placer",
     "meaning_upright": "Marte en Escorpio, primer decanato: el deseo viola lo que ama cuando no tiene forma. Geburah (severidad) en el agua más intensa. Pérdida, duelo, lo derramado no se recupera. Pero hay dos copas en pie — lo que queda tiene valor si se puede ver más allá de lo perdido.",
     "meaning_reversed": "Negación del duelo que impide sanarlo. Aferrarse a las copas derramadas en vez de recoger las que quedan. O bien: el duelo empieza a sanar, la mirada gira hacia las copas que permanecen."},
    {"slug": "seis-de-copas", "suit": "copas", "number": 6, "element": "agua",
     "sephirah": "Tiphareth", "zodiac": "Escorpio 10°–20°", "decan": "Sol en Escorpio",
     "title_book_t": "Lord of Pleasure / Señor del Placer",
     "meaning_upright": "Sol en Escorpio, segundo decanato: la luz penetra lo oscuro y revela dulzura donde había profundidad. Tiphareth (belleza, corazón solar) en el agua que transforma. Nostalgia benigna, inocencia que regresa, generosidad que fluye del pasado hacia el presente. Lo que fue ya no duele: nutre.",
     "meaning_reversed": "Vivir anclado en el pasado, idealización que impide el movimiento. La nostalgia como prisión. O bien: un pasado no resuelto que regresa exigiendo atención."},
    {"slug": "siete-de-copas", "suit": "copas", "number": 7, "element": "agua",
     "sephirah": "Netzach", "zodiac": "Escorpio 20°–30°", "decan": "Venus en Escorpio",
     "title_book_t": "Lord of Illusory Success / Señor del Éxito Ilusorio",
     "meaning_upright": "Venus en Escorpio, tercer decanato: el deseo multiplica las visiones hasta saturar. Netzach (victoria instintiva, Venus) en el signo que transforma el deseo en obsesión. Ensoñación, tentaciones que disfrazan su naturaleza real. La claridad es la herramienta: ¿cuál de estas visiones es real y cuál es proyección?",
     "meaning_reversed": "La ilusión se disipa: vuelta a la realidad, el espejismo reconocido como tal. También: parálisis ante demasiadas opciones, ninguna de las cuales se elige."},
    {"slug": "ocho-de-copas", "suit": "copas", "number": 8, "element": "agua",
     "sephirah": "Hod", "zodiac": "Piscis 0°–10°", "decan": "Saturno en Piscis",
     "title_book_t": "Lord of Abandoned Success / Señor del Éxito Abandonado",
     "meaning_upright": "Saturno en Piscis, primer decanato: la estructura saturnina disuelve la forma pisceana, obligando a buscar más allá de lo establecido. Hod (esplendor, análisis) en el agua más diluida. El éxito construido ya no satisface; hay que dejarlo atrás conscientemente para encontrar algo de mayor profundidad. El abandono es voluntario, no una derrota.",
     "meaning_reversed": "Huir de lo que se debería enfrentar, abandono por cobardía en vez de sabiduría. O bien: quedarse cuando ya era tiempo de partir, aferrarse al éxito vacío por miedo al vacío del camino."},
    {"slug": "nueve-de-copas", "suit": "copas", "number": 9, "element": "agua",
     "sephirah": "Yesod", "zodiac": "Piscis 10°–20°", "decan": "Júpiter en Piscis",
     "title_book_t": "Lord of Material Happiness / Señor de la Felicidad Material",
     "meaning_upright": "Júpiter en Piscis, segundo decanato: la expansión joviana en el agua más porosa produce la satisfacción plena. Yesod (fundamento astral, los deseos realizados) recibe la abundancia emocional hecha carne. La carta del deseo: lo que se quiere llega. Gratitud encarnada, bienestar que se puede ver y tocar.",
     "meaning_reversed": "Complacencia que cierra al mundo. La satisfacción del deseo que se convierte en glotonería o en vacío por falta de nuevas metas. Autosatisfacción que aísla."},
    {"slug": "diez-de-copas", "suit": "copas", "number": 10, "element": "agua",
     "sephirah": "Malkuth", "zodiac": "Piscis 20°–30°", "decan": "Marte en Piscis",
     "title_book_t": "Lord of Perfected Success / Señor del Éxito Perfeccionado",
     "meaning_upright": "Marte en Piscis, tercer decanato: el impulso que completa y cierra el ciclo emocional. Malkuth recibe el amor en su expresión más completa y colectiva. Familia, hogar armonioso, amor que se ha vuelto realidad vivida. El arco iris de la promesa cumplida: no hay más que desear aquí.",
     "meaning_reversed": "La armonía familiar como fachada. Expectativas del hogar ideal que chocan contra la realidad. El ideal de familia convertido en jaula o en fantasía inalcanzable que genera sufrimiento."},
    {"slug": "sota-de-copas", "suit": "copas", "number": 11, "element": "agua",
     "sephirah": None, "zodiac": "Tierra de Agua — Princesa del Cuadrante Meridional-Oriental", "decan": None,
     "title_book_t": "Princess of the Waters / Princesa de las Aguas",
     "meaning_upright": "Tierra de Agua: la intuición que toca lo concreto. Mensajes del inconsciente que llegan como sueños, corazonadas, o invitaciones artísticas y románticas. Receptividad pura sin defensa. Algo del mundo interior está listo para manifestarse.",
     "meaning_reversed": "Ingenuidad emocional que abre la puerta a la manipulación. Mentiras disfrazadas de ternura, el mensaje que no es lo que parece. También: cerrar la receptividad por miedo a ser herido."},
    {"slug": "caballero-de-copas", "suit": "copas", "number": 12, "element": "agua",
     "sephirah": None, "zodiac": "Acuario 20°–Piscis 20° (Fuego de Agua — Caballero GD)", "decan": None,
     "title_book_t": "Knight of Cups / Caballero de Copas — Fuego de Agua",
     "meaning_upright": "Fuego de Agua: el romanticismo en movimiento. Quien actúa desde el corazón, el artista seductor, el mensajero de amor. Las propuestas que llegan con poesía. Su presencia transforma el ambiente emocionalmente; su don es la sensibilidad que se expresa.",
     "meaning_reversed": "Seductor sin sustancia, promesas que evaporan al primer contacto con la realidad. El engañador emocional que usa la sensibilidad como anzuelo. Evasión disfrazada de sensibilidad."},
    {"slug": "reina-de-copas", "suit": "copas", "number": 13, "element": "agua",
     "sephirah": None, "zodiac": "Géminis 20°–Cáncer 20° (Agua de Agua — Reina GD)", "decan": None,
     "title_book_t": "Queen of the Thrones of the Waters / Reina de los Tronos de las Aguas",
     "meaning_upright": "Agua de Agua: empática hasta la profundidad del alma, vidente natural, el espejo que refleja con fidelidad lo que el otro no puede ver en sí mismo. Compasión sin perder la propia orilla. Su presencia sana.",
     "meaning_reversed": "Absorber las emociones del entorno hasta perder identidad propia. La empática sin límites que se ahoga en el dolor de otros. Dependencia emocional, incapacidad de distinguir lo propio de lo ajeno."},
    {"slug": "rey-de-copas", "suit": "copas", "number": 14, "element": "agua",
     "sephirah": None, "zodiac": "Libra 20°–Escorpio 20° (Aire de Agua — Príncipe GD)", "decan": None,
     "title_book_t": "Prince of the Chariot of the Waters / Príncipe del Carro de las Aguas",
     "meaning_upright": "Aire de Agua: quien domina el mundo emocional con sabiduría, no suprimiéndolo sino conociéndolo a fondo. El consejero emocional, el terapeuta, el hombre maduro que sostiene sin ahogarse. Equilibrio entre sentir y pensar.",
     "meaning_reversed": "Control emocional disfrazado de sabiduría: el rey que manipula desde las corrientes subterráneas. Represión que explota de formas inesperadas. También: pérdida en el exceso emocional, el estoico que colapsa."},

    # ── ESPADAS — Aire — Vav — Yetzirah ────────────────────────────────────
    {"slug": "as-de-espadas", "suit": "espadas", "number": 1, "element": "aire",
     "sephirah": "Kether", "zodiac": None, "decan": None,
     "title_book_t": "Root of the Powers of Air / Raíz de los Poderes del Aire",
     "meaning_upright": "La mente en su potencia absoluta, anterior a todo juicio. Kether del Aire: no es aún argumento ni estrategia, es la capacidad de cortar cualquier ilusión con una sola línea recta. La verdad que no tiene consideraciones. Claridad radical que puede usarse para liberar o para herir.",
     "meaning_reversed": "La mente vuelta contra sí misma. Confusión mental, la espada sin mano que la dirija. Verdad que daña sin propósito, o incapacidad de ver con claridad lo que está directamente enfrente."},
    {"slug": "dos-de-espadas", "suit": "espadas", "number": 2, "element": "aire",
     "sephirah": "Chokmah", "zodiac": "Libra 0°–10°", "decan": "Luna en Libra",
     "title_book_t": "Lord of Peace Restored / Señor de la Paz Restaurada",
     "meaning_upright": "Luna en Libra, primer decanato: el instinto de equilibrio modula la mente cortante. Chokmah en el aire cardinal produce una tregua consciente. La paz no es resolución sino acuerdo de no atacar por ahora. Equilibrio inestable elegido como estrategia: los ojos vendados porque ninguna de las opciones es tolerable todavía.",
     "meaning_reversed": "La tregua se rompe: la tensión acumulada estalla o la decisión ya no puede postergarse. También: la venda que cae y revela lo que había que ver, fin del stalemate por agotamiento o por coraje."},
    {"slug": "tres-de-espadas", "suit": "espadas", "number": 3, "element": "aire",
     "sephirah": "Binah", "zodiac": "Libra 10°–20°", "decan": "Saturno en Libra",
     "title_book_t": "Lord of Sorrow / Señor del Dolor",
     "meaning_upright": "Saturno en Libra, segundo decanato: el juicio implacable (Saturno exaltado en Libra) corta los lazos con precisión. Binah (entendimiento, la Gran Madre que comprende el dolor cósmico) en el elemento que piensa lo que siente. Dolor emocional agudo, traición, separación. El pensamiento que hiere porque es verdad.",
     "meaning_reversed": "El dolor en proceso de disolución, o negado: la herida que no sana porque no se reconoce. También: recuperación real que comienza, el corazón que aprende a respirar después del corte."},
    {"slug": "cuatro-de-espadas", "suit": "espadas", "number": 4, "element": "aire",
     "sephirah": "Chesed", "zodiac": "Libra 20°–30°", "decan": "Júpiter en Libra",
     "title_book_t": "Lord of Rest from Strife / Señor del Descanso del Conflicto",
     "meaning_upright": "Júpiter en Libra, tercer decanato: la expansión joviana abre espacio para el descanso después del conflicto. Chesed (misericordia) en el aire que acaba de librar batalla. El guerrero deja las espadas en el altar y recupera fuerzas. No es rendición: es retiro estratégico y necesario. La meditación, la convalecencia, el silencio que regenera.",
     "meaning_reversed": "El descanso que se convierte en parálisis, incapacidad de volver al mundo. Ruptura prematura del retiro cuando todavía se necesita más tiempo. También: negarse al descanso necesario hasta el agotamiento total."},
    {"slug": "cinco-de-espadas", "suit": "espadas", "number": 5, "element": "aire",
     "sephirah": "Geburah", "zodiac": "Acuario 0°–10°", "decan": "Venus en Acuario",
     "title_book_t": "Lord of Defeat / Señor de la Derrota",
     "meaning_upright": "Venus en Acuario, primer decanato: el deseo de harmonía (Venus) en el signo más frío del zodíaco produce una victoria que destruye lo que debería haberse preservado. Geburah (severidad) en el aire que razona sin calidez. Ganar a un coste moral inaceptable. El triunfo donde el vencedor queda solo en el campo.",
     "meaning_reversed": "Elegir no pelear como acto de integridad, la rendición que libera. También: derrota que se niega por orgullo, generando rencor que envenena. El conflicto que sigue vivo bajo la superficie."},
    {"slug": "seis-de-espadas", "suit": "espadas", "number": 6, "element": "aire",
     "sephirah": "Tiphareth", "zodiac": "Acuario 10°–20°", "decan": "Mercurio en Acuario",
     "title_book_t": "Lord of Earned Success / Señor del Éxito Ganado",
     "meaning_upright": "Mercurio en Acuario, segundo decanato: el mensajero en el signo más racional encuentra el camino hacia aguas más calmas. Tiphareth (el corazón solar) recibe la transición con claridad. Alejarse del conflicto conscientemente, viaje de recuperación, el paso difícil hacia algo mejor. No es huida: es movimiento con propósito.",
     "meaning_reversed": "Resistencia a dejar el conflicto, incapacidad de soltar lo que ya se sabe que daña. Estancarse en lo conocido aunque sea doloroso, por miedo a lo que viene después del viaje."},
    {"slug": "siete-de-espadas", "suit": "espadas", "number": 7, "element": "aire",
     "sephirah": "Netzach", "zodiac": "Acuario 20°–30°", "decan": "Luna en Acuario",
     "title_book_t": "Lord of Unstable Effort / Señor del Esfuerzo Inestable",
     "meaning_upright": "Luna en Acuario, tercer decanato: el instinto lunar opera en el signo más impersonal, produciendo estrategias de supervivencia que evitan el confronto directo. Netzach (Victoria instintiva) en el aire que planea. Tomar lo que se puede y escapar; el plan parcial, inteligente pero moralmente comprometido.",
     "meaning_reversed": "El engaño descubierto, la estrategia que fracasa por su propio peso. También: recuperar la honestidad después del desvío, reintegrar la integridad. El ladrón que devuelve lo robado."},
    {"slug": "ocho-de-espadas", "suit": "espadas", "number": 8, "element": "aire",
     "sephirah": "Hod", "zodiac": "Géminis 0°–10°", "decan": "Júpiter en Géminis",
     "title_book_t": "Lord of Shortened Force / Señor de la Fuerza Acortada",
     "meaning_upright": "Júpiter en Géminis, primer decanato: la expansión mental que se ata a sí misma multiplicando las opciones hasta la parálisis. Hod (esplendor, la mente estructurada) en el signo más dividido. La jaula existe en la mente: la figura está atada y vendada pero las puertas están abiertas. La prisión es de percepciones, no de muros reales.",
     "meaning_reversed": "Las vendas caen: la mente se libera de sus propias restricciones. Ver la jaula como lo que siempre fue — hecha de creencias, no de realidad. También: precipitar la salida sin haber entendido el patrón que creó la trampa."},
    {"slug": "nueve-de-espadas", "suit": "espadas", "number": 9, "element": "aire",
     "sephirah": "Yesod", "zodiac": "Géminis 10°–20°", "decan": "Marte en Géminis",
     "title_book_t": "Lord of Despair and Cruelty / Señor de la Desesperación y la Crueldad",
     "meaning_upright": "Marte en Géminis, segundo decanato: el combate marcial se libra en el terreno de la mente dividida. Yesod (el fundamento astral, los miedos inconscientes) recibe la crueldad del pensamiento. La angustia nocturna, la culpa, el pensamiento rumiante que inflige más daño que la realidad exterior. Las 3am son su hora.",
     "meaning_reversed": "El ciclo de angustia se interrumpe; toma de consciencia de que la mayor parte del sufrimiento es mental. El amanecer que llega después de la noche más oscura. Inicio real de la salida del patrón rumiatno."},
    {"slug": "diez-de-espadas", "suit": "espadas", "number": 10, "element": "aire",
     "sephirah": "Malkuth", "zodiac": "Géminis 20°–30°", "decan": "Sol en Géminis",
     "title_book_t": "Lord of Ruin / Señor de la Ruina",
     "meaning_upright": "Sol en Géminis, tercer decanato: la claridad solar ilumina el final absoluto de un ciclo mental. Malkuth recibe la ruina en el mundo físico: diez espadas en la espalda, el cuerpo en el suelo. Pero el cielo del horizonte ya aclara. No puede ir peor; el único camino posible es arriba. El amanecer existe precisamente aquí.",
     "meaning_reversed": "Resistencia al fin necesario que prolonga la agonía. Negarse a reconocer que el ciclo terminó. También: recuperación que comienza desde el punto más bajo, el primer movimiento de quien se levanta."},
    {"slug": "sota-de-espadas", "suit": "espadas", "number": 11, "element": "aire",
     "sephirah": None, "zodiac": "Tierra de Aire — Princesa del Cuadrante Oriental-Nororiental", "decan": None,
     "title_book_t": "Princess of the Rushing Winds / Princesa de los Vientos Veloces",
     "meaning_upright": "Tierra de Aire: la mente que observa antes de actuar. Curiosidad sin límites, vigilancia estratégica, información recopilada con precisión antes de comprometerse. El estudiante del conflicto que aprende las reglas antes de entrar al campo.",
     "meaning_reversed": "La mente que espía y usa el conocimiento como arma. Chismes, crueldad intelectual disfrazada de curiosidad. La información recopilada para herir, no para comprender."},
    {"slug": "caballero-de-espadas", "suit": "espadas", "number": 12, "element": "aire",
     "sephirah": None, "zodiac": "Tauro 20°–Géminis 20° (Fuego de Aire — Caballero GD)", "decan": None,
     "title_book_t": "Knight of Swords / Caballero de Espadas — Fuego de Aire",
     "meaning_upright": "Fuego de Aire: la decisión que ataca sin hesitación. El pensador que convierte el análisis en acción inmediata. Brillante, implacable, llega y corta lo que se necesita cortar. Su velocidad es su mayor virtud y su mayor riesgo.",
     "meaning_reversed": "El fanático intelectual que arrasa sin discriminar. La arrogancia de quien cree que tiene razón y no escucha. Conflictos innecesarios creados por no saber cuándo guardar la espada."},
    {"slug": "reina-de-espadas", "suit": "espadas", "number": 13, "element": "aire",
     "sephirah": None, "zodiac": "Virgo 20°–Libra 20° (Agua de Aire — Reina GD)", "decan": None,
     "title_book_t": "Queen of the Thrones of Air / Reina de los Tronos del Aire",
     "meaning_upright": "Agua de Aire: percepción sin ilusiones, afilada por la experiencia del dolor. La que ha perdido y por eso ve con claridad lo que otros no quieren ver. Independiente, justa, directa. No perdona la deshonestidad porque sabe exactamente a qué huele.",
     "meaning_reversed": "El dolor antiguo convertido en amargura. La frialdad que se disfraza de justicia para ejercer crueldad. El juicio sin misericordia que condena sin considerar el contexto."},
    {"slug": "rey-de-espadas", "suit": "espadas", "number": 14, "element": "aire",
     "sephirah": None, "zodiac": "Capricornio 20°–Acuario 20° (Aire de Aire — Príncipe GD)", "decan": None,
     "title_book_t": "Prince of the Chariots of the Winds / Príncipe de los Carros de los Vientos",
     "meaning_upright": "Aire de Aire: el intelecto en su máxima expresión. El juez, el estratega, el árbitro que piensa antes de hablar y habla con precisión quirúrgica. Domina el pensamiento abstracto y la acción estratégica con igual maestría.",
     "meaning_reversed": "La razón al servicio de la tiranía. El manipulador que usa la lógica para justificar la crueldad. El rey que convierte cada conversación en un tribunal donde él siempre gana."},

    # ── OROS — Tierra — He final — Assiah ──────────────────────────────────
    {"slug": "as-de-oros", "suit": "oros", "number": 1, "element": "tierra",
     "sephirah": "Kether", "zodiac": None, "decan": None,
     "title_book_t": "Root of the Powers of Earth / Raíz de los Poderes de la Tierra",
     "meaning_upright": "La manifestación material en su semilla perfecta. Kether de la Tierra: el oro que contiene la potencia de todo lo que puede construirse. Una oportunidad concreta, un recurso, un cuerpo, una semilla que espera la mano que la trabaje. La tierra lista para recibir.",
     "meaning_reversed": "Oportunidad perdida o bloqueada. El potencial que no se siembra por miedo, por codicia o por parálisis. Los recursos que existen pero no fluyen."},
    {"slug": "dos-de-oros", "suit": "oros", "number": 2, "element": "tierra",
     "sephirah": "Chokmah", "zodiac": "Capricornio 0°–10°", "decan": "Júpiter en Capricornio",
     "title_book_t": "Lord of Harmonious Change / Señor del Cambio Armonioso",
     "meaning_upright": "Júpiter en Capricornio, primer decanato: la expansión joviana bajo la disciplina capricorniana produce malabarismo con gracia. Chokmah (sabiduría como impulso expansivo) en el elemento más estable. Adaptación financiera, equilibrio dinámico entre múltiples demandas. El movimiento perpetuo que no cae.",
     "meaning_reversed": "El malabarismo falla: demasiadas bolas en el aire, desorganización financiera, deudas que se acumulan. El cambio pierde su armonía y todo cae al mismo tiempo."},
    {"slug": "tres-de-oros", "suit": "oros", "number": 3, "element": "tierra",
     "sephirah": "Binah", "zodiac": "Capricornio 10°–20°", "decan": "Marte en Capricornio",
     "title_book_t": "Lord of Material Works / Señor de las Obras Materiales",
     "meaning_upright": "Marte en Capricornio, segundo decanato: Marte exaltado en Capricornio ejecuta con excelencia disciplinada. Binah (entendimiento de las formas duraderas) en la tierra más estructurada. El artesano que trabaja con maestría técnica en equipo. La obra que se construye para durar, el oficio que merece reconocimiento.",
     "meaning_reversed": "Trabajo sin calidad, falta de colaboración, el artesano que no escucha y repite los mismos errores. Mediocridad elegida, obra hecha para pasar el examen, no para durar."},
    {"slug": "cuatro-de-oros", "suit": "oros", "number": 4, "element": "tierra",
     "sephirah": "Chesed", "zodiac": "Capricornio 20°–30°", "decan": "Sol en Capricornio",
     "title_book_t": "Lord of Earthly Power / Señor del Poder Terrenal",
     "meaning_upright": "Sol en Capricornio, tercer decanato: la identidad solar se forja en el poder material consolidado. Chesed (misericordia y estabilidad) en la tierra más ambiciosa. Seguridad financiera real. El riesgo: el que tiene y no puede soltar, la seguridad que se convierte en avaricia preventiva.",
     "meaning_reversed": "Avaricia, miedo a la pérdida que paraliza el flujo natural del recurso. El acaparador que se priva a sí mismo. O bien: generosidad recuperada, el puño que se abre."},
    {"slug": "cinco-de-oros", "suit": "oros", "number": 5, "element": "tierra",
     "sephirah": "Geburah", "zodiac": "Tauro 0°–10°", "decan": "Mercurio en Tauro",
     "title_book_t": "Lord of Material Trouble / Señor del Problema Material",
     "meaning_upright": "Mercurio en Tauro, primer decanato: el pensamiento (Mercurio) atrapado en la necesidad material más básica (Tauro). Geburah (severidad) en la tierra más sensorial. Dificultad económica, exclusión, la sensación de estar afuera en el frío mientras la vida ocurre adentro. La ayuda existe cerca, pero el orgullo o el miedo impide pedirla.",
     "meaning_reversed": "Salir del aislamiento o la privación material. También: negar la situación real, el orgullo que impide recibir ayuda, la trampa de creer que uno debe resolverlo solo."},
    {"slug": "seis-de-oros", "suit": "oros", "number": 6, "element": "tierra",
     "sephirah": "Tiphareth", "zodiac": "Tauro 10°–20°", "decan": "Luna en Tauro",
     "title_book_t": "Lord of Material Success / Señor del Éxito Material",
     "meaning_upright": "Luna en Tauro, segundo decanato: la Luna exaltada en Tauro produce generosidad que fluye naturalmente desde la abundancia. Tiphareth (equilibrio solar) en la tierra más fértil. Dar y recibir en balance real. El mecenas, el préstamo justo, la caridad que no humilla. El recurso que circula y fertiliza.",
     "meaning_reversed": "Caridad condicionada, generosidad como instrumento de control. El que da para que le deban, el poder disfrazado de ayuda. También: recibir sin reciprocar, desequilibrio en el flujo del recurso."},
    {"slug": "siete-de-oros", "suit": "oros", "number": 7, "element": "tierra",
     "sephirah": "Netzach", "zodiac": "Tauro 20°–30°", "decan": "Saturno en Tauro",
     "title_book_t": "Lord of Success Unfulfilled / Señor del Éxito Sin Cumplir",
     "meaning_upright": "Saturno en Tauro, tercer decanato: la restricción saturnina dilata el tiempo de maduración de la semilla taurina. Netzach (victoria instintiva) en el esperar. El fruto que está ahí pero todavía no. La inversión a largo plazo, el trabajo que aún no ha dado su retorno pero lo dará si se sostiene la paciencia.",
     "meaning_reversed": "Impaciencia que abandona antes del fruto. La inversión perdida por no esperar. También: trabajo sin recompensa real, semilla en tierra genuinamente estéril — discernir cuándo esperar y cuándo cambiar de campo."},
    {"slug": "ocho-de-oros", "suit": "oros", "number": 8, "element": "tierra",
     "sephirah": "Hod", "zodiac": "Virgo 0°–10°", "decan": "Sol en Virgo",
     "title_book_t": "Lord of Prudence / Señor de la Prudencia",
     "meaning_upright": "Sol en Virgo, primer decanato: la identidad solar se forja en el servicio técnico disciplinado. Hod (esplendor, el trabajo que se perfecciona) en la tierra más analítica. El aprendiz que hace la misma pieza mil veces hasta que la excelencia sea inevitable. La maestría como camino, no como destino.",
     "meaning_reversed": "Perfeccionismo que paraliza, la habilidad que no se aplica. El artesano que rehace infinitamente sin terminar nada. También: trabajo disperso en detalles irrelevantes que pierden el objeto de vista."},
    {"slug": "nueve-de-oros", "suit": "oros", "number": 9, "element": "tierra",
     "sephirah": "Yesod", "zodiac": "Virgo 10°–20°", "decan": "Venus en Virgo",
     "title_book_t": "Lord of Material Gain / Señor de la Ganancia Material",
     "meaning_upright": "Venus en Virgo, segundo decanato: el placer (Venus) que se ha ganado con el trabajo disciplinado (Virgo). Yesod (fundamento de lo manifestado) en la tierra de la abundancia ganada. Independencia financiera, disfrutar el fruto del trabajo propio sin pedir permiso. El lujo que no genera culpa porque ha sido construido con mérito.",
     "meaning_reversed": "Éxito vacío, riqueza material sin satisfacción interior. O bien: dependencia económica disfrazada de abundancia, el brillo exterior que oculta la fragilidad."},
    {"slug": "diez-de-oros", "suit": "oros", "number": 10, "element": "tierra",
     "sephirah": "Malkuth", "zodiac": "Virgo 20°–30°", "decan": "Mercurio en Virgo",
     "title_book_t": "Lord of Wealth / Señor de la Riqueza",
     "meaning_upright": "Mercurio en Virgo, tercer decanato: Mercurio en domicilio organiza y comunica la riqueza para que se transmita. Malkuth recibe el patrionio completo. Herencia, legado familiar, el sistema de recursos que funciona solo y se pasa de generación en generación. La riqueza que trasciende al individuo.",
     "meaning_reversed": "Herencia disputada, la familia que destruye el patrimonio que debería preservar. La riqueza que ata en vez de liberar, el legado como cadena. También: incapacidad de construir algo que dure más que uno mismo."},
    {"slug": "sota-de-oros", "suit": "oros", "number": 11, "element": "tierra",
     "sephirah": None, "zodiac": "Tierra de Tierra — Princesa del Cuadrante Septentrional-Noroccidental", "decan": None,
     "title_book_t": "Princess of the Echoing Hills / Princesa de las Colinas Resonantes",
     "meaning_upright": "Tierra de Tierra: el estudiante más serio y paciente del mazo. Metódica, práctica, dispuesta a aprender lo que sea necesario antes de actuar. Noticias de oportunidades materiales concretas, nuevas habilidades que empiezan a desarrollarse, el inicio de un proyecto tangible con metodología sólida.",
     "meaning_reversed": "La lentitud que se convierte en inacción total. Oportunidades materiales ignoradas por miedo o pereza. El estudiante que acumula conocimiento pero nunca lo aplica."},
    {"slug": "caballero-de-oros", "suit": "oros", "number": 12, "element": "tierra",
     "sephirah": None, "zodiac": "Aries 20°–Tauro 20° (Fuego de Tierra — Caballero GD)", "decan": None,
     "title_book_t": "Knight of Pentacles / Caballero de Oros — Fuego de Tierra",
     "meaning_upright": "Fuego de Tierra: la acción metódica, implacable y deliberada. El trabajador sin prisa que llega más lejos que todos los que corrieron. Responsabilidad absoluta, fiabilidad que no falla, la rutina como forma de poder. Lento pero inevitable.",
     "meaning_reversed": "La rutina que se convierte en estancamiento. Resistencia al cambio aunque el cambio sea necesario, obstinación improductiva. El trabajador que labora sin visión, eficiente en el camino equivocado."},
    {"slug": "reina-de-oros", "suit": "oros", "number": 13, "element": "tierra",
     "sephirah": None, "zodiac": "Sagitario 20°–Capricornio 20° (Agua de Tierra — Reina GD)", "decan": None,
     "title_book_t": "Queen of the Thrones of Earth / Reina de los Tronos de la Tierra",
     "meaning_upright": "Agua de Tierra: abundancia nutrida con presencia pura. La que hace crecer todo lo que toca: negocios, jardines, personas, proyectos. Práctica, sensual, plenamente segura en el mundo físico. Su riqueza no es acumulación sino fertilidad natural.",
     "meaning_reversed": "El materialismo como sustituto del amor. Sobreprotección sofocante, el hogar como territorio de control disfrazado de cuidado. También: descuido de lo material por bloqueo emocional."},
    {"slug": "rey-de-oros", "suit": "oros", "number": 14, "element": "tierra",
     "sephirah": None, "zodiac": "Leo 20°–Virgo 20° (Aire de Tierra — Príncipe GD)", "decan": None,
     "title_book_t": "Prince of the Chariot of Earth / Príncipe del Carro de la Tierra",
     "meaning_upright": "Aire de Tierra: el empresario que domina el mundo físico con inteligencia y visión. Riqueza construida metódicamente, inversiones prudentes, el hombre que hace crecer el capital porque entiende tanto los números como las personas. El poder material como resultado del pensamiento disciplinado.",
     "meaning_reversed": "Corrupción, codicia sin ética, tratar a las personas como recursos fungibles. El rey que construyó un imperio sobre la explotación. O bien: el intelectual que desprecia lo material hasta la irresponsabilidad."},
]


def main() -> None:
    db = SessionLocal()
    inserted = 0
    skipped = 0
    try:
        rows = _enrich_majors() + MINOR_ARCANA
        for data in rows:
            slug = data["slug"]
            exists = db.query(TarotCard).filter(TarotCard.slug == slug).first()
            if exists:
                skipped += 1
                continue
            # Deriva `arcana` si el dict no lo trae explícito: con `suit` -> menor,
            # sin `suit` -> mayor. Evita NOT NULL failure en tarot_cards.arcana.
            if "arcana" not in data or data["arcana"] is None:
                data["arcana"] = "minor" if data.get("suit") else "major"
            db.add(TarotCard(**data))
            inserted += 1
        db.commit()
        total = db.query(TarotCard).count()
        minors = db.query(TarotCard).filter(TarotCard.arcana == "minor").count()
        majors = db.query(TarotCard).filter(TarotCard.arcana == "major").count()
        print(f"Sembradas {inserted} cartas nuevas (omitidas {skipped} ya presentes).")
        print(f"Catálogo: {majors} mayores + {minors} menores = {total}.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
