"""
Blind Art Server — Phase 1 / First Build Target

Minimal FastAPI server. Goal: start the server, confirm it responds,
confirm the health check works. Nothing else is wired up yet.
"""

from fastapi import FastAPI
from server.main.config import get_settings

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
