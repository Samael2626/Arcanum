"""Contrato HTTP de la biblioteca personal.

Nota sobre las notas personales: NO hay ningun campo de texto en claro en todo
este modulo. El cliente cifra con AES-256 y manda `encrypted_note` + `note_iv`,
exactamente igual que el Grimorio. Anadir aqui un `note: str` seria romper la
promesa de que el servidor no puede leer lo que el usuario escribe.
"""

from datetime import datetime
from typing import Annotated, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

# Los dos idiomas en los que existe el texto: el original y la traduccion.
ReadingLanguage = Literal["es", "en"]


class PositionRef(BaseModel):
    """Posicion estable. Nunca un numero de pagina."""

    work_slug: Annotated[str, Field(min_length=1, max_length=120)]
    chapter_slug: Annotated[str, Field(min_length=1, max_length=160)]
    # Ancla del parrafo, p.ej. "culpeper-complete-herbal.amara-dulcis.3".
    paragraph_anchor: Annotated[str, Field(min_length=1, max_length=255)]
    # 0 = el parrafo entero o su primer trozo. Solo crece si el cliente parte un
    # parrafo largo en fragmentos para que quepa en pantalla.
    fragment_index: Annotated[int, Field(ge=0, le=9999)] = 0

    model_config = ConfigDict(from_attributes=True)


class PositionEcho(PositionRef):
    """Posicion devuelta al cliente, con los titulos para abrir el lector.

    Van resueltos aqui y no los pide el cliente aparte: sin ellos, "Pasajes
    guardados" tendria que hacer una peticion por cada fila para saber que obra
    y que capitulo mostrar.
    """

    work_title: str
    chapter_title: str


class ProgressUpsert(BaseModel):
    """Guardar donde se quedo el usuario. Idempotente por (usuario, obra)."""

    position: PositionRef
    language: ReadingLanguage = "es"


class ProgressResponse(BaseModel):
    id: UUID
    position: PositionEcho
    language: ReadingLanguage
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class BookmarkCreate(BaseModel):
    position: PositionRef
    # Rotulo de navegacion, visible y no confidencial. Lo privado se cifra.
    label: Optional[Annotated[str, Field(max_length=120)]] = None


class BookmarkResponse(BaseModel):
    id: UUID
    position: PositionEcho
    label: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class _NotePair(BaseModel):
    """Ciphertext e IV viajan juntos o no viajan.

    Un ciphertext sin IV es una nota que nadie podra descifrar nunca: mas vale
    rechazarla en el borde que guardar basura irrecuperable.
    """

    encrypted_note: Optional[Annotated[str, Field(max_length=20000)]] = None
    note_iv: Optional[Annotated[str, Field(max_length=64)]] = None

    @model_validator(mode="after")
    def _note_and_iv_together(self):
        if (self.encrypted_note is None) != (self.note_iv is None):
            raise ValueError(
                "encrypted_note y note_iv deben ir juntos: una nota cifrada sin "
                "su IV es irrecuperable"
            )
        return self


class PassageCreate(_NotePair):
    position: PositionRef
    # La cita tal y como se le mostro al usuario. Se copia, no se referencia:
    # si manana se corrige la traduccion, lo guardado sigue diciendo lo que leyo.
    quote_text: Annotated[str, Field(min_length=1, max_length=20000)]
    quote_language: ReadingLanguage = "es"


class PassageNoteUpdate(_NotePair):
    """Editar solo la nota. Mandar ambos en null la borra."""


class PassageResponse(BaseModel):
    id: UUID
    position: PositionEcho
    quote_text: str
    quote_language: ReadingLanguage
    encrypted_note: Optional[str] = None
    note_iv: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
