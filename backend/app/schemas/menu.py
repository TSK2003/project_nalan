from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from decimal import Decimal


class MenuItemCreate(BaseModel):
    name: str
    category: str  # TIFFIN | LUNCH | DINNER | BEVERAGES
    price: Decimal
    description: Optional[str] = None


class MenuItemUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    price: Optional[Decimal] = None
    description: Optional[str] = None
    is_available: Optional[bool] = None


class MenuItemResponse(BaseModel):
    id: int
    name: str
    category: str
    price: Decimal
    is_available: bool
    is_deleted: bool
    description: Optional[str]
    created_at: Optional[datetime]
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True
