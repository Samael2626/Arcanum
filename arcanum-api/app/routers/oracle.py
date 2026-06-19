"""Endpoints del Oráculo: tiradas de tarot y consulta ritual con IA Claude."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from uuid import UUID
from datetime import datetime

from app.db.session import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.divination_session import DivinationSession
from app.models.oracle_conversation import OracleConversation
from app.schemas.divination_session import DivinationSessionCreate, DivinationSessionResponse
from app.schemas.oracle_conversation import OracleConversationCreate, OracleConversationResponse
from app.services.tarot_service import draw_cards, get_tarot_deck
from app.services.claude_service import get_claude_response

router = APIRouter(tags=["oracle"])

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
    context: str,  # Contexto astral (natal chart, fase lunar, hora planetaria, etc.)
    question: str,  # Pregunta del usuario en texto plano (no cifrada)
    tradition_context: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Consulta ritual usando Claude API con el contexto proporcionado.
    Guarda la conversación en oracle_conversations.
    """
    claude_reply = get_claude_response(context=context, question=question)

    user_msg = {"role": "user", "content": question, "timestamp": datetime.utcnow().isoformat()}
    assistant_msg = {"role": "assistant", "content": claude_reply, "timestamp": datetime.utcnow().isoformat()}
    messages = [user_msg, assistant_msg]

    conv_in = OracleConversationCreate(
        tradition_context=tradition_context,
        messages=messages,
    )
    conv = OracleConversation(user_id=current_user.id, **conv_in.model_dump())
    db.add(conv)
    db.commit()
    db.refresh(conv)
    return conv