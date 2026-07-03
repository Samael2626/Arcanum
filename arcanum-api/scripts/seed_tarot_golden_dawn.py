"""Enriquece los 22 Arcanos Mayores con correspondencias Golden Dawn / Book of Thoth.

Puebla, por slug (idempotente — UPDATE, no INSERT), las columnas cabalísticas
añadidas en migration 003 (`hebrew_letter`, `gematria_value`, `astro_correspondence`,
`element`, `zodiac`, `path_number`, `path_from`, `path_to`, `name_es`) para los
22 Mayores. NO toca los 56 Menores ni ninguna otra tabla.

── Decisión Tzaddi (El Emperador / La Estrella) ─────────────────────────────
ARCANUM usa nomenclatura Thoth (Crowley, *The Book of Thoth*, 1944) de forma
consistente en todo el mazo, no la atribución tradicional de la Golden Dawn.

Base: Liber AL vel Legis I:57 — "All these old letters of my Book are aright;
but Tzaddi is not the Star." Crowley interpretó esto como orden de intercambiar
las letras hebreas (y por tanto los senderos) de El Emperador y La Estrella,
manteniendo el signo zodiacal que cada carta ya tenía tradicionalmente:

  GD tradicional:  El Emperador = Heh (ה)   = sendero 15 (Chokmah-Tiphareth) = Aries
                    La Estrella  = Tzaddi (צ) = sendero 28 (Netzach-Yesod)    = Acuario

  Thoth (Crowley): El Emperador = Tzaddi (צ) = sendero 28 (Netzach-Yesod)    = Aries
                    La Estrella  = Heh (ה)   = sendero 15 (Chokmah-Tiphareth) = Acuario

Es decir: el signo zodiacal de cada carta NO cambia (Emperador sigue siendo
Aries, Estrella sigue siendo Acuario) — lo que cambia es qué letra/sendero
ocupa cada carta. Esto rompe la correspondencia fija letra→astro de Sepher
Yetzirah para estas dos letras específicamente (Heh debería ser Aries y
Tzaddi debería ser Acuario por Sepher Yetzirah puro), pero es la atribución
deliberada y documentada del propio Crowley (descrita como "doble bucle en
el zodíaco" alrededor de Piscis). Todas las demás 20 cartas usan la
atribución estándar de Sepher Yetzirah / Book T, compartida por GD y Thoth
sin controversia.

Fuentes:
- Aleister Crowley, *The Book of Thoth* (1944), cap. Atu IV / Atu XVII.
- Liber AL vel Legis I:57.
- Israel Regardie, *The Golden Dawn* (Book T) — atribuciones base de los 20
  senderos no controvertidos.
- Vault D:\\Brain\\40-Esoterismo\\Tarot\\Correspondencias-Tarot-Arbol-de-la-Vida.md
  (documenta la atribución GD tradicional; este seed diverge deliberadamente
  en Emperador/Estrella para ser fiel a Thoth — ver nota en ese archivo).

Uso:
    cd arcanum-api
    venv\\Scripts\\python.exe scripts/seed_tarot_golden_dawn.py                 # aplica a .env.staging
    venv\\Scripts\\python.exe scripts/seed_tarot_golden_dawn.py --env-file .env  # otro entorno
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")  # consola Windows cp1252 no imprime hebreo/glifos

REPO_ROOT = Path(__file__).resolve().parents[1]

parser = argparse.ArgumentParser()
parser.add_argument("--env-file", default=".env.staging",
                     help="Archivo .env a cargar antes de importar la sesión de DB (default: .env.staging)")
args = parser.parse_args()

env_path = REPO_ROOT / args.env_file
if not env_path.exists():
    raise SystemExit(f"No existe {env_path}. Pasa --env-file explícito.")

from dotenv import load_dotenv  # noqa: E402
load_dotenv(env_path, override=True)  # DEBE cargarse antes de importar app.db.session

sys.path.insert(0, str(REPO_ROOT))

from app.db.session import SessionLocal  # noqa: E402
from app.models.tarot import TarotCard  # noqa: E402


# slug -> dict de columnas a fijar.
# element: solo las 3 "madres" (Aleph=Aire, Mem=Agua, Shin=Fuego) lo llevan.
#          Los otros 19 Mayores quedan element=None (no son elementales, son
#          planeta o signo — asignarles un elemento decorativo es inventar
#          correspondencia sin fuente).
# zodiac:  solo las 12 "simples" (signos) lo llevan; planetas/elementos None.
# decan:   NO aplica a los Mayores en Book T/GD (los decanatos son de los 40
#          numerales menores). Se deja intacto (None) — no es un olvido.
MAJOR_GOLDEN_DAWN: dict[str, dict] = {
    "el-loco": dict(
        name_es="El Loco", hebrew_letter="Aleph (א)", gematria_value=1,
        astro_correspondence="Aire 🜁", element="aire", zodiac=None,
        path_number=11, path_from="Kether", path_to="Chokmah",
    ),
    "el-mago": dict(
        name_es="El Mago", hebrew_letter="Beth (ב)", gematria_value=2,
        astro_correspondence="Mercurio ☿", element=None, zodiac=None,
        path_number=12, path_from="Kether", path_to="Binah",
    ),
    "la-sacerdotisa": dict(
        name_es="La Sacerdotisa", hebrew_letter="Gimel (ג)", gematria_value=3,
        astro_correspondence="Luna ☽", element=None, zodiac=None,
        path_number=13, path_from="Kether", path_to="Tiphareth",
    ),
    "la-emperatriz": dict(
        name_es="La Emperatriz", hebrew_letter="Daleth (ד)", gematria_value=4,
        astro_correspondence="Venus ♀", element=None, zodiac=None,
        path_number=14, path_from="Chokmah", path_to="Binah",
    ),
    # ── THOTH SWAP (Liber AL I:57) — ver docstring del módulo ──────────────
    "el-emperador": dict(
        name_es="El Emperador", hebrew_letter="Tzaddi (צ)", gematria_value=90,
        astro_correspondence="Aries ♈", element=None, zodiac="Aries ♈",
        path_number=28, path_from="Netzach", path_to="Yesod",
    ),
    "el-hierofante": dict(
        name_es="El Hierofante", hebrew_letter="Vav (ו)", gematria_value=6,
        astro_correspondence="Tauro ♉", element=None, zodiac="Tauro ♉",
        path_number=16, path_from="Chokmah", path_to="Chesed",
    ),
    "los-enamorados": dict(
        name_es="Los Enamorados", hebrew_letter="Zayin (ז)", gematria_value=7,
        astro_correspondence="Géminis ♊", element=None, zodiac="Géminis ♊",
        path_number=17, path_from="Binah", path_to="Tiphareth",
    ),
    "el-carro": dict(
        name_es="El Carro", hebrew_letter="Cheth (ח)", gematria_value=8,
        astro_correspondence="Cáncer ♋", element=None, zodiac="Cáncer ♋",
        path_number=18, path_from="Binah", path_to="Geburah",
    ),
    "la-fuerza": dict(
        name_es="La Fuerza", hebrew_letter="Teth (ט)", gematria_value=9,
        astro_correspondence="Leo ♌", element=None, zodiac="Leo ♌",
        path_number=19, path_from="Chesed", path_to="Geburah",
    ),
    "el-ermitano": dict(
        name_es="El Ermitaño", hebrew_letter="Yod (י)", gematria_value=10,
        astro_correspondence="Virgo ♍", element=None, zodiac="Virgo ♍",
        path_number=20, path_from="Chesed", path_to="Tiphareth",
    ),
    "la-rueda": dict(
        name_es="La Rueda de la Fortuna", hebrew_letter="Kaph (כ)", gematria_value=20,
        astro_correspondence="Júpiter ♃", element=None, zodiac=None,
        path_number=21, path_from="Chesed", path_to="Netzach",
    ),
    "la-justicia": dict(
        name_es="La Justicia", hebrew_letter="Lamed (ל)", gematria_value=30,
        astro_correspondence="Libra ♎", element=None, zodiac="Libra ♎",
        path_number=22, path_from="Geburah", path_to="Tiphareth",
    ),
    "el-colgado": dict(
        name_es="El Colgado", hebrew_letter="Mem (מ)", gematria_value=40,
        astro_correspondence="Agua 🜄", element="agua", zodiac=None,
        path_number=23, path_from="Geburah", path_to="Hod",
    ),
    "la-muerte": dict(
        name_es="La Muerte", hebrew_letter="Nun (נ)", gematria_value=50,
        astro_correspondence="Escorpio ♏", element=None, zodiac="Escorpio ♏",
        path_number=24, path_from="Tiphareth", path_to="Netzach",
    ),
    "la-templanza": dict(
        name_es="La Templanza", hebrew_letter="Samekh (ס)", gematria_value=60,
        astro_correspondence="Sagitario ♐", element=None, zodiac="Sagitario ♐",
        path_number=25, path_from="Tiphareth", path_to="Yesod",
    ),
    "el-diablo": dict(
        name_es="El Diablo", hebrew_letter="Ayin (ע)", gematria_value=70,
        astro_correspondence="Capricornio ♑", element=None, zodiac="Capricornio ♑",
        path_number=26, path_from="Tiphareth", path_to="Hod",
    ),
    "la-torre": dict(
        name_es="La Torre", hebrew_letter="Peh (פ)", gematria_value=80,
        astro_correspondence="Marte ♂", element=None, zodiac=None,
        path_number=27, path_from="Netzach", path_to="Hod",
    ),
    # ── THOTH SWAP (Liber AL I:57) — ver docstring del módulo ──────────────
    "la-estrella": dict(
        name_es="La Estrella", hebrew_letter="Heh (ה)", gematria_value=5,
        astro_correspondence="Acuario ♒", element=None, zodiac="Acuario ♒",
        path_number=15, path_from="Chokmah", path_to="Tiphareth",
    ),
    "la-luna": dict(
        name_es="La Luna", hebrew_letter="Qoph (ק)", gematria_value=100,
        astro_correspondence="Piscis ♓", element=None, zodiac="Piscis ♓",
        path_number=29, path_from="Netzach", path_to="Malkuth",
    ),
    "el-sol": dict(
        name_es="El Sol", hebrew_letter="Resh (ר)", gematria_value=200,
        astro_correspondence="Sol ☉", element=None, zodiac=None,
        path_number=30, path_from="Hod", path_to="Yesod",
    ),
    "el-juicio": dict(
        name_es="El Juicio", hebrew_letter="Shin (ש)", gematria_value=300,
        astro_correspondence="Fuego 🜂", element="fuego", zodiac=None,
        path_number=31, path_from="Hod", path_to="Malkuth",
    ),
    "el-mundo": dict(
        # Tav es letra "doble" (planeta), no "madre" (elemento): su atribución
        # estricta Book T/GD es Saturno. La glosa popular "Tierra/Universo"
        # (síntesis de los 4 elementos completos) es simbólica, no una
        # atribución de Sepher Yetzirah — por eso element=None aquí, corrigiendo
        # el "tierra" decorativo que traía el seed original.
        name_es="El Mundo", hebrew_letter="Tav (ת)", gematria_value=400,
        astro_correspondence="Saturno ♄", element=None, zodiac=None,
        path_number=32, path_from="Yesod", path_to="Malkuth",
    ),
}


def main() -> None:
    db = SessionLocal()
    updated, missing = 0, []
    try:
        for slug, fields in MAJOR_GOLDEN_DAWN.items():
            card = db.query(TarotCard).filter(TarotCard.slug == slug).first()
            if not card:
                missing.append(slug)
                continue
            for col, value in fields.items():
                setattr(card, col, value)
            updated += 1
        db.commit()
        print(f"Actualizados {updated}/{len(MAJOR_GOLDEN_DAWN)} Arcanos Mayores.")
        if missing:
            print(f"AVISO: slugs no encontrados en tarot_cards: {missing}")

        rows = (
            db.query(TarotCard)
            .filter(TarotCard.arcana == "major")
            .order_by(TarotCard.number)
            .all()
        )
        print(f"\nVerificación ({len(rows)} mayores):")
        non_null_ok = 0
        for r in rows:
            ok = r.hebrew_letter is not None and r.astro_correspondence is not None
            non_null_ok += int(ok)
            print(f"  {r.number:>2} {r.slug:<16} {r.hebrew_letter or '—':<14} "
                  f"{r.astro_correspondence or '—':<14} path={r.path_number} "
                  f"({r.path_from}->{r.path_to}) elem={r.element} zodiac={r.zodiac} "
                  f"gem={r.gematria_value} {'OK' if ok else 'FALTA'}")
        print(f"\n{non_null_ok}/{len(rows)} con hebrew_letter y astro_correspondence no-null.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
