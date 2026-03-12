from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from app.database import Base


class UpiAccount(Base):
    __tablename__ = "upi_accounts"

    id = Column(Integer, primary_key=True, index=True)
    upi_id = Column(String(100), nullable=False)  # e.g. nalanhotel@okicici
    label = Column(String(50), nullable=False)     # e.g. "ICICI UPI"
    is_active = Column(Boolean, default=True)
    is_default = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
