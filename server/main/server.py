"""
Blind Art Server — Phase 1 / First Build Target

Minimal FastAPI server. Goal: start the server, confirm it responds,
confirm the health check works. Nothing else is wired up yet.
"""

from fastapi import FastAPI
from server.main.config import get_settings
from server.main.database import engine, Base
from server.main import models  # noqa: F401  (registers models with Base)

settings = get_settings()

app = FastAPI(
    title="Blind Art Server",
    description="Centralized backend for the Blind Art application ecosystem.",
    version="0.1.0",
)


@app.get("/")
def root():
    return {
        "service": "Blind Art Server",
        "status": "online",
        "version": "0.1.0",
    }


@app.get("/api/health")
def health_check():
    """First success test target: this must return 200 OK."""
    return {"status": "ok"}


# Create tables on startup (Phase 2: minimal setup, no migrations yet)
Base.metadata.create_all(bind=engine)


@app.get("/api/db-health")
def db_health_check():
    """Confirms the app can talk to the database."""
    try:
        with engine.connect() as conn:
            conn.exec_driver_sql("SELECT 1")
        return {"status": "ok", "database": "connected"}
    except Exception as e:
        return {"status": "error", "database": "unreachable", "detail": str(e)}
