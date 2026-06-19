"""Siembra Materia Arcana con correspondencias tradicionales (idempotente por slug).

Uso: cd arcanum-api && venv\\Scripts\\python.exe scripts/seed_materia.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db.session import SessionLocal  # noqa: E402
from app.models.materia_item import MateriaItem  # noqa: E402

ITEMS: list[dict] = [
    # ── Hierbas ──────────────────────────────────────────────────────────────
    dict(slug="romero", item_type="herb", name="Romero", planet="sun", element="fuego",
         aliases=["Rosemary"],
         properties={"intenciones": ["limpieza", "protección", "memoria"],
                     "notas": "Hierba solar de purificación; quema para despejar un espacio.",
                     "parte": "hojas"}),
    dict(slug="lavanda", item_type="herb", name="Lavanda", planet="mercury", element="aire",
         aliases=["Lavender"],
         properties={"intenciones": ["calma", "sueño", "claridad mental"],
                     "notas": "Apacigua la mente; favorece el sueño y la adivinación serena.",
                     "parte": "flores"}),
    dict(slug="rosa", item_type="herb", name="Rosa", planet="venus", element="agua",
         aliases=["Rose"],
         properties={"intenciones": ["amor", "belleza", "autoestima"],
                     "notas": "Flor de Venus por excelencia; abre el corazón.",
                     "parte": "pétalos"}),
    dict(slug="canela", item_type="herb", name="Canela", planet="sun", element="fuego",
         aliases=["Cinnamon"],
         properties={"intenciones": ["prosperidad", "éxito", "poder"],
                     "notas": "Acelera y enciende cualquier intención; atrae dinero.",
                     "parte": "corteza"}),
    dict(slug="artemisa", item_type="herb", name="Artemisa", planet="moon", element="tierra",
         aliases=["Ajenjo", "Mugwort"],
         properties={"intenciones": ["adivinación", "sueños", "visiones"],
                     "notas": "Hierba lunar de la videncia; té o sahumerio antes del trabajo oracular.",
                     "parte": "hojas"}),
    dict(slug="salvia", item_type="herb", name="Salvia", planet="jupiter", element="aire",
         aliases=["Sage"],
         properties={"intenciones": ["limpieza", "sabiduría", "longevidad"],
                     "notas": "Destierra lo denso y atrae consejo sabio.",
                     "parte": "hojas"}),
    # ── Piedras ──────────────────────────────────────────────────────────────
    dict(slug="cuarzo-claro", item_type="stone", name="Cuarzo Claro", planet=None, element=None,
         aliases=["Clear Quartz", "Cristal de roca"],
         properties={"intenciones": ["amplificación", "claridad", "sanación"],
                     "notas": "Cristal maestro; amplifica y dirige cualquier intención."}),
    dict(slug="amatista", item_type="stone", name="Amatista", planet="jupiter", element="agua",
         aliases=["Amethyst"],
         properties={"intenciones": ["intuición", "paz", "sobriedad"],
                     "notas": "Eleva la mente; protege el sueño y la meditación."}),
    dict(slug="obsidiana", item_type="stone", name="Obsidiana", planet="saturn", element="tierra",
         aliases=["Obsidian"],
         properties={"intenciones": ["protección", "destierro", "anclaje"],
                     "notas": "Espejo del inframundo; corta y absorbe lo negativo."}),
    dict(slug="cornalina", item_type="stone", name="Cornalina", planet="mars", element="fuego",
         aliases=["Carnelian"],
         properties={"intenciones": ["coraje", "vitalidad", "deseo"],
                     "notas": "Enciende la voluntad y la fuerza de acción."}),
    # ── Metales ──────────────────────────────────────────────────────────────
    dict(slug="oro", item_type="metal", name="Oro", planet="sun", element="fuego",
         aliases=["Gold"],
         properties={"intenciones": ["éxito", "vitalidad", "riqueza"],
                     "notas": "Metal del Sol; salud, poder e influencia."}),
    dict(slug="plata", item_type="metal", name="Plata", planet="moon", element="agua",
         aliases=["Silver"],
         properties={"intenciones": ["psiquismo", "intuición", "sueños"],
                     "notas": "Metal de la Luna; receptividad y videncia."}),
    dict(slug="cobre", item_type="metal", name="Cobre", planet="venus", element="tierra",
         aliases=["Copper"],
         properties={"intenciones": ["amor", "sanación", "armonía"],
                     "notas": "Metal de Venus; conduce energía de afecto y belleza."}),
    # ── Inciensos ────────────────────────────────────────────────────────────
    dict(slug="olibano", item_type="incense", name="Olíbano", planet="sun", element="fuego",
         aliases=["Incienso", "Frankincense"],
         properties={"intenciones": ["purificación", "elevación", "consagración"],
                     "notas": "Humo solar de consagración; eleva la vibración del rito."}),
    dict(slug="mirra", item_type="incense", name="Mirra", planet="saturn", element="agua",
         aliases=["Myrrh"],
         properties={"intenciones": ["duelo", "protección", "sellado"],
                     "notas": "Resina saturnina; sella, protege y honra a los muertos."}),
]


def main() -> None:
    db = SessionLocal()
    created = 0
    try:
        for data in ITEMS:
            exists = db.query(MateriaItem).filter(MateriaItem.slug == data["slug"]).first()
            if exists:
                continue
            db.add(MateriaItem(**data))
            created += 1
        db.commit()
        total = db.query(MateriaItem).count()
        print(f"Sembrados {created} ítems nuevos. Total en BD: {total}.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
