from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.schemas.bill import BillCreate, BillUpdate, BillResponse, BillListResponse
from app.services.billing_service import (
    create_bill, update_bill, cancel_bill, get_bill, get_bills, search_bills,
)
from app.services.payment_service import confirm_cash_payment
from app.schemas.payment import CashPaymentRequest
from app.utils.security import get_current_user

router = APIRouter(prefix="/api/bills", tags=["Bills"])


@router.post("", response_model=BillResponse, status_code=201)
def create_new_bill(
    bill_data: BillCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new bill in DRAFT status."""
    bill = create_bill(
        db,
        items_data=bill_data.items,
        user_id=current_user.id,
        discount_amount=bill_data.discount_amount,
        discount_percent=bill_data.discount_percent,
        discount_reason=bill_data.discount_reason,
    )
    return _bill_to_response(bill)


@router.put("/{bill_id}", response_model=BillResponse)
def update_existing_bill(
    bill_id: int,
    bill_data: BillUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update bill items and/or discount."""
    bill = update_bill(
        db,
        bill_id=bill_id,
        items_data=bill_data.items,
        discount_amount=bill_data.discount_amount,
        discount_percent=bill_data.discount_percent,
        discount_reason=bill_data.discount_reason,
    )
    return _bill_to_response(bill)


@router.get("/search")
def search_bills_endpoint(
    q: str = Query(..., min_length=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Search bills by bill number."""
    bills = search_bills(db, q)
    return [_bill_to_list_response(b) for b in bills]


@router.get("", response_model=list[BillListResponse])
def list_bills(
    status: Optional[str] = None,
    payment_mode: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get paginated list of bills with filters."""
    bills = get_bills(db, status, payment_mode, date_from, date_to, page, page_size)
    return [_bill_to_list_response(b) for b in bills]


@router.get("/{bill_id}", response_model=BillResponse)
def get_bill_detail(
    bill_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get full bill detail."""
    bill = get_bill(db, bill_id)
    return _bill_to_response(bill)


@router.post("/{bill_id}/cancel", response_model=BillResponse)
def cancel_bill_endpoint(
    bill_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Cancel a bill."""
    bill = cancel_bill(db, bill_id)
    return _bill_to_response(bill)


@router.post("/{bill_id}/confirm-cash", response_model=BillResponse)
def confirm_cash(
    bill_id: int,
    payment: CashPaymentRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Confirm cash payment for a bill."""
    bill = confirm_cash_payment(db, bill_id, payment.cash_received)
    return _bill_to_response(bill)


def _bill_to_response(bill) -> dict:
    """Convert Bill ORM to response dict."""
    return {
        "id": bill.id,
        "bill_number": bill.bill_number,
        "subtotal": bill.subtotal,
        "discount_amount": bill.discount_amount,
        "discount_percent": bill.discount_percent,
        "total_amount": bill.total_amount,
        "status": bill.status,
        "payment_mode": bill.payment_mode,
        "cash_received": bill.cash_received,
        "cash_change": bill.cash_change,
        "upi_amount": bill.upi_amount,
        "upi_ref_id": bill.upi_ref_id,
        "upi_status": bill.upi_status,
        "upi_id_used": bill.upi_id_used,
        "discount_reason": bill.discount_reason,
        "cashier_name": bill.cashier.full_name if bill.cashier else None,
        "created_at": bill.created_at,
        "paid_at": bill.paid_at,
        "cancelled_at": bill.cancelled_at,
        "items": [
            {
                "id": item.id,
                "menu_item_id": item.menu_item_id,
                "item_name": item.item_name,
                "item_category": item.item_category,
                "unit_price": item.unit_price,
                "quantity": item.quantity,
                "line_total": item.line_total,
            }
            for item in bill.items
        ],
    }


def _bill_to_list_response(bill) -> dict:
    """Convert Bill ORM to list response dict."""
    return {
        "id": bill.id,
        "bill_number": bill.bill_number,
        "total_amount": bill.total_amount,
        "status": bill.status,
        "payment_mode": bill.payment_mode,
        "upi_id_used": bill.upi_id_used,
        "item_count": len(bill.items),
        "cashier_name": bill.cashier.full_name if bill.cashier else None,
        "created_at": bill.created_at,
    }
