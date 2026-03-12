from datetime import datetime, timezone
from typing import Optional
from sqlalchemy.orm import Session
from app.models.bill import Bill, BillItem


def get_daily_summary(db: Session, date_str: Optional[str] = None) -> dict:
    """Get daily sales summary for a given date (default today)."""
    if date_str:
        target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    else:
        target_date = datetime.now(timezone.utc).date()

    all_bills = [
        bill for bill in db.query(Bill).all()
        if _bill_created_date(bill) == target_date
    ]
    return _build_summary_payload(
        db,
        all_bills,
        date=target_date.isoformat(),
        date_from=target_date.isoformat(),
        date_to=target_date.isoformat(),
    )


def get_range_summary(db: Session, date_from: str, date_to: str) -> dict:
    """Get sales summary for a date range."""
    from_date = datetime.strptime(date_from, "%Y-%m-%d").date()
    to_date = datetime.strptime(date_to, "%Y-%m-%d").date()

    all_bills = [
        bill
        for bill in db.query(Bill).all()
        if (created_date := _bill_created_date(bill)) is not None
        and from_date <= created_date <= to_date
    ]

    return _build_summary_payload(
        db,
        all_bills,
        date=None,
        date_from=from_date.isoformat(),
        date_to=to_date.isoformat(),
    )


def _build_summary_payload(
    db: Session,
    all_bills: list[Bill],
    *,
    date: Optional[str],
    date_from: str,
    date_to: str,
) -> dict:
    total_bills = len(all_bills)
    paid_bills = [b for b in all_bills if b.status == "PAID"]
    pending_bills = [b for b in all_bills if b.status in ("PENDING_PAYMENT", "DRAFT")]
    cancelled_bills = [b for b in all_bills if b.status == "CANCELLED"]

    total_sales = sum(float(b.total_amount) for b in paid_bills)
    cash_total = sum(
        float(b.cash_received or 0) - float(b.cash_change or 0)
        for b in paid_bills if b.payment_mode in ("CASH", "SPLIT")
    )
    upi_total = sum(
        float(b.upi_amount or 0)
        for b in paid_bills if b.payment_mode in ("UPI", "SPLIT") and b.upi_status == "SUCCESS"
    )
    split_total = sum(
        float(b.total_amount) for b in paid_bills if b.payment_mode == "SPLIT"
    )

    paid_bill_ids = [b.id for b in paid_bills]
    category_breakdown: dict[str, dict[str, float | int]] = {}
    if paid_bill_ids:
        items = db.query(BillItem).filter(BillItem.bill_id.in_(paid_bill_ids)).all()
        for item in items:
            category = item.item_category or "OTHER"
            if category not in category_breakdown:
                category_breakdown[category] = {"total": 0.0, "count": 0}
            category_breakdown[category]["total"] += float(item.line_total)
            category_breakdown[category]["count"] += item.quantity

    for category in category_breakdown:
        if total_sales > 0:
            category_breakdown[category]["percentage"] = round(
                category_breakdown[category]["total"] / total_sales * 100, 1
            )
        else:
            category_breakdown[category]["percentage"] = 0

    return {
        "date": date,
        "date_from": date_from,
        "date_to": date_to,
        "total_bills": total_bills,
        "paid_bills": len(paid_bills),
        "pending_bills": len(pending_bills),
        "cancelled_bills": len(cancelled_bills),
        "total_sales": round(total_sales, 2),
        "cash_total": round(cash_total, 2),
        "upi_total": round(upi_total, 2),
        "split_total": round(split_total, 2),
        "category_breakdown": category_breakdown,
    }


def _bill_created_date(bill: Bill):
    created_at = bill.created_at
    if created_at is None:
        return None
    return created_at.date()
