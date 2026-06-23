"""Siembra de datos de referencia al arrancar el backend.

Invoca los scripts idempotentes de scripts/ (cada uno chequea por slug antes
de insertar, así correr esto en cada deploy es seguro y barato). No fatal: si
un seed falla (BD no lista, tabla ausente), se loguea y el arranque continúa.
"""
import logging

logger = logging.getLogger("arcanum.seed")


def run_seeds() -> None:
    """Puebla materia_items y tarot_cards si faltan. Idempotente, no fatal."""
    _safe_seed("materia", "scripts.seed_materia")
    _safe_seed("tarot", "scripts.seed_tarot")


def _safe_seed(label: str, module_path: str) -> None:
    try:
        import importlib

        module = importlib.import_module(module_path)
        module.main()
        logger.info("seed %s OK", label)
    except Exception as exc:  # noqa: BLE001 — no fatal por diseño
        logger.warning("seed %s falló (no fatal): %s", label, exc)
