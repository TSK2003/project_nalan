from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.schemas.payment import UpiPaymentRequest, SplitPaymentRequest, PaymentStatusResponse
from app.services.payment_service import (
    initiate_upi_payment, initiate_split_payment, get_payment_status,
)
from app.utils.security import get_current_user

router = APIRouter(prefix="/api", tags=["Payments"])


@router.post("/bills/{bill_id}/payment")
def initiate_payment(
    bill_id: int,
    payment_type: str = "UPI",
    upi_account_id: Optional[int] = None,
    split_data: SplitPaymentRequest = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Initiate UPI or split payment for a bill.

    Optionally pass upi_account_id to select which UPI account to use.
    If not provided, the default UPI account is used.
    """
    if payment_type.upper() == "SPLIT" and split_data:
        return initiate_split_payment(
            db, bill_id, split_data.cash_amount,
            upi_account_id=upi_account_id,
        )
    else:
        return initiate_upi_payment(
            db, bill_id,
            upi_account_id=upi_account_id,
        )


@router.get("/payments/{bill_id}/status")
def poll_payment_status(
    bill_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Poll payment status for a bill (used by Flutter to check UPI confirmation)."""
    return get_payment_status(db, bill_id)

