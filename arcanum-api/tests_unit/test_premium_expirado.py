"""Premium caducado deja de ser premium.

EL AGUJERO QUE CIERRA ESTO

`subscription_tier` se ponia a "premium" al comprar y solo volvia a "free"
cuando llegaba el EXPIRATION del webhook. La fecha de vencimiento SI se
guardaba, se cargaba en `UserEntity` y viajaba hasta los cinco sitios que
deciden limites -- y ninguno la miraba.

O sea: si el EXPIRATION se perdia (webhook caido, 5xx agotando los
reintentos, un usuario que RevenueCat no supo asociar), ese usuario quedaba
premium PARA SIEMPRE.

Hoy es un caso raro. Con una prueba gratuita deja de serlo: la mayoria de los
trials no convierten, asi que el camino de expiracion pasa a ser el
mayoritario y el agujero se vuelve la norma.
"""
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.domain.entities import UserEntity


def _usuario(tier="premium", vence=None):
    return UserEntity(
        id=uuid4(),
        email="p@arcanum.test",
        hashed_password="x",
        subscription_tier=tier,
        subscription_expires_at=vence,
    )


AHORA = datetime.now(timezone.utc)


class TestLoQueDecide:
    def test_premium_vigente_es_premium(self):
        assert _usuario(vence=AHORA + timedelta(days=30)).is_premium

    def test_premium_caducado_ayer_NO_es_premium(self):
        # El caso que costaba dinero: tier premium, fecha pasada, y hasta hoy
        # se le daban los 50 tarots y las 20 lecturas diarias igual.
        assert not _usuario(vence=AHORA - timedelta(days=1)).is_premium

    def test_premium_caducado_por_un_segundo_tampoco(self):
        assert not _usuario(vence=AHORA - timedelta(seconds=1)).is_premium

    def test_free_nunca_es_premium_aunque_traiga_fecha_futura(self):
        # Si el tier dice free, la fecha no lo resucita.
        assert not _usuario(tier="free", vence=AHORA + timedelta(days=30)).is_premium

    def test_free_sin_fecha(self):
        assert not _usuario(tier="free").is_premium


class TestFechaNula:
    """Decision (a): sin fecha se SIGUE siendo premium, y se registra.

    Hoy no hay producto de por vida -- solo mensual y anual --, asi que una
    fecha vacia es siempre una anomalia nuestra. Ante una anomalia no se le
    corta el acceso a quien pago: hay usuarios en la base de antes de que el
    webhook guardara la fecha, y cerrar aqui les quitaria el plan de golpe.
    """

    def test_premium_sin_fecha_sigue_siendo_premium(self):
        assert _usuario(vence=None).is_premium

    def test_y_queda_marcado_como_anomalia(self):
        assert _usuario(vence=None).premium_sin_fecha

    def test_un_premium_con_fecha_no_es_anomalia(self):
        assert not _usuario(vence=AHORA + timedelta(days=1)).premium_sin_fecha

    def test_un_free_sin_fecha_tampoco_es_anomalia(self):
        assert not _usuario(tier="free").premium_sin_fecha


class TestFechaNaive:
    """Una fecha sin tzinfo no puede tumbar la autorizacion.

    La columna es TIMESTAMP WITH TIME ZONE y Postgres devuelve aware, pero un
    fixture o un test puede construirla naive. Comparar naive con aware lanza
    TypeError, y aqui eso no seria un fallo de borde: reventaria TODAS las
    rutas de pago a la vez.
    """

    def test_naive_futura_no_revienta_y_es_premium(self):
        naive = datetime.now() + timedelta(days=10)
        assert naive.tzinfo is None
        assert _usuario(vence=naive).is_premium

    def test_naive_pasada_no_revienta_y_no_es_premium(self):
        naive = datetime.now() - timedelta(days=10)
        assert not _usuario(vence=naive).is_premium


def test_los_cinco_sitios_usan_la_propiedad():
    """Nadie vuelve a decidir premium mirando solo el tier.

    Si alguien anade una ruta de pago nueva comparando
    `subscription_tier == "premium"` a mano, vuelve el agujero sin que nada
    avise. Este test recorre el codigo y lo impide.
    """
    import pathlib

    raiz = pathlib.Path(__file__).resolve().parents[1] / "app"
    culpables = []
    for f in raiz.rglob("*.py"):
        # La propiedad ES la definicion: ahi la comparacion es legitima.
        if f.name == "entities.py":
            continue
        for n, linea in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if 'subscription_tier == "premium"' in linea:
                culpables.append(f"{f.relative_to(raiz)}:{n}")
    assert not culpables, (
        "Estos sitios deciden premium sin mirar la fecha de vencimiento. "
        "Usa `user.is_premium`: " + ", ".join(culpables)
    )
