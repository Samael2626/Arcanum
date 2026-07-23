"""Ingesta de obras de dominio público para la sección Lecturas.

Convierte una fuente en texto plano a un documento estructurado
(obra → capítulos → párrafos) listo para servir por la API.

## Por qué texto y no PDF

Un escaneo de estas obras pesa ~80 MB; el mismo texto, 0.5 MB comprimido —
160 veces menos. Y sobre todo: el texto es direccionable. Se puede buscar,
resaltar, anclar una lección a un párrafo concreto y mandarle ese pasaje al
oráculo. Sobre una imagen escaneada nada de eso es posible.

## Licencia

Solo se ingiere obra en dominio público (autor fallecido hace >70 años).
El texto de Project Gutenberg se usa **sin su cabecera ni su pie**: la
transcripción de una obra de dominio público lo sigue siendo, y al retirar la
marca «Project Gutenberg» no aplica su licencia de marca. Por eso
`strip_gutenberg_boilerplate()` no es cosmético — es un requisito.

Uso:
    python scripts/ingest_library.py culpeper --out scripts/library_data/
"""

from __future__ import annotations

import argparse
from collections import Counter
import json
import re
import unicodedata
from dataclasses import asdict, dataclass, field
from pathlib import Path
from urllib.request import Request, urlopen

# ── Modelo del documento ───────────────────────────────────────────────────


@dataclass
class Paragraph:
    """Unidad direccionable: a esto apunta una lección o un resaltado."""

    anchor: str  # p.ej. "culpeper.all-heal.3" — estable entre reingestas
    text: str


@dataclass
class Chapter:
    slug: str
    title: str
    # Qué es este capítulo. Culpeper no es homogéneo: lleva epístolas al
    # principio, ~370 entradas de planta, y un tratado de recetas al final.
    # Mezclarlos daría una lista larguísima donde no se distingue una hierba
    # de un prefacio.
    kind: str = "text"  # "herb" | "catalogue" | "appendix" | "front"
    # Metadatos propios de la obra (en Culpeper: el planeta regente).
    meta: dict[str, str] = field(default_factory=dict)
    paragraphs: list[Paragraph] = field(default_factory=list)


@dataclass
class Work:
    slug: str
    title: str
    author: str
    year: int
    language: str
    source_url: str
    license_note: str
    chapters: list[Chapter] = field(default_factory=list)

    @property
    def word_count(self) -> int:
        return sum(len(p.text.split()) for c in self.chapters for p in c.paragraphs)


# ── Utilidades ─────────────────────────────────────────────────────────────

_PG_START = re.compile(r"\*\*\*\s*START OF TH(E|IS) PROJECT GUTENBERG EBOOK.*?\*\*\*", re.I)
_PG_END = re.compile(r"\*\*\*\s*END OF TH(E|IS) PROJECT GUTENBERG EBOOK.*?\*\*\*", re.I)


def strip_gutenberg_boilerplate(raw: str) -> str:
    """Deja solo la obra, sin cabecera ni pie de Project Gutenberg.

    Requisito de licencia, no limpieza estética: ver el docstring del módulo.
    Falla ruidoso si no encuentra los marcadores — ingerir la obra con el
    aviso legal pegado sería peor que no ingerirla.
    """
    start = _PG_START.search(raw)
    end = _PG_END.search(raw)
    if not start or not end:
        raise ValueError(
            "No se encontraron los marcadores START/END de Project Gutenberg. "
            "Revisa la fuente antes de ingerir: el texto podría llevar el "
            "aviso legal incrustado."
        )
    return raw[start.end() : end.start()]


def slugify(value: str) -> str:
    """Slug ASCII estable, para anclas que no cambien entre reingestas."""
    value = unicodedata.normalize("NFKD", value)
    value = value.encode("ascii", "ignore").decode("ascii").lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")


_LOWERCASE_WORDS = {"or", "and", "of", "the", "in", "with", "a", "its"}


def title_case(value: str) -> str:
    """Capitaliza sin romper apóstrofes ni guiones.

    `str.title()` no sirve: convierte "ADDER'S TONGUE" en "Adder'S Tongue"
    porque trata el apóstrofe como separador de palabra. Estos títulos se
    muestran tal cual al usuario.
    """
    words = []
    for i, word in enumerate(value.split()):
        lower = word.lower()
        if i > 0 and lower.strip(".,") in _LOWERCASE_WORDS:
            words.append(lower)
            continue
        # Capitaliza el primer carácter de cada tramo separado por guion,
        # dejando intacto lo que sigue a un apóstrofe.
        words.append("-".join(part[:1].upper() + part[1:] for part in lower.split("-")))
    return " ".join(words)


def normalize_paragraphs(block: str) -> list[str]:
    """Reflowea el texto a párrafos: los saltos de línea duros del original
    son de máquina de escribir, no del autor, y en móvil rompen la lectura."""
    out = []
    for chunk in re.split(r"\n\s*\n", block):
        text = " ".join(line.strip() for line in chunk.splitlines())
        text = re.sub(r"\s{2,}", " ", text).strip()
        if text:
            out.append(text)
    return out


# ── Culpeper · The Complete Herbal (1653) ──────────────────────────────────

CULPEPER_SOURCE = "https://www.gutenberg.org/cache/epub/49513/pg49513.txt"

# Las entradas de planta son títulos indentados en mayúsculas: "    ALL-HEAL."
_ENTRY = re.compile(r"^ {4}([A-Z][A-Z0-9 .,'’()-]{2,60})\.?\s*$", re.M)

_PLANET = r"(Saturn|Jupiter|Mars|Sol|Sun|Venus|Mercury|Luna|Moon)"

# Regencia FUERTE: construcciones que casi nunca son incidentales. "It is an
# herb of Mars", "under the dominion of Saturn", "governed by Jupiter", "Venus
# owns this herb". Se buscan en toda la sección.
_STRONG_RULER = re.compile(
    r"(?:herb|tree|plant)\s+of\s+(?:the\s+)?" + _PLANET
    + r"|(?:planet|dominion|influence)\s+of\s+(?:the\s+)?" + _PLANET
    + r"|governed\s+by\s+(?:the\s+)?" + _PLANET
    + r"|" + _PLANET + r"\s+(?:owns|governs|claims|rules)"
    # Posesivo: "The herb is Jupiter's" (con apóstrofe recto o tipográfico).
    + r"|" + _PLANET + r"['’']s\b",
    re.I,
)

# Regencia DÉBIL: "X are under Jupiter". Es regencia cuando enumera subtipos al
# inicio (la rosa roja bajo Júpiter, la damascena bajo Venus…), pero "those
# under Saturn" más adelante son enfermedades que trata, no su regencia. Por
# eso solo se acepta en la cabecera de la sección y nunca tras "those"/"parts".
_WEAK_UNDER = re.compile(r"(?<!those )under\s+(?:the\s+)?" + _PLANET, re.I)
_WEAK_LIMIT = 170  # caracteres iniciales donde "under X" aún es regencia

_PLANET_KEY = {
    "saturn": "saturn",
    "jupiter": "jupiter",
    "mars": "mars",
    "sol": "sun",
    "sun": "sun",
    "venus": "venus",
    "mercury": "mercury",
    "luna": "moon",
    "moon": "moon",
}


# Marcas de que un planeta está siendo NEGADO, no afirmado. Culpeper discute
# atribuciones ajenas antes de dar la suya: en henbane escribe "I wonder how
# astrologers could take on them to make this an herb of Jupiter... it is under
# the dominion of Saturn". Coger el primer planeta daba Júpiter — justo el que
# él rechaza. Si alguna de estas aparece en los ~60 caracteres previos, el
# planeta se descarta.
_NEGATION = re.compile(
    r"\b(wonder|how could|cannot|could not|is not|no astrologer|mistake|"
    r"erroneously|falsely|deny|denied)\b",
    re.I,
)


def _extract_rulers(paragraphs: list[str]) -> list[str]:
    """Planetas regentes AFIRMADOS, desde 'Government and virtues'.

    Devuelve una lista, no un valor único, porque una entrada legítima puede
    declarar varios: Culpeper pone la rosa roja bajo Júpiter, la damascena bajo
    Venus y la blanca bajo la Luna. Aplastar eso a un solo planeta perdía
    información y creaba falsas discrepancias con Materia Arcana.

    Es el puente con Materia: la misma correspondencia que la app afirma, ahora
    citable. Solo se mira esta sección — un planeta nombrado en la descripción
    botánica no es una regencia.
    """
    for p in paragraphs:
        if "_Government and virtues._]" not in p and "_Government._]" not in p:
            continue
        section = p.split("]", 1)[1] if "]" in p else p
        counts: "Counter[str]" = Counter()

        def add(match: "re.Match[str]") -> None:
            # Un planeta negado es una atribución que el autor rechaza, no la
            # suya: "I wonder how astrologers could make this an herb of…".
            window = section[max(0, match.start() - 60) : match.start()]
            if _NEGATION.search(window):
                return
            planet = next(
                (_PLANET_KEY[g.lower()] for g in match.groups() if g), None
            )
            if planet:
                counts[planet] += 1

        # 1) Regencia fuerte, en cualquier posición.
        for match in _STRONG_RULER.finditer(section):
            add(match)
        # 2) "under X" solo en la cabecera, donde aún es regencia (subtipos)
        #    y no una lista de dolencias.
        if not counts:
            for match in _WEAK_UNDER.finditer(section[:_WEAK_LIMIT]):
                add(match)

        if not counts:
            return []
        # El planeta REGENTE es el que domina. En el texto (larguísimo) de
        # wormwood, "herb of Mars" aparece diez veces y otros planetas una vez
        # en digresiones: gana Marte. Cuando varios empatan —la rosa roja bajo
        # Júpiter, la damascena bajo Venus— son regencias legítimas de subtipo
        # y se conservan todas.
        top = max(counts.values())
        return [planet for planet, n in counts.items() if n == top]
    return []


# Marcadores que identifican una entrada de hierba de verdad. Un prefacio o
# una receta no los tiene, así que sirven para clasificar sin adivinar.
_HERB_MARKERS = ("_Descript._]", "_Government and virtues._]", "_Government._]")

# El tratado final ("English Physician Enlarged") usa títulos NO indentados:
# "CHAPTER I.", "SECTION II.", "OF THE STOMACH...". Sin separarlo, sus ~540
# párrafos caen en un único capítulo imposible de leer.
_SUBHEADING = re.compile(r"^([A-Z][A-Z0-9 .,'’()-]{3,70})\.?\s*$", re.M)


# El catálogo de materia médica del College: listas de raíces, cortezas,
# piedras, jugos… No son hierbas con regencia, pero tampoco preliminares.
_CATALOGUE_TITLES = {
    "roots", "barks", "raspings", "juices", "stones", "woods", "herbs",
    "flowers", "fruits", "seeds", "gums", "leaves", "living creatures",
    "belonging to the sea", "things bred from plants", "and excrements",
    "salts", "metals", "minerals",
}


def _classify(title: str, paragraphs: list[str]) -> str:
    """Clasifica lo que no es una entrada de hierba.

    Llamarlo todo "front" mentía: el catálogo de materia médica aparecía
    junto a las epístolas del prefacio.
    """
    if title.strip().rstrip(".").lower() in _CATALOGUE_TITLES:
        return "catalogue"
    if any("_College._]" in p or "_The College._]" in p for p in paragraphs):
        return "catalogue"
    return "front"


def _split_appendix(title: str, block: str, work_slug: str) -> list[Chapter]:
    """Parte un bloque largo de apéndice por sus propios subtítulos."""
    matches = list(_SUBHEADING.finditer(block))
    if not matches:
        return []

    chapters: list[Chapter] = []
    for i, match in enumerate(matches):
        sub_title = match.group(1).strip().rstrip(".")
        end = matches[i + 1].start() if i + 1 < len(matches) else len(block)
        paragraphs = normalize_paragraphs(block[match.end() : end])
        if not paragraphs:
            continue
        slug = slugify(f"{title}-{sub_title}")
        chapters.append(
            Chapter(
                slug=slug,
                title=title_case(sub_title),
                kind="appendix",
                paragraphs=[
                    Paragraph(anchor=f"{work_slug}.{slug}.{n}", text=text)
                    for n, text in enumerate(paragraphs)
                ],
            )
        )
    return chapters


def parse_culpeper(raw: str) -> Work:
    body = strip_gutenberg_boilerplate(raw)

    matches = list(_ENTRY.finditer(body))
    if not matches:
        raise ValueError("Culpeper: no se detectó ninguna entrada de planta.")

    work = Work(
        slug="culpeper-complete-herbal",
        title="The Complete Herbal",
        author="Nicholas Culpeper",
        year=1653,
        language="en",
        source_url=CULPEPER_SOURCE,
        license_note=(
            "Dominio público: Nicholas Culpeper († 1654). Transcripción de "
            "Project Gutenberg #49513, usada sin su cabecera ni su pie."
        ),
    )

    seen: dict[str, int] = {}
    for i, match in enumerate(matches):
        title = match.group(1).strip().rstrip(".")
        block = body[match.end() : matches[i + 1].start() if i + 1 < len(matches) else len(body)]
        paragraphs = normalize_paragraphs(block)

        # Una entrada real describe una planta; los restos de portada e
        # imprenta caen aquí y se descartan por tamaño.
        if len(paragraphs) < 2 or sum(len(p.split()) for p in paragraphs) < 60:
            continue

        is_herb = any(m in p for p in paragraphs for m in _HERB_MARKERS)

        # Bloques largos sin marcadores de hierba: portada, epístolas y el
        # tratado final. Se parten por sus propios subtítulos en vez de
        # quedar como un muro de cientos de párrafos.
        if not is_herb and len(paragraphs) > 20:
            block = body[match.end() : matches[i + 1].start() if i + 1 < len(matches) else len(body)]
            sub_chapters = _split_appendix(title, block, work.slug)
            if sub_chapters:
                work.chapters.extend(sub_chapters)
                continue

        slug = slugify(title)
        # Culpeper repite nombres ("WATER AGRIMONY" y variantes): se
        # desambigua para que las anclas sigan siendo únicas y estables.
        seen[slug] = seen.get(slug, 0) + 1
        if seen[slug] > 1:
            slug = f"{slug}-{seen[slug]}"

        chapter = Chapter(
            slug=slug,
            title=title_case(title),
            kind="herb" if is_herb else _classify(title, paragraphs),
            meta={},
        )
        if is_herb:
            rulers = _extract_rulers(paragraphs)
            if rulers:
                # Lista siempre; el "principal" (para un solo glifo) es el
                # primero afirmado, pero la app usa el planeta de Materia como
                # principal — esto es solo lo que la OBRA declara.
                chapter.meta["ruling_planets"] = rulers
                chapter.meta["ruling_planet"] = rulers[0]

        chapter.paragraphs = [
            Paragraph(anchor=f"{work.slug}.{slug}.{n}", text=text)
            for n, text in enumerate(paragraphs)
        ]
        work.chapters.append(chapter)

    return work


PARSERS = {"culpeper": (CULPEPER_SOURCE, parse_culpeper)}


# ── CLI ────────────────────────────────────────────────────────────────────


def fetch(url: str) -> str:
    request = Request(url, headers={"User-Agent": "ARCANUM-library-ingest/1.0"})
    with urlopen(request, timeout=120) as response:
        return response.read().decode("utf-8", errors="replace")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", choices=sorted(PARSERS))
    parser.add_argument("--out", type=Path, default=Path("scripts/library_data"))
    parser.add_argument("--source", help="Fichero local en vez de descargar")
    args = parser.parse_args()

    url, parse = PARSERS[args.work]
    raw = Path(args.source).read_text(encoding="utf-8") if args.source else fetch(url)

    work = parse(raw)
    args.out.mkdir(parents=True, exist_ok=True)
    destination = args.out / f"{work.slug}.json"
    destination.write_text(
        json.dumps(asdict(work), ensure_ascii=False, indent=1), encoding="utf-8"
    )

    import gzip
    from collections import Counter

    kinds = Counter(c.kind for c in work.chapters)
    with_ruler = sum(1 for c in work.chapters if c.meta.get("ruling_planets"))
    compact = json.dumps(asdict(work), ensure_ascii=False).encode()
    longest = max(work.chapters, key=lambda c: len(c.paragraphs))

    print(f"{work.title} - {work.author} ({work.year})")
    print(f"  capitulos    : {len(work.chapters)}  {dict(kinds)}")
    print(f"  parrafos     : {sum(len(c.paragraphs) for c in work.chapters)}")
    print(f"  palabras     : {work.word_count:,}")
    print(f"  con regente  : {with_ruler} de {kinds['herb']} hierbas")
    print(f"  cap. mayor   : {longest.title} ({len(longest.paragraphs)} parrafos)")
    print(f"  JSON         : {destination}")
    print(f"  peso         : {len(compact) / 1024:.0f} KB  ->  "
          f"{len(gzip.compress(compact, 9)) / 1024:.0f} KB gzip")


if __name__ == "__main__":
    main()
