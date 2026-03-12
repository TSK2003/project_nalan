from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.bill import Bill
from app.models.upi_account import UpiAccount
from app.utils.upi import build_upi_qr_string


def _resolve_upi_account(db: Session, upi_account_id: Optional[int] = None) -> UpiAccount:
    """Resolve which UPI account to use. Prioritizes explicit ID, then default, then any active."""
    if upi_account_id:
        account = db.query(UpiAccount).filter(
            UpiAccount.id == upi_account_id, UpiAccount.is_active == True
        ).first()
        if not account:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Selected UPI account not found or inactive",
            )
        return account

    # Fallback to default
    account = db.query(UpiAccount).filter(
        UpiAccount.is_active == True, UpiAccount.is_default == True
    ).first()

    if not account:
        # Fallback to any active account
        account = db.query(UpiAccount).filter(UpiAccount.is_active == True).first()

    if not account:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No UPI accounts configured. Please add a UPI account first.",
        )

    return account


def confirm_cash_payment(db: Session, bill_id: int, cash_received: Decimal) -> Bill:
    """Confirm cash payment for a bill."""
    bill = db.query(Bill).filter(Bill.id == bill_id).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    if bill.status not in ("DRAFT", "PENDING_PAYMENT"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot process payment for bill in {bill.status} status",
        )

    if cash_received < bill.total_amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cash received is less than bill total",
        )

    bill.payment_mode = "CASH"
    bill.cash_received = cash_received
    bill.cash_change = cash_received - bill.total_amount
    bill.status = "PAID"
    bill.paid_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(bill)
    return bill


def initiate_upi_payment(db: Session, bill_id: int,
                          upi_account_id: Optional[int] = None) -> dict:
    """Initiate UPI payment — resolve UPI account, generate QR string, set status."""
    bill = db.query(Bill).filter(Bill.id == bill_id).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    if bill.status not in ("DRAFT", "PENDING_PAYMENT"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot process payment for bill in {bill.status} status",
        )

    # Resolve which UPI account to use
    upi_account = _resolve_upi_account(db, upi_account_id)

    upi_amount = float(bill.total_amount)
    qr_string = build_upi_qr_string(upi_amount, bill.bill_number, upi_id=upi_account.upi_id)

    bill.payment_mode = "UPI"
    bill.upi_amount = bill.total_amount
    bill.upi_status = "PENDING"
    bill.status = "PENDING_PAYMENT"
    bill.upi_account_id = upi_account.id
    bill.upi_id_used = upi_account.upi_id  # snapshot

    db.commit()
    db.refresh(bill)

    return {
        "bill_id": bill.id,
        "bill_number": bill.bill_number,
        "status": bill.status,
        "payment_mode": "UPI",
        "total_amount": bill.total_amount,
        "upi_amount": bill.upi_amount,
        "upi_status": bill.upi_status,
        "upi_qr_string": qr_string,
        "upi_id_used": upi_account.upi_id,
        "upi_account_label": upi_account.label,
    }


def initiate_split_payment(db: Session, bill_id: int, cash_amount: Decimal,
                            upi_account_id: Optional[int] = None) -> dict:
    """Initiate split payment — cash portion confirmed immediately, UPI portion generates QR."""
    bill = db.query(Bill).filter(Bill.id == bill_id).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    if bill.status not in ("DRAFT", "PENDING_PAYMENT"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot process payment for bill in {bill.status} status",
        )

    if cash_amount >= bill.total_amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cash amount covers the entire bill. Use cash payment instead.",
        )

    if cash_amount < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cash amount cannot be negative",
        )

    # Resolve which UPI account to use
    upi_account = _resolve_upi_account(db, upi_account_id)

    upi_amount = bill.total_amount - cash_amount
    qr_string = build_upi_qr_string(float(upi_amount), bill.bill_number, upi_id=upi_account.upi_id)

    bill.payment_mode = "SPLIT"
    bill.cash_received = cash_amount
    bill.upi_amount = upi_amount
    bill.upi_status = "PENDING"
    bill.status = "PENDING_PAYMENT"
    bill.upi_account_id = upi_account.id
    bill.upi_id_used = upi_account.upi_id  # snapshot

    db.commit()
    db.refresh(bill)

    return {
        "bill_id": bill.id,
        "bill_number": bill.bill_number,
        "status": bill.status,
        "payment_mode": "SPLIT",
        "total_amount": bill.total_amount,
        "cash_received": cash_amount,
        "upi_amount": upi_amount,
        "upi_status": bill.upi_status,
        "upi_qr_string": qr_string,
        "upi_id_used": upi_account.upi_id,
        "upi_account_label": upi_account.label,
    }


def get_payment_status(db: Session, bill_id: int) -> dict:
    """Get payment status for polling."""
    bill = db.query(Bill).filter(Bill.id == bill_id).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    result = {
        "bill_id": bill.id,
        "bill_number": bill.bill_number,
        "status": bill.status,
        "payment_mode": bill.payment_mode,
        "total_amount": bill.total_amount,
        "cash_received": bill.cash_received,
        "cash_change": bill.cash_change,
        "upi_amount": bill.upi_amount,
        "upi_ref_id": bill.upi_ref_id,
        "upi_status": bill.upi_status,
        "upi_id_used": bill.upi_id_used,
    }

    # Regenerate QR if still pending
    if bill.upi_status == "PENDING" and bill.upi_amount:
        upi_id = bill.upi_id_used  # Use the snapshotted UPI ID
        result["upi_qr_string"] = build_upi_qr_string(
            float(bill.upi_amount), bill.bill_number, upi_id=upi_id
        )

    return result


def process_upi_webhook(db: Session, bill_number: str, upi_ref_id: str,
                         amount: Decimal, webhook_status: str) -> Bill:
    """Process UPI webhook callback — mark bill as PAID or FAILED."""
    bill = db.query(Bill).filter(Bill.bill_number == bill_number).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    if bill.status == "PAID":
        return bill  # Idempotent

    if webhook_status == "SUCCESS":
        bill.upi_ref_id = upi_ref_id
        bill.upi_status = "SUCCESS"

        if bill.payment_mode == "SPLIT":
            # Check if cash + UPI covers total
            cash = bill.cash_received or Decimal("0")
            if cash + amount >= bill.total_amount:
                bill.status = "PAID"
                bill.paid_at = datetime.now(timezone.utc)
            # else stay PENDING_PAYMENT
        else:
            # Full UPI payment
            bill.status = "PAID"
            bill.paid_at = datetime.now(timezone.utc)
    elif webhook_status == "FAILED":
        bill.upi_status = "FAILED"
        bill.status = "FAILED"

    db.commit()
    db.refresh(bill)
    return bill

