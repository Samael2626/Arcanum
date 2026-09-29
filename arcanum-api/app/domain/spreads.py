"""Value objects para spreads de Tarot: definiciones y registro.

Cada tirada tiene sus posiciones (nombres que usan el Oraculo y la lectura) y,
desde la mesa de tarot, su disposicion sobre el pano: un hueco por posicion con
coordenadas en fraccion del area de tirada, giro y significado. La mesa de la app
y el prototipo (`prototipos/tarot-mesa-3d-v2.html`) leen esta misma definicion.

Las tres tiradas originales conservan sus nombres de posicion tal cual: el Oraculo
los recibe en su prompt y cambiarlos alteraria sus respuestas.
"""

import math
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class SpreadType(str, Enum):
    ONE_CARD = "one_card"
    THREE_CARD = "three_card"
    CELTIC_CROSS = "celtic_cross"
    SIMPLE_CROSS = "simple_cross"
    RELATIONSHIP = "relationship"
    HORSESHOE = "horseshoe"
    YEAR_WHEEL = "year_wheel"


@dataclass(frozen=True)
class SpreadSlot:
    """Hueco en el pano: x, y en fraccion del area de tirada (0..1), giro en grados."""
    x: float
    y: float
    rotation: int
    meaning: str


@dataclass(frozen=True)
class Spread:
    slug: str
    name: str
    positions: list[str] = field(default_factory=list)
    # disposicion en la mesa; vacia en tiradas sin mesa
    slots: tuple[SpreadSlot, ...] = ()
    description: str = ""
    card_scale: float = 1.0      # escala de la carta respecto a la base de la mesa
    label_mode: str = "number"   # "name": el nombre se borda en el pano; "number": solo el numero

    def __post_init__(self) -> None:
        if self.slots and len(self.slots) != len(self.positions):
            raise ValueError(f"{self.slug}: {len(self.slots)} huecos para {len(self.positions)} posiciones")

    @property
    def card_count(self) -> int:
        return len(self.positions)

    @classmethod
    def one_card(cls) -> "Spread":
        return cls(slug="one_card", name="Una carta", positions=["Mensaje"],
                   description="Lo esencial, sin rodeos.", card_scale=1.0, label_mode="name",
                   slots=(SpreadSlot(.5, .5, 0, "Lo esencial de la pregunta."),))

    @classmethod
    def three_card(cls) -> "Spread":
        return cls(slug="three_card", name="Tres cartas", positions=["Pasado", "Presente", "Futuro"],
                   description="Pasado, presente y futuro.", card_scale=.9, label_mode="name",
                   slots=(SpreadSlot(.2, .46, 0, "Lo que trajo hasta aquí."),
                          SpreadSlot(.5, .46, 0, "Lo que pesa ahora."),
                          SpreadSlot(.8, .46, 0, "Hacia dónde tiende.")))

    @classmethod
    def celtic_cross(cls) -> "Spread":
        return cls(
            slug="celtic_cross",
            name="Cruz Celta",
            positions=[
                "Situación actual", "El desafío", "Fundamento (raíz)", "Pasado reciente",
                "Lo que corona (posible futuro)", "Futuro inmediato", "Tu actitud",
                "Entorno e influencias", "Esperanzas y miedos", "Resultado",
            ],
            description="La tirada clásica de diez cartas.", card_scale=.56,
            slots=(
                SpreadSlot(.34, .5, 0, "Lo que ocupa tu momento."),
                SpreadSlot(.34, .5, 90, "El desafío inmediato."),
                SpreadSlot(.34, .8, 0, "La raíz de la situación."),
                SpreadSlot(.13, .5, 0, "Lo que se está yendo."),
                SpreadSlot(.34, .2, 0, "Lo mejor que puede salir."),
                SpreadSlot(.55, .5, 0, "Lo que se acerca."),
                SpreadSlot(.86, .87, 0, "Tu actitud."),
                SpreadSlot(.86, .62, 0, "Lo que te rodea."),
                SpreadSlot(.86, .38, 0, "Lo que deseas o temes."),
                SpreadSlot(.86, .13, 0, "Hacia dónde tiende todo."),
            ),
        )

    @classmethod
    def simple_cross(cls) -> "Spread":
        return cls(
            slug="simple_cross", name="Cruz simple",
            positions=["Situación", "Pasado", "Futuro", "Lo que ayuda", "Lo que frena"],
            description="Situación, lo que ayuda y lo que frena.", card_scale=.74,
            slots=(SpreadSlot(.5, .5, 0, "El centro de la pregunta."),
                   SpreadSlot(.2, .5, 0, "Lo que queda atrás."),
                   SpreadSlot(.8, .5, 0, "Lo que se acerca."),
                   SpreadSlot(.5, .14, 0, "La fuerza a favor."),
                   SpreadSlot(.5, .86, 0, "La resistencia.")),
        )

    @classmethod
    def relationship(cls) -> "Spread":
        return cls(
            slug="relationship", name="Relación",
            positions=["Tú", "La otra persona", "Lo que os une", "Lo que os separa", "Hacia dónde va"],
            description="Dos personas y lo que hay entre ellas.", card_scale=.74,
            slots=(SpreadSlot(.18, .3, 0, "Cómo llegas a la relación."),
                   SpreadSlot(.82, .3, 0, "Cómo llega la otra parte."),
                   SpreadSlot(.5, .16, 0, "El vínculo."),
                   SpreadSlot(.5, .52, 0, "La tensión."),
                   SpreadSlot(.5, .87, 0, "La tendencia.")),
        )

    @classmethod
    def horseshoe(cls) -> "Spread":
        return cls(
            slug="horseshoe", name="Herradura",
            positions=["Pasado", "Presente", "Futuro próximo", "Consejo", "Entorno", "Obstáculos", "Desenlace"],
            description="Siete cartas en arco: del pasado al desenlace.", card_scale=.64,
            slots=(SpreadSlot(.08, .8, -8, "Lo que dejó huella."),
                   SpreadSlot(.14, .46, -5, "La situación de hoy."),
                   SpreadSlot(.29, .17, -2, "Lo que llega pronto."),
                   SpreadSlot(.5, .08, 0, "Lo que conviene hacer."),
                   SpreadSlot(.71, .17, 2, "Las personas y el ambiente."),
                   SpreadSlot(.86, .46, 5, "Lo que se interpone."),
                   SpreadSlot(.92, .8, 8, "Hacia dónde va.")),
        )

    @classmethod
    def year_wheel(cls) -> "Spread":
        months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio",
                  "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
        # una carta por mes en circulo, enero arriba y en sentido horario
        slots = tuple(
            SpreadSlot(round(.5 + math.cos(-math.pi / 2 + i * math.pi / 6) * .4, 4),
                       round(.5 + math.sin(-math.pi / 2 + i * math.pi / 6) * .41, 4),
                       0, f"Lo que trae {m.lower()}.")
            for i, m in enumerate(months)
        )
        return cls(slug="year_wheel", name="Rueda del año", positions=months,
                   description="Una carta por mes.", card_scale=.46, slots=slots)


_SPREAD_REGISTRY: dict[str, Spread] = {
    s.slug: s for s in (
        Spread.one_card(), Spread.three_card(), Spread.celtic_cross(), Spread.simple_cross(),
        Spread.relationship(), Spread.horseshoe(), Spread.year_wheel(),
    )
}


def get_spread(slug: str) -> Optional[Spread]:
    return _SPREAD_REGISTRY.get(slug)


def list_spreads() -> list[Spread]:
    return list(_SPREAD_REGISTRY.values())
