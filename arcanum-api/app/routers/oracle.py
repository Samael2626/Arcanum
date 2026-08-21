"""Endpoints del Oráculo: tiradas de tarot y consulta ritual con IA Groq."""
import logging
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, status
from groq import APIConnectionError, APIStatusError, APITimeoutError
from pydantic import BaseModel, Field
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.adapters.repositories import (
    DivinationSessionRepository,
    NatalChartRepository,
    OracleConversationRepository,
)
from app.api.deps import (
    get_divination_session_repo,
    get_natal_chart_repo,
    get_oracle_conversation_repo,
    get_tarot_service,
)
from app.application.services.tarot_service import TarotService, draw_cards
from app.application.services.usage_service import UsageService
from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.schemas.divination_session import DivinationSessionCreate, DivinationSessionResponse
from app.schemas.oracle_conversation import OracleConversationResponse
from app.services import safety
from app.services.claude_service import get_claude_response
from app.services.oracle_context import build_oracle_context, build_tarot_context

logger = logging.getLogger("arcanum.oracle")

router = APIRouter(tags=["oracle"])


class OracleQuestion(BaseModel):
    question: str | None = Field(default=None, min_length=1, max_length=500)
    divination_session_id: UUID | None = None


@router.post("/tarot/draw", response_model=DivinationSessionResponse)
def draw_tarot(
    enc_question: str | None = None,
    question_iv: str | None = None,
    spread_type: str = "three_card",
    current_user: UserEntity = Depends(get_current_user),
    div_repo: DivinationSessionRepository = Depends(get_divination_session_repo),
    db: Session = Depends(get_db),
    idempotency_key: str = Header(..., alias="Idempotency-Key"),
    tarot: TarotService = Depends(get_tarot_service),
):
    if spread_type not in ("three_card", "celtic_cross"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Tipo de extensión no soportado.")
    payload = {"spread_type": spread_type, "enc_question": enc_question, "question_iv": question_iv}
    limit = settings.TAROT_PREMIUM_DAILY if current_user.subscription_tier == "premium" else settings.TAROT_FREE_DAILY
    reservation = UsageService().reserve(db, current_user.id, "tarot", idempotency_key, payload, limit)
    if reservation.replay:
        return reservation.operation.result
    try:
        cards = draw_cards(
            tarot.get_tarot_deck(),
            count=3 if spread_type == "three_card" else 10,
            spread_type=spread_type,
        )
        session = div_repo.create(
            user_id=current_user.id,
            commit=False,
            **DivinationSessionCreate(
                system="tarot",
                spread_type=spread_type,
                cards_drawn={"cards": cards},
                encrypted_question=enc_question,
                question_iv=question_iv,
            ).model_dump(),
        )
        result = DivinationSessionResponse.model_validate(session).model_dump(mode="json")
        UsageService().capture(db, reservation.operation, result)
        return session
    except Exception:
        db.rollback()
        UsageService().reverse(db, reservation.operation)
        raise


@router.post("/ia", response_model=OracleConversationResponse)
def ritual_ia(
    body: OracleQuestion,
    current_user: UserEntity = Depends(get_current_user),
    natal_repo: NatalChartRepository = Depends(get_natal_chart_repo),
    conv_repo: OracleConversationRepository = Depends(get_oracle_conversation_repo),
    div_repo: DivinationSessionRepository = Depends(get_divination_session_repo),
    db: Session = Depends(get_db),
    idempotency_key: str = Header(..., alias="Idempotency-Key"),
):
    if not body.question and body.divination_session_id is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Envía una pregunta, un divination_session_id, o ambos.")

    # Guardarrail de entrada, ANTES de reservar cuota: una pregunta que no se va
    # a responder no puede costarle una consulta a nadie, y ademas no llega al
    # modelo. La crisis manda sobre todo lo demas: ahi no hay lectura simbolica
    # que valga, hay derivacion. El porque de cada dominio vive en `safety`.
    motivo = safety.screen_question(body.question)
    if motivo is not None:
        logger.warning("Consulta rechazada por guardarrail de entrada: %s", motivo)
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY, safety.message_for(motivo))

    natal_chart = natal_repo.get_by_user_id(current_user.id)
    if natal_chart is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "Calcula primero tu carta natal con POST /astral/natal-chart.",
        )
    context = build_oracle_context(current_user, natal_chart)
    tarot_context: str | None = None
    card_count = 0
    expected_cards: list[str] = []
    if body.divination_session_id is not None:
        session = div_repo.get_owned(body.divination_session_id, current_user.id)
        if session is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Tirada no encontrada.")
        if session.system != "tarot":
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "La sesión indicada no es una tirada de tarot.")
        tarot_context = build_tarot_context(session)
        cards = (session.cards_drawn or {}).get("cards") or []
        card_count = len(cards)
        expected_cards = [card.get("name") or card.get("slug") or "" for card in cards]

    is_premium = current_user.subscription_tier == "premium"
    reservation = UsageService().reserve(
        db,
        current_user.id,
        "oracle",
        idempotency_key,
        body.model_dump(mode="json"),
        settings.ORACLE_PREMIUM_DAILY if is_premium else settings.ORACLE_FREE_DAILY,
    )
    if reservation.replay:
        return reservation.operation.result

    try:
        reply = get_claude_response(
            context=context,
            question=body.question,
            tarot=tarot_context,
            model=settings.ORACLE_MODEL_PREMIUM if is_premium else settings.ORACLE_MODEL_FREE,
            card_count=card_count,
            expected_cards=expected_cards,
        )
        now = datetime.now(timezone.utc).isoformat()
        messages = [
            {"role": "system", "content": context if tarot_context is None else f"{context}\n\n{tarot_context}", "timestamp": now},
            {"role": "user", "content": body.question or "[Lectura de tirada de tarot]", "timestamp": now},
            {"role": "assistant", "content": reply, "timestamp": now},
        ]
        conversation = conv_repo.create_or_update(
            user_id=current_user.id,
            messages=messages,
            tradition_context=current_user.preferred_tradition,
            commit=False,
        )
        result = OracleConversationResponse.model_validate(conversation).model_dump(mode="json")
        UsageService().capture(db, reservation.operation, result)
        return conversation
    except (HTTPException, APITimeoutError, APIConnectionError, APIStatusError, SQLAlchemyError):
        db.rollback()
        UsageService().reverse(db, reservation.operation)
        raise
    except Exception:
        db.rollback()
        UsageService().reverse(db, reservation.operation)
        raise
