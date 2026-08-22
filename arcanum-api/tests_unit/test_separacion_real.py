"""La separacion real entre los dos cuerpos, no la nominal del aspecto.

La rueda del cielo sellado coloca los dos cuerpos a su distancia REAL sobre el
circulo. Con `orb` solo no se puede: es `abs(sep - angle)` y pierde el signo, o
sea que un trigono con orbe 0.7 puede estar a 119.3 o a 120.7 grados y el dibujo
saldria en el sitio equivocado la mitad de las veces.

Dibujar un triangulo perfecto cuando el angulo real no lo es seria justo lo que
esta app no puede permitirse: fingir precision que no tiene.
"""
from datetime import datetime, timezone

from app.services import natal_chart_engine as nce


def _transitos():
    carta = nce.compute_natal_chart(nce.BirthData(
        datetime(1990, 3, 15, 13, 30, tzinfo=timezone.utc), 4.711, -74.072))
    return nce.compute_transits(
        nce.natal_targets(carta), datetime.now(timezone.utc))["aspects_to_natal"]


def test_cada_aspecto_trae_su_separacion_real():
    aspectos = _transitos()
    assert aspectos, "la carta de prueba deberia tener algun aspecto"
    for a in aspectos:
        assert "separation" in a, f"falta separation en {a['transit']}-{a['natal']}"
        assert 0 <= a["separation"] <= 180


def test_la_separacion_concuerda_con_el_orbe():
    """orb es la distancia a la exactitud: |separacion - angulo|."""
    for a in _transitos():
        assert abs(abs(a["separation"] - a["angle"]) - a["orb"]) < 0.02, a


def test_la_separacion_no_es_siempre_el_angulo_nominal():
    """Si lo fuera, no aportaria nada y la rueda podria usar `angle` a secas."""
    aspectos = _transitos()
    distintas = [a for a in aspectos if abs(a["separation"] - a["angle"]) > 0.05]
    assert distintas, "ningun aspecto se aparta de su angulo nominal: sospechoso"
