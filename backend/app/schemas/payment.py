from pydantic import BaseModel
from typing import Optional
from decimal import Decimal


class CashPaymentRequest(BaseModel):
    cash_received: Decimal


class UpiPaymentRequest(BaseModel):
    """Initiates UPI payment for the bill."""
    upi_account_id: Optional[int] = None  # Which UPI account to use (default if omitted)


class SplitPaymentRequest(BaseModel):
    cash_amount: Decimal
    # UPI amount is calculated as total - cash_amount


class PaymentStatusResponse(BaseModel):
    bill_id: int
    bill_number: str
    status: str
    payment_mode: Optional[str]
    total_amount: Decimal
    cash_received: Optional[Decimal]
    cash_change: Optional[Decimal]
    upi_amount: Optional[Decimal]
    upi_ref_id: Optional[str]
    upi_status: Optional[str]
    upi_id_used: Optional[str] = None
    upi_qr_string: Optional[str] = None


class WebhookPayload(BaseModel):
    """Simulated UPI gateway webhook payload."""
    transaction_id: str
    bill_number: str
    amount: Decimal
    status: str  # SUCCESS | FAILED
    upi_ref_id: str
