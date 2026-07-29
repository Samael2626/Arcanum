"""Puente Materia -> Culpeper: busca el excerpt de regencia planetaria."""

import re
from dataclasses import dataclass
from typing import Optional

from app.models.library import LibraryParagraph


_PLANET_WORDS: dict[str, tuple[str, ...]] = {
    "sun": ("sun", "sol", "solar"),
    "moon": ("moon", "luna", "lunar"),
    "mercury": ("mercury", "mercurio"),
    "venus": ("venus",),
    "mars": ("mars", "marte"),
    "jupiter": ("jupiter", "júpiter", "jove"),
    "saturn": ("saturn", "saturno"),
}

_RULER_HINT = re.compile(
    r"\b(herb of|dominion|govern|ruled by|owns|claims|under the|"
    r"influence of|regid|domin|goberna|pertenece|planta de)\b",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class ExcerptResult:
    text: Optional[str] = None
    is_translation: bool = False


def find_ruling_excerpt(
    paragraphs: list[LibraryParagraph], ruling_planets: list[str]
) -> ExcerptResult:
    """Busca el pasaje que declara la regencia planetaria.

    Prioriza párrafo que nombre el planeta Y traiga frase de regencia;
    si no, el primero que nombre el planeta; si nada, ExcerptResult(None, False).
    Prefiere la traducción ES cuando existe.
    """
    words = tuple(
        w for planet in ruling_planets for w in _PLANET_WORDS.get(planet, ())
    )
    if not words:
        return ExcerptResult()

    word_re = re.compile(
        r"\b(" + "|".join(re.escape(w) for w in words) + r")\b", re.IGNORECASE
    )

    fallback: Optional[tuple[str, bool]] = None
    for p in sorted(paragraphs, key=lambda x: x.position):
        for text, is_es in ((p.text_es, True), (p.text_original, False)):
            if not text or not word_re.search(text):
                continue
            if _RULER_HINT.search(text):
                return ExcerptResult(text=text, is_translation=is_es)
            if fallback is None:
                fallback = (text, is_es)
            break
    if fallback is not None:
        return ExcerptResult(text=fallback[0], is_translation=fallback[1])
    return ExcerptResult()
