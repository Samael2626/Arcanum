"""Tests unitarios PUROS de la sesion de sorteo de la mesa de tarot — sin BD.

Ejecutar desde arcanum-api/ con:
    .venv/Scripts/python.exe -m pytest tests_unit/test_tarot_session_pure.py -q

La invariante que importa por encima de todo: ninguna operacion pierde ni duplica
cartas. Se comprueba en cada caso y en secuencias aleatorias largas.
"""
import random
from collections import Counter

import pytest

from app.domain.decks import get_deck, list_decks
from app.domain.tarot_session import SessionError, TarotSession

RWS = [f"carta-{i:02d}" for i in range(78)]
MAYORES = [f"mayor-{i:02d}" for i in range(22)]


def _open(cards=RWS, deck="rws"):
    return TarotSession.open(get_deck(deck), cards)


def _todas(s: TarotSession) -> Counter:
    """Cartas en montones + sacadas: siempre deberia ser el mazo exacto."""
    c = Counter(s.drawn)
    for pid in s.piles:
        c.update(s.live(pid))
    return c


# ---------- mazos ----------
def test_mazos_disponibles():
    assert {d.slug for d in list_decks()} == {"rws", "mayores"}
    assert get_deck("mayores").includes("major") and not get_deck("mayores").includes("minor")
    assert get_deck("rws").includes("major") and get_deck("rws").includes("minor")
    assert get_deck("no-existe") is None


def test_abrir_rechaza_mazo_vacio_o_repetido():
    with pytest.raises(SessionError):
        _open([])
    with pytest.raises(SessionError):
        _open(["a", "a", "b"])


def test_abrir_deja_orden_de_fabrica_y_sin_invertidas():
    s = _open()
    assert s.live("p0") == RWS and s.total() == 78 and s.state == "sin barajar"
    slug, rev = s.take("p0", 0)
    assert slug == RWS[0] and rev is False   # sin barajar no hay invertidas


# ---------- barajar ----------
def test_barajar_conserva_las_cartas_y_cambia_el_orden():
    s = _open()
    s.shuffle("p0", random.Random(7))
    assert Counter(s.live("p0")) == Counter(RWS)
    assert s.live("p0") != RWS
    assert s.state.startswith("barajado")


def test_barajar_decide_invertidas_solo_si_el_mazo_las_admite():
    s = _open()
    s.shuffle("p0", random.Random(3))
    assert any(s.reversed_.values()) and not all(s.reversed_.values())
    s2 = _open()
    s2.allow_reversed = False
    s2.shuffle("p0", random.Random(3))
    assert not any(s2.reversed_.values())


def test_barajar_por_defecto_usa_azar_criptografico():
    a, b = _open(), _open()
    a.shuffle("p0"); b.shuffle("p0")
    assert a.live("p0") != b.live("p0")   # 78! ordenes: coincidir es imposible en la practica


# ---------- cortar y unir ----------
def test_cortar_crea_monton_con_las_de_arriba():
    s = _open()
    new = s.cut("p0", 30)
    assert s.live(new) == RWS[:30] and s.live("p0") == RWS[30:]
    assert _todas(s) == Counter(RWS)


@pytest.mark.parametrize("n", [0, 78, -1, 100])
def test_corte_imposible(n):
    with pytest.raises(SessionError):
        _open().cut("p0", n)


def test_corte_clasico_lo_de_abajo_pasa_arriba():
    s = _open()
    top = s.cut("p0", 30)
    s.merge(["p0", top], "p0")
    assert s.live("p0") == RWS[30:] + RWS[:30]
    assert list(s.piles) == ["p0"]


def test_unir_devolviendo_arriba_lo_de_arriba_deshace_el_corte():
    s = _open()
    top = s.cut("p0", 30)
    s.merge([top, "p0"], "p0")
    assert s.live("p0") == RWS


def test_unir_valida_montones():
    s = _open()
    top = s.cut("p0", 10)
    with pytest.raises(SessionError):
        s.merge(["p0"], "p0")
    with pytest.raises(SessionError):
        s.merge(["p0", "p0"], "p0")
    with pytest.raises(SessionError):
        s.merge(["p0", top], "p9")
    with pytest.raises(SessionError):
        s.merge(["p0", "p9"], "p0")


# ---------- sacar, devolver, recoger ----------
def test_sacar_por_posicion_es_estable_con_el_abanico_abierto():
    s = _open()
    s.shuffle("p0", random.Random(1))
    fila = list(s.piles["p0"])
    posiciones = [40, 3, 77, 12]
    sacadas = [s.take("p0", p)[0] for p in posiciones]
    assert sacadas == [fila[p] for p in posiciones]   # sacar una no mueve a las demas
    assert s.count("p0") == 74 and s.top("p0") == 0


def test_no_se_saca_dos_veces_la_misma_posicion():
    s = _open()
    s.take("p0", 5)
    with pytest.raises(SessionError):
        s.take("p0", 5)
    with pytest.raises(SessionError):
        s.take("p0", 78)
    with pytest.raises(SessionError):
        s.take("p7", 0)


def test_devolver_va_al_fondo_y_recoger_devuelve_todo():
    s = _open()
    a, _ = s.take("p0", 0)
    b, _ = s.take("p0", 1)
    s.give_back(a, "p0")
    assert s.live("p0")[-1] == a and s.drawn == [b]
    with pytest.raises(SessionError):
        s.give_back(a, "p0")   # ya no esta fuera
    s.gather("p0")
    assert s.drawn == [] and s.count("p0") == 78 and _todas(s) == Counter(RWS)


def test_mazo_de_mayores_solo_tiene_mayores():
    s = _open(MAYORES, "mayores")
    s.shuffle("p0", random.Random(2))
    sacadas = {s.take("p0", p)[0] for p in range(22)}
    assert sacadas == set(MAYORES)


# ---------- lo que ve el cliente ----------
def test_la_vista_publica_no_revela_el_orden():
    s = _open()
    s.shuffle("p0", random.Random(5))
    s.take("p0", 2)
    v = s.public_view()
    texto = repr(v)
    assert v["total"] == 77 and v["piles"]["p0"]["count"] == 77
    assert 2 not in v["piles"]["p0"]["positions"]
    ocultas = [c for c in RWS if c not in s.drawn]
    assert not any(c in texto for c in ocultas)   # ninguna carta del mazo aparece
    assert v["drawn"][0]["slug"] == s.drawn[0]


def test_persistencia_ida_y_vuelta():
    s = _open()
    s.shuffle("p0", random.Random(11))
    top = s.cut("p0", 20)
    s.take(top, 4)
    r = TarotSession.from_dict(s.to_dict())
    assert r.to_dict() == s.to_dict()
    r.take("p0", 0)
    assert s.count("p0") == 58   # la copia no comparte listas con el original


# ---------- invariante bajo operaciones aleatorias ----------
@pytest.mark.parametrize("seed", range(200))
def test_ninguna_secuencia_pierde_ni_duplica_cartas(seed):
    rng = random.Random(seed)
    cards = MAYORES if seed % 3 == 0 else RWS
    s = _open(cards, "mayores" if seed % 3 == 0 else "rws")
    for _ in range(40):
        op = rng.choice(["shuffle", "cut", "merge", "take", "give_back", "gather"])
        pid = rng.choice(list(s.piles))
        try:
            if op == "shuffle":
                s.shuffle(pid, rng)
            elif op == "cut" and s.count(pid) > 1:
                s.cut(pid, rng.randint(1, s.count(pid) - 1))
            elif op == "merge" and len(s.piles) > 1:
                ids = rng.sample(list(s.piles), rng.randint(2, len(s.piles)))
                s.merge(ids, rng.choice(ids))
            elif op == "take" and s.count(pid):
                s.take(pid, rng.choice([i for i, c in enumerate(s.piles[pid]) if c is not None]))
            elif op == "give_back" and s.drawn:
                s.give_back(rng.choice(s.drawn), pid)
            elif op == "gather":
                s.gather(pid)
        except SessionError:
            pass
        assert _todas(s) == Counter(cards)
        assert s.total() + len(s.drawn) == len(cards)
