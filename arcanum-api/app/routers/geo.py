"""Geocoding del lugar de nacimiento: país+ciudad -> lat/lon/timezone reales.

Reemplaza el default hardcodeado a Bogotá que usaba el onboarding. Requiere
auth: se llama dentro del flujo de onboarding, donde el usuario ya está
autenticado (registro -> login automático -> onboarding). El cliente debe
mostrar `display_name` para que el usuario CONFIRME antes de guardar nada
en su perfil (POST /users/me con los valores devueltos aquí).
"""
from fastapi import APIRouter, Depends, HTTPException, status

from app.core.rate_limit import enforce_user_quota
from app.core.security import get_current_user
from app.domain.entities import UserEntity
from app.schemas.geo import GeoResolveRequest, GeoResolveResponse
from app.services import geocoding

router = APIRouter()


@router.post("/resolve", response_model=GeoResolveResponse)
def resolve_geo(
    body: GeoResolveRequest,
    current_user: UserEntity = Depends(get_current_user),
):
    """Resuelve país+ciudad a lat/lon/timezone reales.

    Fail loud: 422 con detalle si Nominatim no encuentra el lugar o no se
    puede derivar la zona horaria. El cliente debe mostrar el error y pedir
    corregir — nunca avanzar con un default inventado.
    """
    enforce_user_quota(
        scope="geo_resolve",
        identifier=str(current_user.id),
        max_calls=30,
        window_seconds=86400,
        detail="Demasiadas búsquedas de ubicación hoy. Intenta de nuevo mañana.",
    )
    try:
        loc = geocoding.resolve_location(body.country, body.city)
    except geocoding.GeocodingError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e)
        )

    return GeoResolveResponse(
        display_name=loc.display_name,
        lat=f"{loc.lat:.6f}",
        lon=f"{loc.lon:.6f}",
        timezone=loc.timezone,
    )
