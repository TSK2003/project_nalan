from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import Base, SessionLocal, engine
from app.models import Bill, BillItem, MenuItem, UpiAccount, User
from app.utils.security import hash_password

settings = get_settings()

_default_menu_items = [
    ("Idli (2 pcs)", "TIFFIN", 30),
    ("Mini Idli (6 pcs)", "TIFFIN", 40),
    ("Masala Dosa", "TIFFIN", 60),
    ("Plain Dosa", "TIFFIN", 50),
    ("Rava Dosa", "TIFFIN", 65),
    ("Pongal", "TIFFIN", 40),
    ("Upma", "TIFFIN", 35),
    ("Vada (2 pcs)", "TIFFIN", 30),
    ("Idli + Vada Combo", "TIFFIN", 55),
    ("Meals (Full)", "LUNCH", 120),
    ("Meals (Mini)", "LUNCH", 80),
    ("Rice + Sambar", "LUNCH", 60),
    ("Parotta (2 pcs)", "DINNER", 50),
    ("Parotta + Salna", "DINNER", 70),
    ("Chapati (2 pcs)", "DINNER", 45),
    ("Egg Parotta", "DINNER", 80),
    ("Tea", "BEVERAGES", 15),
    ("Coffee", "BEVERAGES", 20),
    ("Filter Coffee", "BEVERAGES", 25),
    ("Lemon Juice", "BEVERAGES", 30),
]


def ensure_database_ready() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        _seed_defaults(db)
        db.commit()
    finally:
        db.close()


def _seed_defaults(db: Session) -> None:
    if db.query(User).count() == 0:
        db.add_all(
            [
                User(
                    username="store_admin",
                    password_hash=hash_password("store_admin"),
                    full_name="Store Admin",
                    role="cashier",
                    is_active=True,
                ),
                User(
                    username="cashier1",
                    password_hash=hash_password("cash@1234"),
                    full_name="Cashier 1",
                    role="cashier",
                    is_active=True,
                ),
            ]
        )

    if settings.HOTEL_UPI_ID and db.query(UpiAccount).count() == 0:
        db.add(
            UpiAccount(
                upi_id=settings.HOTEL_UPI_ID,
                label="Default UPI",
                is_active=True,
                is_default=True,
            )
        )

    if db.query(MenuItem).count() == 0:
        db.add_all(
            [
                MenuItem(name=name, category=category, price=price)
                for name, category, price in _default_menu_items
            ]
        )
