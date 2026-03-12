from pathlib import Path

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.config import get_settings

settings = get_settings()

_backend_dir = Path(__file__).resolve().parents[1]
_sqlite_fallback_url = f"sqlite:///{_backend_dir / 'nalan_pos.db'}"


def _create_engine(database_url: str):
    connect_args = {}
    if database_url.startswith("sqlite"):
        connect_args["check_same_thread"] = False

    return create_engine(
        database_url,
        pool_pre_ping=not database_url.startswith("sqlite"),
        connect_args=connect_args,
    )


def _build_engine():
    primary_url = settings.DATABASE_URL
    try:
        primary_engine = _create_engine(primary_url)
        with primary_engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return primary_engine, primary_url
    except Exception as exc:
        fallback_engine = _create_engine(_sqlite_fallback_url)
        with fallback_engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        print(
            f"[database] Falling back to SQLite because '{primary_url}' "
            f"is unavailable: {exc}"
        )
        return fallback_engine, _sqlite_fallback_url


engine, active_database_url = _build_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    """Dependency that provides a database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
