"""Lo que el prompt del Oraculo pide y el modelo incumple igual.

Hermano de `horoscope_guard`, y nacido de un agujero medido el 25-sep-2026: el
horoscopo pasaba por siete comprobaciones deterministas y el Oraculo por
NINGUNA. `extra_checks` se le daba solo a la ruta del horoscopo
(`claude_service._generate_with_coverage`), asi que una lectura de tarot podia
escribir "energia" tres veces, hablar de "el consultante" y cerrar con un
ritual de siete pasos sin que nada lo parase. Y es la ruta que se cobra.

NO SE REUSA `horoscope_guard.defectos` TAL CUAL, y la razon es una:
`materia_prestada` compara la materia contra el bloque de datos, y el contexto
astral del Oraculo nombra los planetas en INGLES ("sun en Tauro"). Con esa
comprobacion puesta, cada romero de Sol y cada rosa de Venus se marcaria como
materia de un cuerpo ausente, y cada lectura se llevaria un reintento entero
por nada. Lo demas si se reusa, porque las reglas son las mismas reglas.

LO QUE SI ES SUYO:
- la jerga cabalistica, que el horoscopo no ve nunca (Hod, Chokmah, decanato);
- "el consultante", que convierte una pregunta en primera persona en un
  expediente sobre un tercero;
- el destino escrito, que la tradicion no lee: lee fuerzas, no guiones.
"""
from __future__ import annotations

import re

from app.services import horoscope_guard as hg

# La jerga del Oraculo. Las sephiroth y el decanato vienen en las
# correspondencias de cada carta, asi que el modelo las tiene delante y las
# copia sin pagarlas: "Hod (esplendor) en la tierra mas analitica" es el
# catalogo, no una lectura.
GLOSABLES_ORACULO: tuple[str, ...] = hg._GLOSABLES + (
    "kether", "chokmah", "binah", "chesed", "geburah", "tiphareth",
    "netzach", "hod", "yesod", "malkuth", "sephirah", "sefirah",
    "decanato", "letra hebrea", "sympatheia", "synthemata",
)

# "el consultante" en todas sus formas. Es la marca del informe sobre un
# tercero, y lo que Samuel pidio arreglar primero: la pregunta viene en primera
# persona y la respuesta la mira desde fuera.
_TERCERA_PERSONA = re.compile(
    r"\b(?:el|la|del|de la|al|a la)\s+consultante\b"
)

# El destino como guion escrito. La lectura simbolica dice que fuerzas hay, no
# que esta decidido: "lo que el destino senala" es justo la frase que convierte
# un oraculo en una prediccion.
_DESTINO = re.compile(
    r"\b(?:"
    r"el destino\b|del destino\b|tu destino\b"
    r"|el plan mayor|esta escrito\b|estaba escrito\b"
    r"|el universo (?:conspira|quiere|te)"
    r")"
)


# DECIDIR POR ELLA. Este es el limite que nace de haber abierto el imperativo,
# y salio en la primera tirada medida despues de abrirlo: "debes dejar atras la
# comodidad del empleo actual y aceptar la propuesta de menor paga, pues esa
# renuncia sera la llave que abre la puerta al aprendizaje que buscas".
#
# Tres cosas a la vez, y ninguna la cazaba nada: decide la decision que vino a
# consultar, promete como acaba, y ademas lo hace sobre el sueldo. El imperativo
# permitido es "habla antes de que se enfrie" o "no contestes hoy" -- el ritmo,
# lo que dice y lo que calla --, nunca el desenlace que estaba sobre la mesa.
_DECIDE_POR_TI = re.compile(
    r"\b(?:debes|tienes que|deberias|lo que tienes que hacer es|"
    r"la decision correcta es|lo correcto es|te conviene)\s+"
    r"(?:\w+\s+){0,3}?"
    r"(?:aceptar|rechazar|renunciar|dejar|abandonar|quedarte|irte|marcharte|"
    r"cambiar de trabajo|coger|tomar ese|elegir)\b"
)

# La promesa vestida de imagen. "conseguiras" ya estaba vetada en claro; esto es
# la misma apuesta dicha con una llave y una puerta, y colaba entera.
_PROMESA_VELADA = re.compile(
    r"\b(?:sera la llave|abrira? la puerta|te llevara a|"
    r"garantiza|asegura el|acabara bien|saldra bien)\b"
)


def decide_por_ti(texto: str) -> list[str]:
    """La decision que vino a consultar, tomada por el Oraculo."""
    return sorted({m.group(0) for m in _DECIDE_POR_TI.finditer(hg._plano(texto))})


def promesa_velada(texto: str) -> list[str]:
    """El desenlace prometido con una imagen en vez de con un verbo."""
    return sorted({m.group(0) for m in _PROMESA_VELADA.finditer(hg._plano(texto))})


def tercera_persona(texto: str) -> list[str]:
    """"el consultante" y sus variantes: el informe en vez de la respuesta."""
    return sorted({m.group(0) for m in _TERCERA_PERSONA.finditer(hg._plano(texto))})


def destino_escrito(texto: str) -> list[str]:
    """El futuro como guion ya decidido."""
    return sorted({m.group(0) for m in _DESTINO.finditer(hg._plano(texto))})


def defectos(texto: str, datos: str) -> list[str]:
    """Todo lo que hay que rehacer, en frases que puedan ir en el aviso.

    Mismo contrato que `horoscope_guard.defectos`: lista vacia cuando el texto
    esta bien, y cada entrada es una instruccion que el reintento puede seguir.
    """
    partes: list[str] = []

    promesas = hg.promesas_de_resultado(texto)
    if promesas:
        partes.append(
            "prometiste un resultado cerrado (" + ", ".join(promesas) + "). "
            "Puedes decir que esta soltando, que roza y que tiene delante para "
            "decidir; como acaba no lo sabes. Esa frase no se reescribe con "
            "otra palabra: se cae")

    asesoria = hg.asesoria_real(texto)
    if asesoria:
        partes.append(
            "cruzaste a consejo real (" + "; ".join(asesoria) + "). Puedes "
            "decirle que haga, pero en el registro simbolico y cotidiano. Una "
            "decision de dinero, de salud o de derecho no se manda nunca: di "
            "el terreno sin dar la instruccion")

    decide = decide_por_ti(texto)
    if decide:
        partes.append(
            "decidiste por ella (" + ", ".join(f'"{d}"' for d in decide)
            + "). Justo la decision que vino a consultar es la que NO tomas: "
              "puedes decirle que haga en el ritmo del dia -- que hable, que "
              "espere, que no conteste hoy --, no que acepte o rechace lo que "
              "trajo. Di que esta soltando y que pide el simbolo; elegir es suyo")

    velada = promesa_velada(texto)
    if velada:
        partes.append(
            "prometiste el desenlace con una imagen (" + ", ".join(velada)
            + "). Una llave que abre una puerta es la misma apuesta que "
              "\"conseguiras\", dicha mas bonito, y se comprueba manana igual")

    ajena = tercera_persona(texto)
    if ajena:
        partes.append(
            "hablaste de " + ", ".join(f'"{a}"' for a in ajena) + " en vez de "
            "hablarle a ella. Le respondes DE TU: quien pregunta esta delante, "
            "no es el asunto de un informe")

    guion = destino_escrito(texto)
    if guion:
        partes.append(
            "escribiste el futuro como un guion ya decidido ("
            + ", ".join(guion) + "). La tradicion lee fuerzas, no guiones: di "
            "que empuja y que pide, no que esta escrito")

    vetadas = hg.palabras_vetadas(texto)
    if vetadas:
        partes.append(
            "usaste vocabulario prohibido (" + ", ".join(vetadas) + "). No es "
            "cuestion de cambiar la palabra: la idea que solo sale con ella es "
            "de revista y se cae entera. Para el animo tienes las palabras del "
            "taller y del cuerpo -- la tension, el roce, el filo, lo que "
            "aprieta")

    gremio = hg.formulas_de_gremio(texto)
    if gremio:
        partes.append(
            "usaste formulas de oficio sin explicarlas (" + ", ".join(gremio)
            + "). En la MISMA frase tiene que ir su razon, en palabras "
              "corrientes")

    glosas = hg.glosas_de_manual(texto, GLOSABLES_ORACULO)
    if glosas:
        partes.append(
            "colgaste la definicion entera del nombre (" + ", ".join(glosas)
            + "). El termino se paga en media frase y con tus palabras; el "
              "sentido se dice ACTUANDO, con las cartas y los cuerpos de sujeto")

    geometria = hg.geometria_escrita(texto)
    if geometria:
        partes.append(
            "escribiste la geometria del calculo (" + ", ".join(geometria)
            + "). Di lo que sale de ahi, no de donde sale")

    copiadas = hg.frases_copiadas(texto, datos)
    if copiadas:
        muestra = "; ".join(f'"{c[:60]}..."' for c in copiadas[:2])
        partes.append(
            f"copiaste literal del contexto o de la ficha de la carta "
            f"({muestra}). Eso es lo que hay que SABER; como se dice lo pones tu")

    return partes


def aviso(faltantes: list[str], defectos_hallados: list[str],
          obligatorios: list[str] | None = None) -> str:
    """El unico aviso del unico reintento: cobertura y defectos juntos.

    Mismo criterio que `horoscope_guard.aviso`, con la forma del Oraculo -- que
    no son dos parrafos y un cierre, sino la tirada por posicion --, y con la
    misma leccion medida: los obligatorios se recuerdan SIEMPRE, tambien cuando
    no faltaba ninguno, porque al reescribir entero se pierde lo que no se
    vuelve a pedir.
    """
    lineas = ["Tu version anterior tiene que rehacerse. Problemas:"]
    if faltantes:
        lineas.append(
            "- no nombraste: " + "; ".join(faltantes) + ". Una posicion sin "
            "interpretar deja la tirada a medias")
    lineas += [f"- {d}" for d in defectos_hallados]
    lineas.append(
        "Reescribe la lectura ENTERA corrigiendo todo lo anterior. Manten la "
        "forma segun el tamano de la tirada, hablale DE TU, di en palabras "
        "corrientes que esta soltando o superando, y cierra con UN SOLO gesto "
        "que quepa en una frase.")
    if obligatorios:
        lineas.append(
            "Y NO PIERDAS lo que ya estaba bien: la lectura nueva tiene que "
            "seguir cubriendo " + "; ".join(obligatorios) + ".")
    return chr(10).join(lineas)
