"""Endpoints del Oráculo: tiradas de tarot y consulta ritual con IA Claude."""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from uuid import UUID
from datetime import datetime

from app.core.config import settings
from app.core.rate_limit import enforce_user_quota
from app.db.session import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.divination_session import DivinationSession
from app.models.natal_chart import NatalChart
from app.models.oracle_conversation import OracleConversation
from app.schemas.divination_session import DivinationSessionCreate, DivinationSessionResponse
from app.schemas.oracle_conversation import OracleConversationCreate, OracleConversationResponse
from app.services.tarot_service import draw_cards, get_tarot_deck
from app.services.claude_service import get_claude_response
from app.services.oracle_context import build_oracle_context

router = APIRouter(tags=["oracle"])

_ONE_DAY_SECONDS = 86400


class OracleQuestion(BaseModel):
    """Body de la consulta al oráculo IA. El cliente SOLO manda la pregunta."""
    question: str = Field(..., min_length=1, max_length=500)

# -------------------------------------------------
# TAROT
# -------------------------------------------------
@router.post("/tarot/draw", response_model=DivinationSessionResponse)
def draw_tarot(
    enc_question: str | None = None,
    question_iv: str | None = None,
    spread_type: str = "three_card",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
    baraja = get_tarot_deck()
    cartas = draw_cards(baraja, count=count, spread_type=spread_type)

    session_in = DivinationSessionCreate(
        system="tarot",
        spread_type=spread_type,
        cards_drawn={"cards": cartas},
        encrypted_question=enc_question,
        question_iv=question_iv,
    )
    session = DivinationSession(user_id=current_user.id, **session_in.model_dump())
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


# -------------------------------------------------
# IA RITUAL (Claude API)
# -------------------------------------------------
@router.post("/ia", response_model=OracleConversationResponse)
def ritual_ia(
    body: OracleQuestion,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Consulta ritual con Claude. El contexto astral se construye SERVER-SIDE a
    partir de la carta natal cacheada del usuario (el cliente solo manda la
    pregunta). Aplica cuota diaria por usuario según el tier y guarda la
    conversación en oracle_conversations.
    """
    is_premium = current_user.subscription_tier == "premium"

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

    natal_chart = db.query(NatalChart).filter(NatalChart.user_id == current_user.id).first()
    if natal_chart is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Calcula primero tu carta natal con POST /astral/natal-chart.",
        )

    context = build_oracle_context(current_user, natal_chart, db)
    model = settings.CLAUDE_MODEL_PREMIUM if is_premium else settings.CLAUDE_MODEL_FREE
    claude_reply = get_claude_response(context=context, question=body.question, model=model)

    now = datetime.utcnow().isoformat()
    user_msg = {"role": "user", "content": body.question, "timestamp": now}
    assistant_msg = {"role": "assistant", "content": claude_reply, "timestamp": now}
    # Snapshot del contexto astral usado (auditoría/historial), como mensaje
    # 'system' que el frontend ya tolera (MessageRole.system existe en el schema).
    context_msg = {"role": "system", "content": context, "timestamp": now}
    messages = [context_msg, user_msg, assistant_msg]

    conv_in = OracleConversationCreate(
        tradition_context=current_user.preferred_tradition,
        messages=messages,
    )
    conv = OracleConversation(user_id=current_user.id, **conv_in.model_dump(mode="json"))
    db.add(conv)
    db.commit()
    db.refresh(conv)
    return conv