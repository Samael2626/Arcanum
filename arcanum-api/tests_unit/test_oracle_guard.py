# -*- coding: utf-8 -*-
"""El Oraculo tambien se comprueba, y hasta el 25-sep-2026 no se comprobaba.

`extra_checks` se le pasaba SOLO a la ruta del horoscopo, asi que una lectura de
tarot -- la ruta que se cobra -- no pasaba por ninguna guarda. Medido con una
tirada real: escribio "energia" tres veces, hablo de "el consultante" y cerro
con un ritual de siete pasos con verso en latin y un juramento enterrado bajo
una raiz de roble. Nada lo paro.
"""
from app.services import oracle_guard as og

# El contexto del Oraculo, tal como lo arma `oracle_context`: los planetas van
# en INGLES, y de ahi la decision de NO heredar `materia_prestada`.
DATOS = (
    "CONTEXTO ASTRAL DEL CONSULTANTE\n"
    "Planetas natales: sun en Tauro (casa 4); moon en Libra (casa 9).\n"
    "TIRADA DE TAROT DEL CONSULTANTE (spread: three_card)\n"
    "- Pasado: Senor de la Prudencia (derecha) [elemento tierra - palo oros]"
)


def test_el_consultante_no_se_escribe():
    """Convierte una pregunta en primera persona en un informe sobre un tercero."""
    for frase in ("la identidad del consultante se ha templado",
                  "las cartas hablan al consultante de su trabajo",
                  "el miedo de la consultante ante la oferta"):
        assert og.tercera_persona(frase), frase
        assert any("hablarle a ella" in d for d in og.defectos(frase, DATOS))


def test_hablar_de_tu_pasa():
    for frase in ("ese patron ha dejado en tu pecho la sensacion de haber agotado",
                  "el miedo que sientes ante la oferta es el eco de la copa"):
        assert og.tercera_persona(frase) == [], frase


def test_el_destino_no_se_escribe():
    """La tradicion lee fuerzas, no guiones."""
    for frase in ("la decision puede ser honrada dentro del plan mayor del destino",
                  "eso ya estaba escrito antes de que preguntaras",
                  "el universo conspira para que lo dejes"):
        assert og.destino_escrito(frase), frase
        assert any("guion ya decidido" in d for d in og.defectos(frase, DATOS))


def test_la_jerga_cabalistica_se_paga_o_no_entra():
    """Viene en la ficha de la carta, asi que el modelo la copia sin explicarla."""
    largo = ("Hod, que es el esplendor del trabajo que se perfecciona en la tierra "
             "mas analitica y se repite mil veces, sostiene el pasado")
    assert og.defectos(largo, DATOS), "la glosa larga de Hod tiene que caerse"
    corto = "Hod, que es el esplendor del trabajo repetido, sostiene el pasado"
    from app.services import horoscope_guard as hg
    assert hg.glosas_de_manual(corto, og.GLOSABLES_ORACULO) == [], \
        "el pago barato es lo que el prompt pide: no puede marcarse"


def test_el_oraculo_hereda_las_guardas_que_comparte():
    """Promesa de resultado y asesoria real valen igual aqui."""
    assert any("resultado cerrado" in d
               for d in og.defectos("conseguiras ese puesto", DATOS))
    assert any("consejo real" in d
               for d in og.defectos("vende esas acciones antes del viernes", DATOS))


def test_el_oraculo_NO_hereda_la_materia_prestada():
    """El contexto nombra los planetas en ingles: heredarla marcaria todo.

    "sun en Tauro" no contiene "el Sol", asi que el romero solar -- que es
    correcto -- se marcaria como materia de un cuerpo ausente, y cada lectura
    se llevaria un reintento entero por nada.
    """
    assert og.defectos("un ramo de romero junto a la vela", DATOS) == []


def test_el_prompt_del_oraculo_va_a_juego_con_el_guard():
    """Si el catalogo no esta montado no se puede afirmar nada: se salta."""
    import pytest
    from app.core.config import settings
    from app.core.content import ContentError, load_text
    try:
        voz = settings.ORACLE_SYSTEM_PROMPT or load_text(settings.ORACLE_PROMPT_PATH)
    except ContentError:
        pytest.skip("catalogo no montado; define ARCANUM_DATA_DIR")
    assert "LE RESPONDES A QUIEN PREGUNTA" in voz
    assert "UN SOLO GESTO" in voz
    assert "NADA DE DESTINO" in voz
    assert "no a \"el consultante\"" in voz


def test_el_oraculo_recibe_de_verdad_los_checks():
    """La linea que falto meses: sin ella todo lo de arriba es decorativo."""
    import inspect
    from app.services import claude_service as cs
    fuente = inspect.getsource(cs.generate_reading)
    assert "extra_checks=checks" in fuente
    assert "og.defectos" in fuente


# ── El limite que nace de haber abierto el imperativo ────────────────────────
# Salio en la PRIMERA tirada medida despues de abrirlo, y ninguna guarda lo
# cazaba: decidia la decision consultada, prometia como acaba, y encima sobre el
# sueldo. Las tres cosas en la misma frase.

DECISION_TOMADA = (
    "la senal indica que debes dejar atras la comodidad del empleo actual y "
    "aceptar la propuesta de menor paga, pues esa renuncia sera la llave que "
    "abre la puerta al aprendizaje que buscas"
)


def test_no_se_decide_la_decision_consultada():
    assert og.decide_por_ti(DECISION_TOMADA) == ["debes dejar"]
    assert any("decidiste por ella" in d for d in og.defectos(DECISION_TOMADA, DATOS))


def test_la_promesa_vestida_de_imagen_tambien_se_cae():
    """"sera la llave que abre la puerta" es "conseguiras" dicho mas bonito."""
    assert og.promesa_velada(DECISION_TOMADA) == ["sera la llave"]
    assert any("con una imagen" in d for d in og.defectos(DECISION_TOMADA, DATOS))


def test_el_imperativo_del_ritmo_sigue_permitido():
    """Lo que se abrio a proposito no puede caerse con lo que se acaba de cerrar."""
    for frase in ("no contestes hoy y deja madurar esa oferta una semana",
                  "habla con quien dejaste a medias antes de que se enfrie",
                  "duerme antes de responder ese correo",
                  "estas soltando algo que ya cumplio, y todavia no te lo crees"):
        assert og.decide_por_ti(frase) == [], frase
        assert og.promesa_velada(frase) == [], frase
        assert og.defectos(frase, DATOS) == [], frase
