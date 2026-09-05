"""
Blind Art Server — configuration

Reads settings from environment variables so nothing sensitive is
hard-coded. Copy .env.example to .env locally; on Render, set these
as environment variables in the dashboard instead.
"""

import os
from functools import lru_cache


class Settings:
    def __init__(self):
        self.environment = os.getenv("ENVIRONMENT", "development")
        self.port = int(os.getenv("PORT", "8000"))
        # Placeholder for Phase 2 — not used yet.
        self.database_url = os.getenv("DATABASE_URL", "")
        self.jwt_secret_key = os.getenv("JWT_SECRET_KEY", "dev-only-insecure-secret-change-me")


@lru_cache
def get_settings() -> Settings:
    return Settings()
