from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import func as sql_func
from fastapi import HTTPException, status
from app.models.bill import Bill, BillItem
from app.models.menu_item import MenuItem
from app.config import get_settings

settings = get_settings()


def generate_bill_number(db: Session) -> str:
    """Generate bill number in format: NLN-YYYYMMDD-XXXX (daily sequential)."""
    today = datetime.now(timezone.utc).strftime("%Y%m%d")
    prefix = f"{settings.BILL_PREFIX}-{today}-"

    # Get last bill number for today
    last_bill = (
        db.query(Bill)
        .filter(Bill.bill_number.like(f"{prefix}%"))
        .order_by(Bill.bill_number.desc())
        .first()
    )

    if last_bill:
        last_seq = int(last_bill.bill_number.split("-")[-1])
        next_seq = last_seq + 1
    else:
        next_seq = 1

    return f"{prefix}{next_seq:04d}"


def create_bill(db: Session, items_data: list, user_id: int,
                discount_amount: Decimal = Decimal("0"),
                discount_percent: Decimal = Decimal("0"),
                discount_reason: Optional[str] = None) -> Bill:
    """Create a new bill in DRAFT status with item snapshots."""
    bill_number = generate_bill_number(db)

    bill = Bill(
        bill_number=bill_number,
        subtotal=Decimal("0"),
        discount_amount=discount_amount,
        discount_percent=discount_percent,
        discount_reason=discount_reason,
        total_amount=Decimal("0"),
        status="DRAFT",
        created_by=user_id,
    )
    db.add(bill)
    db.flush()  # Get bill.id

    subtotal = Decimal("0")
    for item_data in items_data:
        menu_item = db.query(MenuItem).filter(
            MenuItem.id == item_data.menu_item_id,
            MenuItem.is_deleted == False,
            MenuItem.is_available == True,
        ).first()

        if not menu_item:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Menu item {item_data.menu_item_id} not found or unavailable",
            )

        line_total = menu_item.price * item_data.quantity
        bill_item = BillItem(
            bill_id=bill.id,
            menu_item_id=menu_item.id,
            item_name=menu_item.name,
            item_category=menu_item.category,
            unit_price=menu_item.price,
            quantity=item_data.quantity,
            line_total=line_total,
        )
        db.add(bill_item)
        subtotal += line_total

    # Calculate total with discount
    bill.subtotal = subtotal
    _apply_discount(bill, discount_amount, discount_percent, subtotal)

    db.commit()
    db.refresh(bill)
    return bill


def update_bill(db: Session, bill_id: int, items_data: Optional[list] = None,
                discount_amount: Optional[Decimal] = None,
                discount_percent: Optional[Decimal] = None,
                discount_reason: Optional[str] = None) -> Bill:
    """Update a DRAFT bill — replace items and/or discount."""
    bill = db.query(Bill).filter(Bill.id == bill_id).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    if bill.status not in ("DRAFT", "PENDING_PAYMENT"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot edit bill in {bill.status} status",
        )

    if items_data is not None:
        # Remove old items
        db.query(BillItem).filter(BillItem.bill_id == bill.id).delete()

        subtotal = Decimal("0")
        for item_data in items_data:
            menu_item = db.query(MenuItem).filter(
                MenuItem.id == item_data.menu_item_id,
                MenuItem.is_deleted == False,
                MenuItem.is_available == True,
            ).first()

            if not menu_item:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Menu item {item_data.menu_item_id} not found or unavailable",
                )

            line_total = menu_item.price * item_data.quantity
            bill_item = BillItem(
                bill_id=bill.id,
                menu_item_id=menu_item.id,
                item_name=menu_item.name,
                item_category=menu_item.category,
                unit_price=menu_item.price,
                quantity=item_data.quantity,
                line_total=line_total,
            )
            db.add(bill_item)
            subtotal += line_total

        bill.subtotal = subtotal

    # Update discount
    d_amount = discount_amount if discount_amount is not None else bill.discount_amount
    d_percent = discount_percent if discount_percent is not None else bill.discount_percent
    _apply_discount(bill, d_amount, d_percent, bill.subtotal)

    if discount_reason is not None:
        bill.discount_reason = discount_reason

    db.commit()
    db.refresh(bill)
    return bill


def cancel_bill(db: Session, bill_id: int) -> Bill:
    """Cancel a bill. Only DRAFT or PENDING_PAYMENT bills can be cancelled."""
    bill = db.query(Bill).filter(Bill.id == bill_id).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    if bill.status in ("PAID", "CANCELLED"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot cancel bill in {bill.status} status",
        )

    bill.status = "CANCELLED"
    bill.cancelled_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(bill)
    return bill


def get_bill(db: Session, bill_id: int) -> Bill:
    bill = db.query(Bill).filter(Bill.id == bill_id).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")
    return bill


def get_bills(db: Session, status_filter: Optional[str] = None,
              payment_mode: Optional[str] = None,
              date_from: Optional[str] = None,
              date_to: Optional[str] = None,
              page: int = 1, page_size: int = 20) -> List[Bill]:
    """Get paginated list of bills with filters."""
    query = db.query(Bill).order_by(Bill.created_at.desc())

    if status_filter:
        query = query.filter(Bill.status == status_filter)
    if payment_mode:
        query = query.filter(Bill.payment_mode == payment_mode)
    if date_from:
        query = query.filter(Bill.created_at >= date_from)
    if date_to:
        query = query.filter(Bill.created_at <= date_to)

    offset = (page - 1) * page_size
    return query.offset(offset).limit(page_size).all()


def search_bills(db: Session, query_str: str) -> List[Bill]:
    """Search bills by bill number or amount."""
    return (
        db.query(Bill)
        .filter(Bill.bill_number.ilike(f"%{query_str}%"))
        .order_by(Bill.created_at.desc())
        .limit(50)
        .all()
    )


def _apply_discount(bill: Bill, discount_amount: Decimal,
                     discount_percent: Decimal, subtotal: Decimal):
    """Apply discount to bill total with validation."""
    max_discount_pct = settings.MAX_DISCOUNT_PCT

    if discount_percent > 0:
        if discount_percent > max_discount_pct:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Discount cannot exceed {max_discount_pct}%",
            )
        calculated_discount = subtotal * discount_percent / Decimal("100")
        bill.discount_percent = discount_percent
        bill.discount_amount = calculated_discount
    elif discount_amount > 0:
        if discount_amount > subtotal:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Discount cannot exceed bill subtotal",
            )
        bill.discount_amount = discount_amount
        bill.discount_percent = Decimal("0")
    else:
        bill.discount_amount = Decimal("0")
        bill.discount_percent = Decimal("0")

    bill.total_amount = subtotal - bill.discount_amount
