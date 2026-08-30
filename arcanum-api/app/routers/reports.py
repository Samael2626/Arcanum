from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.models.content_report import ContentReport
from app.schemas.content_report import ContentReportCreate, ContentReportResponse

router = APIRouter(prefix="/reports", tags=["reports"])


@router.post("", response_model=ContentReportResponse, status_code=status.HTTP_201_CREATED)
def create_content_report(
    payload: ContentReportCreate,
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ContentReport:
    report = ContentReport(user_id=current_user.id, **payload.model_dump())
    db.add(report)
    db.commit()
    db.refresh(report)
    return report
