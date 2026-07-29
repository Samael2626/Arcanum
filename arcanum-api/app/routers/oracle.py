"""Endpoints del Oráculo: tiradas de tarot y consulta ritual con IA Claude."""
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.api.deps import (
    get_divination_session_repo,
    get_natal_chart_repo,
    get_oracle_conversation_repo,
    get_tarot_service,
)
from app.adapters.repositories import (
    DivinationSessionRepository,
    NatalChartRepository,
    OracleConversationRepository,
)
from app.application.services.tarot_service import TarotService, draw_cards
from app.core.config import settings
from app.core.rate_limit import enforce_user_quota
from app.core.security import get_current_user
from app.domain.entities import UserEntity
from app.schemas.divination_session import DivinationSessionCreate, DivinationSessionResponse
from app.schemas.oracle_conversation import OracleConversationCreate, OracleConversationResponse
from app.services.claude_service import get_claude_response
from app.services.oracle_context import build_oracle_context, build_tarot_context

router = APIRouter(tags=["oracle"])

_ONE_DAY_SECONDS = 86400


class OracleQuestion(BaseModel):
    """Body de la consulta al oráculo IA. Tres modos:

    - solo `question`              → lectura astral (como antes).
    - `question` + `session_id`    → respuesta anclada a las cartas tiradas.
    - solo `divination_session_id` → lectura de la tirada (sin pregunta).
    Ambos nulos → 400 (validado en el endpoint).
    """
    question: str | None = Field(default=None, min_length=1, max_length=500)
    divination_session_id: UUID | None = None


# -------------------------------------------------
# TAROT
# -------------------------------------------------
@router.post("/tarot/draw", response_model=DivinationSessionResponse)
def draw_tarot(
    enc_question: str | None = None,
    question_iv: str | None = None,
    spread_type: str = "three_card",
    current_user: UserEntity = Depends(get_current_user),
    div_repo: DivinationSessionRepository = Depends(get_divination_session_repo),
    tarot: TarotService = Depends(get_tarot_service),
):
    """
    Realiza una tirada de tarot y guarda la sesión.
    La pregunta (si se proporciona) debe venir cifrada AES-256 desde el cliente.
    """
    if spread_type not in ("three_card", "celtic_cross"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tipo de extensión no soportado. Use 'three_card' o 'celtic_cross'.",
        )
    count = 3 if spread_type == "three_card" else 10
    baraja = tarot.get_tarot_deck()
    cartas = draw_cards(baraja, count=count, spread_type=spread_type)

    session_in = DivinationSessionCreate(
        system="tarot",
        spread_type=spread_type,
        cards_drawn={"cards": cartas},
        encrypted_question=enc_question,
        question_iv=question_iv,
    )
    session = div_repo.create(user_id=current_user.id, **session_in.model_dump())
    return session


# -------------------------------------------------
# IA RITUAL (Claude API)
# -------------------------------------------------
@router.post("/ia", response_model=OracleConversationResponse)
def ritual_ia(
    body: OracleQuestion,
    current_user: UserEntity = Depends(get_current_user),
    natal_repo: NatalChartRepository = Depends(get_natal_chart_repo),
    conv_repo: OracleConversationRepository = Depends(get_oracle_conversation_repo),
    div_repo: DivinationSessionRepository = Depends(get_divination_session_repo),
):
    """
    Consulta ritual con Claude. El contexto astral se construye SERVER-SIDE a
    partir de la carta natal cacheada del usuario (el cliente solo manda la
    pregunta). Aplica cuota diaria por usuario según el tier y guarda la
    conversación en oracle_conversations.
    """
    is_premium = current_user.subscription_tier == "premium"

    # Validación de entrada ANTES de consumir cuota: al menos uno de los dos.
    if not body.question and body.divination_session_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Envía una pregunta, un divination_session_id, o ambos.",
        )

    # Cuota diaria por usuario (no por IP). Fail-open si Redis no está.
    daily_limit = settings.ORACLE_PREMIUM_DAILY if is_premium else settings.ORACLE_FREE_DAILY
    enforce_user_quota(
        scope="oracle_ia",
        identifier=str(current_user.id),
        max_calls=daily_limit,
        window_seconds=_ONE_DAY_SECONDS,
        detail=(f"Has alcanzado tu cupo diario de consultas al oráculo "
                f"({daily_limit}/día). Vuelve mañana o mejora tu plan."),
    )

    natal_chart = natal_repo.get_by_user_id(current_user.id)
    if natal_chart is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Calcula primero tu carta natal con POST /astral/natal-chart.",
        )

    context = build_oracle_context(current_user, natal_chart)

    # Tirada opcional: SOLO si el cliente manda un id explícito (sin heurística
    # de "última tirada reciente"). Debe pertenecer al usuario y ser de tarot.
    tarot_context: str | None = None
    card_count = 0
    expected_cards: list[str] = []
    if body.divination_session_id is not None:
        session = div_repo.get_owned(body.divination_session_id, current_user.id)
        if session is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tirada no encontrada.",
            )
        if session.system != "tarot":
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="La sesión indicada no es una tirada de tarot.",
            )
        tarot_context = build_tarot_context(session)
        _cards = (session.cards_drawn or {}).get("cards") or []
        card_count = len(_cards)
        expected_cards = [c.get("name") or c.get("slug") or "" for c in _cards]

    model = settings.CLAUDE_MODEL_PREMIUM if is_premium else settings.CLAUDE_MODEL_FREE
    claude_reply = get_claude_response(
        context=context, question=body.question, tarot=tarot_context, model=model,
        card_count=card_count, expected_cards=expected_cards,
    )

    now = datetime.utcnow().isoformat()
    # Modo solo-tirada: no hay pregunta; marcador legible para el historial.
    user_content = body.question or "[Lectura de tirada de tarot]"
    user_msg = {"role": "user", "content": user_content, "timestamp": now}
    assistant_msg = {"role": "assistant", "content": claude_reply, "timestamp": now}
    # Snapshot del contexto usado (auditoría). Si hubo tirada, se incluye para
    # que el historial muestre qué cartas se leyeron (sin columna nueva ni migración).
    snapshot = context if tarot_context is None else f"{context}\n\n{tarot_context}"
    context_msg = {"role": "system", "content": snapshot, "timestamp": now}
    messages = [context_msg, user_msg, assistant_msg]

    conv_in = OracleConversationCreate(
        tradition_context=current_user.preferred_tradition,
        messages=messages,
    )
    conv = conv_repo.create_or_update(
        user_id=current_user.id,
        messages=messages,
        tradition_context=current_user.preferred_tradition,
    )
    return conv