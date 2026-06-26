"""Siembra Materia Arcana con correspondencias tradicionales (idempotente por slug).

Uso: cd arcanum-api && venv\\Scripts\\python.exe scripts/seed_materia.py

Datos particionados en scripts/materia_data/ para mantenibilidad:
  - hierbas.py         — 25 hierbas nuevas
  - piedras.py         — 20 piedras/gemas nuevas
  - metales_inciensos.py — 4 metales + 10 inciensos nuevos
  - planetas_angeles.py  — 7 planetas + 7 ángeles + 12 signos
  - aceites_resinas.py   — 13 aceites y resinas
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db.session import SessionLocal  # noqa: E402
from app.models.materia_item import MateriaItem  # noqa: E402
from scripts.materia_data import (  # noqa: E402
    HIERBAS, PIEDRAS, METALES, INCIENSOS, PLANETAS, ANGELES, SIGNOS, ACEITES_RESINAS,
)

# ── Ítems originales (15) — intactos ─────────────────────────────────────────
_ORIGINALES: list[dict] = [
    # ── Hierbas ──────────────────────────────────────────────────────────────
    dict(slug="romero", item_type="herb", name="Romero", planet="sun", element="fuego",
         aliases=["Rosemary"],
         properties={"intenciones": ["limpieza", "protección", "memoria"],
                     "notas": "Hierba solar de purificación; quema para despejar un espacio.",
                     "parte": "hojas", "toxicidad": "no",
                     "estudio": "Rosmarinus officinalis (ahora Salvia rosmarinus) fue descrito por Dioscórides (III.75) como planta calorífica y para el útero. Culpeper lo asigna al Sol bajo Aries. Su uso en purificación de espacios y memoria es de los más antiguos y documentados — los griegos quemaban romero como sustituto del incienso caro.",
                     "fuente": "Dioscórides, De Materia Medica III.75; Culpeper, Complete Herbal"}),
    dict(slug="lavanda", item_type="herb", name="Lavanda", planet="mercury", element="aire",
         aliases=["Lavender"],
         properties={"intenciones": ["calma", "sueño", "claridad mental"],
                     "notas": "Apacigua la mente; favorece el sueño y la adivinación serena.",
                     "parte": "flores", "toxicidad": "no",
                     "estudio": "Lavandula angustifolia fue usada por los romanos en los baños (de ahí 'lavare'). Dioscórides la menciona como planta de virtud calorífica suave. Culpeper la asigna a Mercurio. En magia: favorece la calma mental necesaria para el trabajo oracular.",
                     "fuente": "Culpeper, Complete Herbal; Dioscórides, De Materia Medica"}),
    dict(slug="rosa", item_type="herb", name="Rosa", planet="venus", element="agua",
         aliases=["Rose"],
         properties={"intenciones": ["amor", "belleza", "autoestima"],
                     "notas": "Flor de Venus por excelencia; abre el corazón.",
                     "parte": "pétalos", "toxicidad": "no",
                     "estudio": "Rosa gallica y Rosa damascena son las más usadas en magia y perfumería. Dioscórides (I.99) describe la rosa para uso médico (pétalos secos, agua de rosas). Culpeper la asigna a Venus. Agrippa (Lib. I) la incluye entre las plantas venusinas.",
                     "fuente": "Dioscórides, De Materia Medica I.99; Culpeper, Complete Herbal; Agrippa, Lib. I"}),
    dict(slug="canela", item_type="herb", name="Canela", planet="sun", element="fuego",
         aliases=["Cinnamon"],
         properties={"intenciones": ["prosperidad", "éxito", "poder"],
                     "notas": "Acelera y enciende cualquier intención; atrae dinero.",
                     "parte": "corteza", "toxicidad": "no",
                     "estudio": "Cinnamomum verum fue la especia más preciada del mundo antiguo. Dioscórides (I.13) la describe extensamente. Agrippa (Lib. I) la asigna al Sol. En el aceite sagrado del Templo (Éxodo 30:23) es uno de los cinco ingredientes.",
                     "fuente": "Dioscórides, De Materia Medica I.13; Agrippa, Lib. I; Éxodo 30:23"}),
    dict(slug="artemisa", item_type="herb", name="Artemisa", planet="moon", element="tierra",
         aliases=["Ajenjo silvestre", "Mugwort"],
         properties={"intenciones": ["adivinación", "sueños", "visiones"],
                     "notas": "Hierba lunar de la videncia; té o sahumerio antes del trabajo oracular.",
                     "parte": "hojas", "toxicidad": "leve — abortiva en dosis muy altas; evitar en embarazo",
                     "estudio": "Artemisia vulgaris fue dedicada a la diosa Ártemis/Diana, patrona de la Luna. Dioscórides (III.113) la usa para regular la menstruación y facilitar el parto. Culpeper la asigna a la Luna. El humo de artemisa es el sahumerio oracular más usado en la tradición europea.",
                     "fuente": "Dioscórides, De Materia Medica III.113; Culpeper, Complete Herbal"}),
    dict(slug="salvia", item_type="herb", name="Salvia", planet="jupiter", element="aire",
         aliases=["Sage"],
         properties={"intenciones": ["limpieza", "sabiduría", "longevidad"],
                     "notas": "Destierra lo denso y atrae consejo sabio.",
                     "parte": "hojas", "toxicidad": "no",
                     "estudio": "Salvia officinalis fue la panacea medieval europea: 'Cur moriatur homo cui Salvia crescit in horto?' (¿Por qué moriría un hombre en cuyo jardín crece la salvia?). Dioscórides (III.33) la usa como diurética y para llagas. Culpeper la asigna a Júpiter.",
                     "fuente": "Dioscórides, De Materia Medica III.33; Culpeper, Complete Herbal"}),
    # ── Piedras ──────────────────────────────────────────────────────────────
    dict(slug="cuarzo-claro", item_type="stone", name="Cuarzo Claro", planet=None, element=None,
         aliases=["Clear Quartz", "Cristal de roca"],
         properties={"intenciones": ["amplificación", "claridad", "sanación"],
                     "notas": "Cristal maestro; amplifica y dirige cualquier intención.",
                     "estudio": "El cristal de roca (SiO₂ puro) fue llamado 'krystallos' (hielo eterno) por los griegos que creían que era agua congelada permanentemente. Agrippa (Lib. I) lo lista como amplificador de virtudes. Su neutralidad elemental lo hace universal.",
                     "fuente": "Agrippa, Lib. I; Plinio, Historia Natural XXXVII"}),
    dict(slug="amatista", item_type="stone", name="Amatista", planet="jupiter", element="agua",
         aliases=["Amethyst"],
         properties={"intenciones": ["intuición", "paz", "sobriedad"],
                     "notas": "Eleva la mente; protege el sueño y la meditación.",
                     "estudio": "La amatista (SiO₂ con trazas de hierro y manganeso) fue la gema de los obispos medievales. Su nombre griego 'amethystos' significa 'no ebrio' — se creía que protegía contra la embriaguez. Agrippa (Lib. I) la asigna a Júpiter. Dioscórides (V.94) la menciona.",
                     "fuente": "Dioscórides, De Materia Medica V.94; Agrippa, Lib. I"}),
    dict(slug="obsidiana", item_type="stone", name="Obsidiana", planet="saturn", element="tierra",
         aliases=["Obsidian"],
         properties={"intenciones": ["protección", "destierro", "anclaje"],
                     "notas": "Espejo del inframundo; corta y absorbe lo negativo.",
                     "estudio": "El vidrio volcánico obsidiana fue el material de los espejos adivinatorios aztecas (tezcatl) y del famoso espejo de John Dee (British Museum). Agrippa (Lib. I) asigna las piedras negras a Saturno. Los aztecas la asociaban a Tezcatlipoca, dios del espejo humeante.",
                     "fuente": "Agrippa, Lib. I; arqueología mesoamericana; John Dee (British Museum)"}),
    dict(slug="cornalina", item_type="stone", name="Cornalina", planet="mars", element="fuego",
         aliases=["Carnelian"],
         properties={"intenciones": ["coraje", "vitalidad", "deseo"],
                     "notas": "Enciende la voluntad y la fuerza de acción.",
                     "estudio": "La cornalina (calcedonia roja-anaranjada con óxido de hierro) fue la piedra más usada en amuletos egipcios y mesopotámicos. Agrippa (Lib. I) la asigna a Marte por su color. El Profeta Mahoma llevaba un anillo de cornalina. En el Libro de los Muertos aparece en múltiples amuletos protectores.",
                     "fuente": "Agrippa, Lib. I; Libro de los Muertos (Papiro de Ani)"}),
    # ── Metales ──────────────────────────────────────────────────────────────
    dict(slug="oro", item_type="metal", name="Oro", planet="sun", element="fuego",
         aliases=["Gold"],
         properties={"intenciones": ["éxito", "vitalidad", "riqueza"],
                     "notas": "Metal del Sol; salud, poder e influencia.",
                     "estudio": "El oro (Au) es el metal del Sol en todas las tradiciones alquímicas. Agrippa (Lib. I, cap. XXVI) lo asigna al Sol: 'el oro imita al Sol en su color y brillo'. El símbolo ☉ del Sol es también el símbolo alquímico del oro. El oro no se oxida — como el Sol, es eterno e inalterable.",
                     "dia": "domingo", "angel_regente": "Miguel",
                     "fuente": "Agrippa, Lib. I cap. XXVI; tradición alquímica universal"}),
    dict(slug="plata", item_type="metal", name="Plata", planet="moon", element="agua",
         aliases=["Silver"],
         properties={"intenciones": ["psiquismo", "intuición", "sueños"],
                     "notas": "Metal de la Luna; receptividad y videncia.",
                     "estudio": "La plata (Ag) es el metal de la Luna. Agrippa (Lib. I, cap. XXVI): 'la plata pertenece a la Luna, receptiva y reflejante como el espejo lunar'. El espejo de plata es el instrumento adivinatorio lunar clásico. La plata mata a los hombres lobo en el folklore — su virtud lunar anula la maldición lunar de la transformación.",
                     "dia": "lunes", "angel_regente": "Gabriel",
                     "fuente": "Agrippa, Lib. I cap. XXVI; tradición alquímica"}),
    dict(slug="cobre", item_type="metal", name="Cobre", planet="venus", element="tierra",
         aliases=["Copper"],
         properties={"intenciones": ["amor", "sanación", "armonía"],
                     "notas": "Metal de Venus; conduce energía de afecto y belleza.",
                     "estudio": "El cobre (Cu) toma su nombre de Chipre (Kypros/Cyprus), isla sagrada de Afrodita. Agrippa (Lib. I, cap. XXVI) lo asigna a Venus. El cobre es el mejor conductor eléctrico después de la plata — en la tradición mágica 'conduce' la energía amorosa. El símbolo de Venus (♀) fue originalmente el símbolo alquímico del cobre.",
                     "dia": "viernes", "angel_regente": "Anael",
                     "fuente": "Agrippa, Lib. I cap. XXVI; etimología (Cyprus/Kypros)"}),
    # ── Inciensos ────────────────────────────────────────────────────────────
    dict(slug="olibano", item_type="incense", name="Olíbano", planet="sun", element="fuego",
         aliases=["Incienso", "Frankincense"],
         properties={"intenciones": ["purificación", "elevación", "consagración"],
                     "notas": "Humo solar de consagración; eleva la vibración del rito.",
                     "estudio": "Boswellia sacra y B. carterii producen el olíbano. Dioscórides (I.68) lo describe extensamente. Agrippa lo asigna al Sol. Es el incienso del Templo de Jerusalén, de la misa católica y de los rituales solares en todo el mundo antiguo. El ácido boswélico tiene propiedades antiinflamatorias validadas científicamente.",
                     "fuente": "Dioscórides, De Materia Medica I.68; Agrippa, Lib. I; Éxodo 30:34"}),
    dict(slug="mirra", item_type="incense", name="Mirra", planet="saturn", element="agua",
         aliases=["Myrrh"],
         properties={"intenciones": ["duelo", "protección", "sellado"],
                     "notas": "Resina saturnina; sella, protege y honra a los muertos.",
                     "estudio": "Commiphora myrrha fue el agente de embalsamamiento egipcio por excelencia. Dioscórides (I.64) la describe para heridas, úlceras y como antimicrobiano. Agrippa la asigna a Saturno. Es uno de los tres dones de los Reyes Magos — la mirra como símbolo de la mortalidad de Jesús. En magia sella y preserva, como preserva la carne embalsamada.",
                     "fuente": "Dioscórides, De Materia Medica I.64; Agrippa, Lib. I; Mateo 2:11"}),
]

# ── Lista maestra ─────────────────────────────────────────────────────────────
ITEMS: list[dict] = (
    _ORIGINALES
    + HIERBAS
    + PIEDRAS
    + METALES
    + INCIENSOS
    + PLANETAS
    + ANGELES
    + SIGNOS
    + ACEITES_RESINAS
)


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
