from pydantic import BaseModel, ConfigDict, Field


class GeoResolveRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    country: str = Field(..., min_length=1, max_length=100)
    city: str = Field(..., min_length=1, max_length=100)


class GeoResolveResponse(BaseModel):
    """Lugar resuelto por el geocoder. El cliente lo muestra para que el
    usuario CONFIRME antes de persistirlo como lugar de nacimiento."""

    model_config = ConfigDict(from_attributes=True)

    display_name: str
    lat: str
    lon: str
    timezone: str
