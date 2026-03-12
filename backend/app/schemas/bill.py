from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from decimal import Decimal


class BillItemCreate(BaseModel):
    menu_item_id: int
    quantity: int


class BillItemResponse(BaseModel):
    id: int
    menu_item_id: int
    item_name: str
    item_category: Optional[str]
    unit_price: Decimal
    quantity: int
    line_total: Decimal

    class Config:
        from_attributes = True


class BillCreate(BaseModel):
    items: List[BillItemCreate]
    discount_amount: Optional[Decimal] = Decimal("0")
    discount_percent: Optional[Decimal] = Decimal("0")
    discount_reason: Optional[str] = None


class BillUpdate(BaseModel):
    items: Optional[List[BillItemCreate]] = None
    discount_amount: Optional[Decimal] = None
    discount_percent: Optional[Decimal] = None
    discount_reason: Optional[str] = None


class BillResponse(BaseModel):
    id: int
    bill_number: str
    subtotal: Decimal
    discount_amount: Decimal
    discount_percent: Decimal
    total_amount: Decimal
    status: str
    payment_mode: Optional[str]
    cash_received: Optional[Decimal]
    cash_change: Optional[Decimal]
    upi_amount: Optional[Decimal]
    upi_ref_id: Optional[str]
    upi_status: Optional[str]
    upi_id_used: Optional[str] = None
    discount_reason: Optional[str]
    cashier_name: Optional[str] = None
    created_at: Optional[datetime]
    paid_at: Optional[datetime]
    cancelled_at: Optional[datetime]
    items: List[BillItemResponse] = []

    class Config:
        from_attributes = True


class BillListResponse(BaseModel):
    id: int
    bill_number: str
    total_amount: Decimal
    status: str
    payment_mode: Optional[str]
    upi_id_used: Optional[str] = None
    item_count: int = 0
    cashier_name: Optional[str] = None
    created_at: Optional[datetime]

    class Config:
        from_attributes = True
