from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.models.upi_account import UpiAccount
from app.schemas.upi_account import UpiAccountCreate, UpiAccountUpdate, UpiAccountResponse
from app.utils.security import get_current_user
from datetime import datetime, timezone

router = APIRouter(prefix="/api/upi-accounts", tags=["UPI Accounts"])

MAX_UPI_ACCOUNTS = 3


@router.get("", response_model=list[UpiAccountResponse])
def list_upi_accounts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all active UPI accounts."""
    return (
        db.query(UpiAccount)
        .filter(UpiAccount.is_active == True)
        .order_by(UpiAccount.is_default.desc(), UpiAccount.created_at)
        .all()
    )


@router.post("", response_model=UpiAccountResponse, status_code=201)
def create_upi_account(
    data: UpiAccountCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new UPI account. Maximum 3 active accounts allowed."""
    active_count = db.query(UpiAccount).filter(UpiAccount.is_active == True).count()
    if active_count >= MAX_UPI_ACCOUNTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Maximum {MAX_UPI_ACCOUNTS} UPI accounts allowed. "
                   f"Please deactivate an existing account first.",
        )

    # Check for duplicate UPI ID
    existing = (
        db.query(UpiAccount)
        .filter(UpiAccount.upi_id == data.upi_id, UpiAccount.is_active == True)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"UPI ID '{data.upi_id}' is already registered.",
        )

    # If this is the first account, make it default
    is_first = active_count == 0

    account = UpiAccount(
        upi_id=data.upi_id,
        label=data.label,
        is_default=is_first,
    )
    db.add(account)
    db.commit()
    db.refresh(account)
    return account


@router.put("/{account_id}", response_model=UpiAccountResponse)
def update_upi_account(
    account_id: int,
    data: UpiAccountUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update an existing UPI account's ID or label."""
    account = (
        db.query(UpiAccount)
        .filter(UpiAccount.id == account_id, UpiAccount.is_active == True)
        .first()
    )
    if not account:
        raise HTTPException(status_code=404, detail="UPI account not found")

    update_data = data.model_dump(exclude_unset=True)

    # Check for duplicate UPI ID if changing it
    if "upi_id" in update_data and update_data["upi_id"] != account.upi_id:
        existing = (
            db.query(UpiAccount)
            .filter(
                UpiAccount.upi_id == update_data["upi_id"],
                UpiAccount.is_active == True,
                UpiAccount.id != account_id,
            )
            .first()
        )
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"UPI ID '{update_data['upi_id']}' is already registered.",
            )

    for key, value in update_data.items():
        setattr(account, key, value)

    account.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(account)
    return account


@router.delete("/{account_id}")
def delete_upi_account(
    account_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Deactivate a UPI account (soft delete)."""
    account = (
        db.query(UpiAccount)
        .filter(UpiAccount.id == account_id, UpiAccount.is_active == True)
        .first()
    )
    if not account:
        raise HTTPException(status_code=404, detail="UPI account not found")

    was_default = account.is_default
    account.is_active = False
    account.is_default = False
    account.updated_at = datetime.now(timezone.utc)

    # If this was the default, promote another account
    if was_default:
        next_default = (
            db.query(UpiAccount)
            .filter(UpiAccount.is_active == True, UpiAccount.id != account_id)
            .order_by(UpiAccount.created_at)
            .first()
        )
        if next_default:
            next_default.is_default = True

    db.commit()
    return {"message": f"UPI account '{account.label}' deactivated"}


@router.patch("/{account_id}/default", response_model=UpiAccountResponse)
def set_default_upi_account(
    account_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Set a UPI account as the default."""
    account = (
        db.query(UpiAccount)
        .filter(UpiAccount.id == account_id, UpiAccount.is_active == True)
        .first()
    )
    if not account:
        raise HTTPException(status_code=404, detail="UPI account not found")

    # Unset existing default
    db.query(UpiAccount).filter(
        UpiAccount.is_active == True, UpiAccount.is_default == True
    ).update({"is_default": False})

    account.is_default = True
    db.commit()
    db.refresh(account)
    return account
