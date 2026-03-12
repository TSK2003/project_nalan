from sqlalchemy import Column, Integer, String, Boolean, Numeric, Text, DateTime
from sqlalchemy.sql import func
from app.database import Base


class MenuItem(Base):
    __tablename__ = "menu_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    category = Column(String(20), nullable=False, index=True)
    price = Column(Numeric(8, 2), nullable=False)
    is_available = Column(Boolean, default=True)
    is_deleted = Column(Boolean, default=False)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
