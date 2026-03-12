from pydantic import BaseModel, field_validator
from typing import Optional
from datetime import datetime
import re


class UpiAccountCreate(BaseModel):
    upi_id: str
    label: str

    @field_validator("upi_id")
    @classmethod
    def validate_upi_id(cls, v: str) -> str:
        v = v.strip()
        if not re.match(r"^[\w.\-]+@[\w]+$", v):
            raise ValueError("Invalid UPI ID format. Expected format: name@bank")
        return v

    @field_validator("label")
    @classmethod
    def validate_label(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 2:
            raise ValueError("Label must be at least 2 characters")
        if len(v) > 50:
            raise ValueError("Label must be 50 characters or less")
        return v


class UpiAccountUpdate(BaseModel):
    upi_id: Optional[str] = None
    label: Optional[str] = None

    @field_validator("upi_id")
    @classmethod
    def validate_upi_id(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        v = v.strip()
        if not re.match(r"^[\w.\-]+@[\w]+$", v):
            raise ValueError("Invalid UPI ID format. Expected format: name@bank")
        return v


class UpiAccountResponse(BaseModel):
    id: int
    upi_id: str
    label: str
    is_active: bool
    is_default: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
