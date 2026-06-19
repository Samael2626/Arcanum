"""Oráculo: tarot (Arcanos Mayores). IA ritual (Claude) pendiente de API key."""
from fastapi import APIRouter, HTTPException, Query, status

from app.services import tarot

router = APIRouter()


@router.get("/tarot/spreads")
def tarot_spreads():
    """Tiradas disponibles y sus posiciones."""
    return tarot.SPREADS


@router.get("/tarot/draw")
def tarot_draw(spread: str = Query("three")):
    """Tira las cartas de la tirada indicada."""
    if spread not in tarot.SPREADS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Tirada no soportada: {spread}",
        )
    return {"spread": spread, "cards": tarot.draw(spread)}
