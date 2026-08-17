"""La residencia manda para el cielo de hoy; el nacimiento, para la carta natal.

Son dos lugares con dos usos que no se pueden confundir: meter la residencia en
la carta natal romperia el Ascendente de todo el que se haya mudado.
"""
from datetime import datetime, timezone
from types import SimpleNamespace

from app.services import horoscope as hs
from app.services import natal_chart_engine as nce
from app.services import user_sky as us

NOW = datetime(2026, 8, 17, 12, 0, tzinfo=timezone.utc)

BOGOTA = ("4.7110", "-74.0700")
MADRID = ("40.4168", "-3.7038")


def _user(birth=BOGOTA, current=(None, None), birth_tz="America/Bogota",
          current_tz=None):
    return SimpleNamespace(
        birth_lat=birth[0], birth_lon=birth[1], birth_timezone=birth_tz,
        current_lat=current[0], current_lon=current[1],
        current_timezone=current_tz,
    )


# ── El criterio de donde esta la persona ─────────────────────────────────────


def test_sin_residencia_se_usa_el_lugar_de_nacimiento():
    # Vacio significa "vivo donde naci": nadie tiene que rellenar nada para
    # seguir exactamente como antes.
    assert us.coords(_user()) == (4.7110, -74.0700)


def test_con_residencia_manda_la_residencia():
    assert us.coords(_user(current=MADRID)) == (40.4168, -3.7038)


def test_sin_ninguno_de_los_dos_no_se_inventa_una_ciudad():
    assert us.coords(_user(birth=(None, None))) is None


def test_una_residencia_a_medias_cae_al_nacimiento():
    # Latitud sin longitud no es un lugar. Antes de inventar el par, se usa el
    # de nacimiento, que si esta completo.
    assert us.coords(_user(current=("40.4168", None))) == (4.7110, -74.0700)


def test_una_residencia_corrupta_no_tumba_el_cielo():
    assert us.coords(_user(current=("no-es-un-numero", "tampoco"))) == (4.7110, -74.0700)


def test_un_usuario_sin_el_atributo_de_nacimiento_es_un_bug_y_revienta():
    # Ausencia de lugar y error de programa no son lo mismo. Silenciar esto
    # esconderia el fallo real.
    try:
        us.coords(SimpleNamespace())
    except AttributeError:
        return
    raise AssertionError("deberia levantar AttributeError")


# ── La zona horaria sigue la misma regla ─────────────────────────────────────


def test_la_zona_horaria_prefiere_la_residencia():
    assert us.timezone_name(_user(current_tz="Europe/Madrid")) == "Europe/Madrid"


def test_sin_residencia_la_zona_es_la_de_nacimiento():
    assert us.timezone_name(_user()) == "America/Bogota"


def test_el_dia_del_horoscopo_cambia_donde_vives():
    # 02:00 UTC del 18 son las 21:00 del 17 en Bogota, pero ya las 04:00 del 18
    # en Madrid. Quien se mudo debe recibir el corte de dia de donde vive.
    en_utc = datetime(2026, 8, 18, 2, 0, tzinfo=timezone.utc)
    solo_nacio = _user()
    se_mudo = _user(current=MADRID, current_tz="Europe/Madrid")

    assert hs.local_date(us.timezone_name(solo_nacio), en_utc).isoformat() == "2026-08-17"
    assert hs.local_date(us.timezone_name(se_mudo), en_utc).isoformat() == "2026-08-18"


# ── Lo que la residencia NO puede tocar ──────────────────────────────────────


def test_la_carta_natal_no_cambia_al_declarar_residencia():
    """El test que fija el limite: la carta se calcula donde naciste.

    Si la residencia se colara en `_birth_data`, el Ascendente y las casas de
    todo el que se haya mudado cambiarian de golpe. Seria peor que el bug que
    esto viene a arreglar.
    """
    from app.routers import astral

    nacimiento = datetime(1990, 5, 1, 12, 0, tzinfo=timezone.utc)
    base = dict(
        birth_date=nacimiento, birth_time=nacimiento,
        birth_lat=BOGOTA[0], birth_lon=BOGOTA[1], birth_timezone="America/Bogota",
    )
    quieto = SimpleNamespace(**base, current_lat=None, current_lon=None,
                             current_timezone=None)
    mudado = SimpleNamespace(**base, current_lat=MADRID[0], current_lon=MADRID[1],
                             current_timezone="Europe/Madrid")

    a = nce.compute_natal_chart(astral._birth_data(quieto, "placidus"))
    b = nce.compute_natal_chart(astral._birth_data(mudado, "placidus"))

    assert a["ascendant"] == b["ascendant"]
    assert a["houses"] == b["houses"]
    assert a["planets"] == b["planets"]


def test_mudarse_si_cambia_la_hora_planetaria():
    # La contraparte del test anterior: lo que SI debe moverse, se mueve.
    quieto = us.planetary_hour(_user(), NOW)
    mudado = us.planetary_hour(_user(current=MADRID), NOW)
    assert quieto is not None and mudado is not None
    assert quieto != mudado
