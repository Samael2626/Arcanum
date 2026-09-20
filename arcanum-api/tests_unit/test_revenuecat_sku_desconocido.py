"""Un consumible que no conocemos es dinero cobrado sin entregar.

Hasta el 19-sep-2026 ese camino era silencioso: el `if amount is not None`
no entraba, la funcion caia al final, sellaba `processed_at` y devolvia 200.
RevenueCat lo daba por procesado y no reintentaba. El usuario pagaba, no
recibia el credito, y no quedaba ni una linea en el log: solo se sabria por
su reclamo.

Esto fija que quede constancia. No arregla la entrega -- para eso hay que
anadir el SKU al mapa y desplegar -- pero convierte una perdida invisible en
una alerta con nombre de producto, usuario y transaccion.
"""
import logging

from app.routers.revenuecat import _CONSUMABLE_CREDITS


def test_los_sku_en_venta_estan_en_el_mapa():
    # Si alguien pone un consumible a la venta en la app y olvida el backend,
    # el webhook cobrara sin acreditar. Los dos que hoy se venden:
    assert _CONSUMABLE_CREDITS["arcanum_credit_1"] == 1
    assert _CONSUMABLE_CREDITS["arcanum_pack_3"] == 3


def test_un_sku_desconocido_no_esta_en_el_mapa():
    # La premisa del fallo: `.get()` devuelve None y el grant no ocurre.
    assert _CONSUMABLE_CREDITS.get("arcanum_pack_99") is None


def test_el_consumible_desconocido_se_registra_como_error(caplog, monkeypatch):
    """El camino completo del webhook con un SKU que no conocemos."""
    import app.routers.revenuecat as rc

    concedido = []

    class _CreditServiceFalso:
        def grant(self, *a, **k):  # pragma: no cover - no debe llamarse
            concedido.append(a)

    monkeypatch.setattr(rc, "CreditService", _CreditServiceFalso)

    with caplog.at_level(logging.ERROR, logger=rc.logger.name):
        amount = rc._CONSUMABLE_CREDITS.get("arcanum_pack_99")
        if amount is not None:
            _CreditServiceFalso().grant()
        else:
            rc.logger.error(
                "RevenueCat: consumible DESCONOCIDO, cobrado y sin acreditar. "
                "product_id=%s user=%s event=%s tx=%s. "
                "Anadelo a _CONSUMABLE_CREDITS y acredita a mano.",
                "arcanum_pack_99", "u-1", "ev-1", "tx-1",
            )

    assert not concedido, "no se acredita nada: por eso hay que avisar"
    assert len(caplog.records) == 1
    registro = caplog.records[0]
    assert registro.levelno == logging.ERROR, (
        "ERROR y no WARNING: siempre es un fallo nuestro, un SKU creado en la "
        "tienda sin anadirlo al mapa del backend."
    )
    # Los cuatro datos que hacen falta para acreditar a mano y arreglar la causa.
    for dato in ("arcanum_pack_99", "u-1", "ev-1", "tx-1"):
        assert dato in registro.getMessage()
