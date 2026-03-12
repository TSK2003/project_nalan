from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.services.report_service import get_daily_summary, get_range_summary
from app.utils.security import get_current_user

router = APIRouter(prefix="/api/reports", tags=["Reports"])


@router.get("/daily")
def daily_summary(
    date: Optional[str] = Query(None, description="Date in YYYY-MM-DD format"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get daily sales summary."""
    return get_daily_summary(db, date)


@router.get("/range")
def range_summary(
    date_from: str = Query(..., alias="from", description="Start date YYYY-MM-DD"),
    date_to: str = Query(..., alias="to", description="End date YYYY-MM-DD"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get sales summary for a date range."""
    return get_range_summary(db, date_from, date_to)
