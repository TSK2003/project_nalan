from urllib.parse import quote
from app.config import get_settings

settings = get_settings()


def build_upi_qr_string(amount: float, bill_number: str, upi_id: str | None = None) -> str:
    """Build a UPI deep-link string for QR code generation.

    Format: upi://pay?pa={UPI_ID}&pn={NAME}&am={AMOUNT}&cu=INR&tn={BILL_NUMBER}

    Args:
        amount: Payment amount.
        bill_number: Bill reference number for transaction note.
        upi_id: The UPI ID to receive payment. Falls back to config if not provided.
    """
    if not upi_id:
        upi_id = settings.HOTEL_UPI_ID
    hotel_name = quote(settings.HOTEL_NAME)
    amount_str = f"{amount:.2f}"
    txn_note = quote(bill_number)

    return (
        f"upi://pay?"
        f"pa={upi_id}"
        f"&pn={hotel_name}"
        f"&am={amount_str}"
        f"&cu=INR"
        f"&tn={txn_note}"
    )
