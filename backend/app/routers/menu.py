from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.menu_item import MenuItem
from app.models.user import User
from app.schemas.menu import MenuItemCreate, MenuItemUpdate, MenuItemResponse
from app.utils.security import get_current_user
from datetime import datetime, timezone

router = APIRouter(prefix="/api/menu", tags=["Menu"])


@router.get("", response_model=list[MenuItemResponse])
def list_menu_items(
    category: Optional[str] = None,
    available: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all menu items, optionally filtered by category and availability."""
    query = db.query(MenuItem).filter(MenuItem.is_deleted == False)

    if category:
        query = query.filter(MenuItem.category == category.upper())
    if available is not None:
        query = query.filter(MenuItem.is_available == available)

    return query.order_by(MenuItem.category, MenuItem.name).all()


@router.post("", response_model=MenuItemResponse, status_code=status.HTTP_201_CREATED)
def create_menu_item(
    item: MenuItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new menu item."""
    db_item = MenuItem(
        name=item.name,
        category=item.category.upper(),
        price=item.price,
        description=item.description,
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item


@router.put("/{item_id}", response_model=MenuItemResponse)
def update_menu_item(
    item_id: int,
    item: MenuItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update an existing menu item."""
    db_item = db.query(MenuItem).filter(MenuItem.id == item_id, MenuItem.is_deleted == False).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Menu item not found")

    update_data = item.model_dump(exclude_unset=True)
    if "category" in update_data:
        update_data["category"] = update_data["category"].upper()
    update_data["updated_at"] = datetime.now(timezone.utc)

    for key, value in update_data.items():
        setattr(db_item, key, value)

    db.commit()
    db.refresh(db_item)
    return db_item


@router.delete("/{item_id}")
def delete_menu_item(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Soft delete a menu item."""
    db_item = db.query(MenuItem).filter(MenuItem.id == item_id, MenuItem.is_deleted == False).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Menu item not found")

    db_item.is_deleted = True
    db_item.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"message": f"Menu item '{db_item.name}' deleted"}


@router.patch("/{item_id}/toggle", response_model=MenuItemResponse)
def toggle_availability(
    item_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Toggle menu item availability."""
    db_item = db.query(MenuItem).filter(MenuItem.id == item_id, MenuItem.is_deleted == False).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Menu item not found")

    db_item.is_available = not db_item.is_available
    db_item.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(db_item)
    return db_item
