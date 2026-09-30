"""Las siembras del arranque piden la sesion en el momento, no al importarse.

Regresion: importaban `SessionLocal`, que vale None hasta que alguien crea la
fabrica, asi que `main()` reventaba con TypeError. Como `run_seeds` es no fatal
por diseno, el arranque lo tragaba y ninguna base nueva recibia cartas ni materia.
"""
import importlib

import pytest


class _Sentinel(Exception):
    pass


@pytest.mark.parametrize("module", ["scripts.seed_tarot", "scripts.seed_materia"])
def test_la_siembra_pide_la_fabrica_de_sesiones_al_ejecutarse(module, monkeypatch):
    seed = importlib.import_module(module)

    def factory():
        raise _Sentinel

    monkeypatch.setattr(seed, "get_session_factory", factory)
    with pytest.raises(_Sentinel):
        seed.main()
