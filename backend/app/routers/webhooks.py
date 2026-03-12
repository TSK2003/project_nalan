from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.payment import WebhookPayload
from app.services.payment_service import process_upi_webhook

router = APIRouter(prefix="/api/webhooks", tags=["Webhooks"])


@router.post("/upi/callback")
def upi_webhook(
    payload: WebhookPayload,
    db: Session = Depends(get_db),
):
    """Receive UPI gateway confirmation webhook.

    In production, this endpoint should verify HMAC signature from the gateway.
    For Phase 1 simulation, it accepts the payload directly.
    """
    bill = process_upi_webhook(
        db,
        bill_number=payload.bill_number,
        upi_ref_id=payload.upi_ref_id,
        amount=payload.amount,
        webhook_status=payload.status,
    )
    return {
        "message": "Webhook processed",
        "bill_number": bill.bill_number,
        "bill_status": bill.status,
    }
