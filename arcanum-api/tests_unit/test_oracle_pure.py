"""Tests unitarios PUROS del Oráculo — sin BD, sin TestClient, sin conftest.

Viven fuera de `tests/` a propósito: el conftest de `tests/` tiene un fixture
autouse (session-scope) que corre `Base.metadata.create_all` sobre SQLite, y los
modelos usan tipos exclusivos de PostgreSQL (UUID/JSONB/ARRAY) que SQLite no sabe
compilar. Eso hace fallar en setup CUALQUIER test del paquete `tests/`, incluso
los puros. Aislándolos aquí, no se carga ese conftest.

Ejecutar desde arcanum-api/ con:
    venv/Scripts/python.exe -m pytest tests_unit/ -q

Cubre dos funciones puras (sin I/O):
  - oracle_context.build_tarot_context(session)   → render de la tirada
  - claude_service._build_user_message(ctx, q, t) → ensamblado del mensaje user
"""
from types import SimpleNamespace

from app.services.oracle_context import build_tarot_context
from app.services.claude_service import _build_user_message


# ── build_tarot_context ───────────────────────────────────────────────────────

def _session(cards, spread_type="three_card"):
    """Fake de DivinationSession: build_tarot_context solo lee dos atributos."""
    return SimpleNamespace(
        cards_drawn={"cards": cards} if cards is not None else None,
        spread_type=spread_type,
    )


def test_tarot_context_sin_cartas_devuelve_vacio():
    assert build_tarot_context(_session([])) == ""
    assert build_tarot_context(_session(None)) == ""


def test_tarot_context_render_por_posicion_derecha():
    cards = [
        {"position": "Pasado", "name": "El Loco", "drawn_upright": True,
         "meaning": "Nuevos comienzos."},
        {"position": "Presente", "name": "La Torre", "drawn_upright": True,
         "meaning": "Ruptura súbita."},
    ]
    out = build_tarot_context(_session(cards))
    assert "TIRADA DE TAROT DEL CONSULTANTE (spread: three_card)" in out
    assert "- Pasado: El Loco (derecha) — Nuevos comienzos." in out
    assert "- Presente: La Torre (derecha) — Ruptura súbita." in out


def test_tarot_context_marca_invertida():
    cards = [{"position": "Mensaje", "name": "La Luna", "drawn_upright": False,
              "meaning": "Confusión que se disipa."}]
    out = build_tarot_context(_session(cards, spread_type="one_card"))
    assert "(invertida)" in out
    assert "spread: one_card" in out


def test_tarot_context_carta_sin_meaning_no_deja_guion_colgando():
    cards = [{"position": "Presente", "name": "El Sol", "drawn_upright": True}]
    out = build_tarot_context(_session(cards))
    assert "- Presente: El Sol (derecha)" in out
    assert "—" not in out  # sin meaning no se agrega el separador


def test_tarot_context_fallback_a_slug_y_orientacion_por_defecto():
    # Sin 'name' usa 'slug'; sin 'drawn_upright' asume derecha (default True).
    cards = [{"position": "Futuro", "slug": "el-mago", "meaning": "Voluntad."}]
    out = build_tarot_context(_session(cards))
    assert "- Futuro: el-mago (derecha) — Voluntad." in out


# ── _build_user_message ───────────────────────────────────────────────────────

_CTX = "CONTEXTO ASTRAL DEL CONSULTANTE\nLuna: llena."
_TAROT = "TIRADA DE TAROT DEL CONSULTANTE\n- Presente: El Sol (derecha)"


def test_user_message_solo_pregunta():
    q = "¿Qué energía rige mi día?"
    msg = _build_user_message(_CTX, q, None)
    assert msg.startswith(_CTX)
    assert f"Pregunta del consultante: {q}" in msg
    assert "TIRADA DE TAROT" not in msg
    assert "no formuló pregunta" not in msg


def test_user_message_pregunta_mas_tirada_respeta_orden():
    q = "¿Qué me revela la tirada?"
    msg = _build_user_message(_CTX, q, _TAROT)
    # Orden esperado: contexto → tirada → pregunta.
    i_ctx = msg.index(_CTX)
    i_tarot = msg.index("TIRADA DE TAROT")
    i_q = msg.index("Pregunta del consultante:")
    assert i_ctx < i_tarot < i_q


def test_user_message_solo_tirada_pide_lectura():
    msg = _build_user_message(_CTX, None, _TAROT)
    assert "TIRADA DE TAROT" in msg
    assert "no formuló pregunta" in msg
    assert "Pregunta del consultante:" not in msg


def test_user_message_solo_contexto_marca_ausencia_de_pregunta():
    msg = _build_user_message(_CTX, None, None)
    assert msg.startswith(_CTX)
    assert "no formuló pregunta" in msg
    assert "TIRADA DE TAROT" not in msg
