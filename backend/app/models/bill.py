from sqlalchemy import Column, Integer, String, Numeric, DateTime, ForeignKey
from sqlalchemy import CheckConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class Bill(Base):
    __tablename__ = "bills"

    id = Column(Integer, primary_key=True, index=True)
    bill_number = Column(String(25), unique=True, nullable=False, index=True)
    subtotal = Column(Numeric(10, 2), nullable=False, default=0)
    discount_amount = Column(Numeric(10, 2), default=0)
    discount_percent = Column(Numeric(5, 2), default=0)
    total_amount = Column(Numeric(10, 2), nullable=False, default=0)
    status = Column(String(20), default="DRAFT", index=True)
    payment_mode = Column(String(10), nullable=True)  # CASH | UPI | SPLIT
    cash_received = Column(Numeric(10, 2), nullable=True)
    cash_change = Column(Numeric(10, 2), nullable=True)
    upi_amount = Column(Numeric(10, 2), nullable=True)
    upi_ref_id = Column(String(100), nullable=True)
    upi_status = Column(String(20), nullable=True)  # PENDING | SUCCESS | FAILED
    upi_account_id = Column(Integer, ForeignKey("upi_accounts.id"), nullable=True)
    upi_id_used = Column(String(100), nullable=True)  # snapshot of UPI ID at payment time
    discount_reason = Column(String(200), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    paid_at = Column(DateTime(timezone=True), nullable=True)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)

    items = relationship("BillItem", back_populates="bill", cascade="all, delete-orphan")
    cashier = relationship("User", lazy="joined")
    upi_account = relationship("UpiAccount", lazy="joined")


class BillItem(Base):
    __tablename__ = "bill_items"

    id = Column(Integer, primary_key=True, index=True)
    bill_id = Column(Integer, ForeignKey("bills.id"), nullable=False)
    menu_item_id = Column(Integer, ForeignKey("menu_items.id"), nullable=False)
    item_name = Column(String(100), nullable=False)  # snapshot
    item_category = Column(String(20), nullable=True)
    unit_price = Column(Numeric(8, 2), nullable=False)  # snapshot
    quantity = Column(Integer, nullable=False)
    line_total = Column(Numeric(10, 2), nullable=False)

    bill = relationship("Bill", back_populates="items")
