"""
Seed script for Nalan Hotel POS database.
Creates default users and menu items.

Usage: python seed.py
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database import engine, SessionLocal, Base
from app.models.user import User
from app.models.menu_item import MenuItem
from app.models.bill import Bill, BillItem
from app.models.upi_account import UpiAccount
from app.config import get_settings
from app.utils.security import hash_password


def seed_database():
    # Create all tables
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        # Check if already seeded
        if db.query(User).first():
            print("⚠️  Database already seeded. Skipping.")
            return

        # === SEED USERS ===
        users = [
            User(
                username="admin",
                password_hash=hash_password("nalan@2024"),
                full_name="Admin",
                role="cashier",
                is_active=True,
            ),
            User(
                username="cashier1",
                password_hash=hash_password("cash@1234"),
                full_name="Ravi",
                role="cashier",
                is_active=True,
            ),
        ]
        db.add_all(users)
        db.flush()
        print(f"✅ Created {len(users)} users")
        # === SEED DEFAULT UPI ACCOUNT ===
        settings = get_settings()
        if settings.HOTEL_UPI_ID:
            existing_upi = db.query(UpiAccount).first()
            if not existing_upi:
                default_upi = UpiAccount(
                    upi_id=settings.HOTEL_UPI_ID,
                    label="Default UPI",
                    is_active=True,
                    is_default=True,
                )
                db.add(default_upi)
                db.flush()
                print(f"✅ Created default UPI account: {settings.HOTEL_UPI_ID}")

        # === SEED MENU ITEMS ===
        menu_items = [
            # TIFFIN
            MenuItem(name="Idli (2 pcs)", category="TIFFIN", price=30),
            MenuItem(name="Mini Idli (6 pcs)", category="TIFFIN", price=40),
            MenuItem(name="Masala Dosa", category="TIFFIN", price=60),
            MenuItem(name="Plain Dosa", category="TIFFIN", price=50),
            MenuItem(name="Rava Dosa", category="TIFFIN", price=65),
            MenuItem(name="Pongal", category="TIFFIN", price=40),
            MenuItem(name="Upma", category="TIFFIN", price=35),
            MenuItem(name="Vada (2 pcs)", category="TIFFIN", price=30),
            MenuItem(name="Idli + Vada Combo", category="TIFFIN", price=55),
            # LUNCH
            MenuItem(name="Meals (Full)", category="LUNCH", price=120),
            MenuItem(name="Meals (Mini)", category="LUNCH", price=80),
            MenuItem(name="Rice + Sambar", category="LUNCH", price=60),
            # DINNER
            MenuItem(name="Parotta (2 pcs)", category="DINNER", price=50),
            MenuItem(name="Parotta + Salna", category="DINNER", price=70),
            MenuItem(name="Chapati (2 pcs)", category="DINNER", price=45),
            MenuItem(name="Egg Parotta", category="DINNER", price=80),
            # BEVERAGES
            MenuItem(name="Tea", category="BEVERAGES", price=15),
            MenuItem(name="Coffee", category="BEVERAGES", price=20),
            MenuItem(name="Filter Coffee", category="BEVERAGES", price=25),
            MenuItem(name="Lemon Juice", category="BEVERAGES", price=30),
        ]
        db.add_all(menu_items)
        print(f"✅ Created {len(menu_items)} menu items")

        db.commit()
        print("\n🎉 Database seeded successfully!")
        print("\n📝 Login credentials:")
        print("   Username: admin    Password: nalan@2024")
        print("   Username: cashier1 Password: cash@1234")

    except Exception as e:
        db.rollback()
        print(f"❌ Error seeding database: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
