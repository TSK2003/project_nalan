from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database import active_database_url
from app.main import health_check, root


def test_root_endpoint_reports_service_metadata() -> None:
    assert root() == {
        "app": "Nalan Hotel POS API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
        "database": active_database_url,
    }


def test_health_endpoint_reports_healthy() -> None:
    assert health_check() == {
        "status": "healthy",
        "database": active_database_url,
    }
