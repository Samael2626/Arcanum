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

sys.path.insert(0, str(REPO_ROOT))

from app.core.content import load_dataset  # noqa: E402


def _cargar_entorno() -> None:
    """Lee --env-file y carga el .env ANTES de tocar la sesion de DB.

    Vive dentro de una funcion, no al importar: el modulo debe poder importarse
    desde tests y desde otros scripts sin exigir un .env ni parsear argv.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", default=".env.staging",
                        help="Archivo .env a cargar antes de importar la sesión de DB "
                             "(default: .env.staging)")
    args = parser.parse_args()

    env_path = REPO_ROOT / args.env_file
    if not env_path.exists():
        raise SystemExit(f"No existe {env_path}. Pasa --env-file explícito.")

    from dotenv import load_dotenv
    load_dotenv(env_path, override=True)


# slug -> dict de columnas a fijar.
# element: solo las 3 "madres" (Aleph=Aire, Mem=Agua, Shin=Fuego) lo llevan.
#          Los otros 19 Mayores quedan element=None (no son elementales, son
#          planeta o signo — asignarles un elemento decorativo es inventar
#          correspondencia sin fuente).
# zodiac:  solo las 12 "simples" (signos) lo llevan; planetas/elementos None.
# decan:   NO aplica a los Mayores en Book T/GD (los decanatos son de los 40
#          numerales menores). Se deja intacto (None) — no es un olvido.
# Los datos viven en el catalogo externo (tarot/golden_dawn.json). Ver
# app/core/content.py; ARCANUM_DATA_DIR apunta al repositorio Arcanum-datos.


def cargar_golden_dawn() -> dict[str, dict]:
    return load_dataset("tarot/golden_dawn")


def main() -> None:
    _cargar_entorno()
    from app.db.session import SessionLocal
    from app.models.tarot import TarotCard
    db = SessionLocal()
    updated, missing = 0, []
    try:
        golden_dawn = cargar_golden_dawn()
        for slug, fields in golden_dawn.items():
            card = db.query(TarotCard).filter(TarotCard.slug == slug).first()
            if not card:
                missing.append(slug)
                continue
            for col, value in fields.items():
                setattr(card, col, value)
            updated += 1
        db.commit()
        print(f"Actualizados {updated}/{len(golden_dawn)} Arcanos Mayores.")
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
