"""
Blind Art Server — Phase 1 / First Build Target

Minimal FastAPI server. Goal: start the server, confirm it responds,
confirm the health check works. Nothing else is wired up yet.
"""

from fastapi import FastAPI
from server.main.config import get_settings
from server.main.database import engine, Base
from server.main import models  # noqa: F401  (registers models with Base)
from sqlalchemy.orm import Session
from fastapi import Depends, HTTPException, status
from server.main.database import get_db
from server.main.schemas import SignupRequest, LoginRequest, TokenResponse, UserResponse
from server.main.auth import hash_password, verify_password, create_access_token, get_current_user

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


@app.post("/api/auth/signup", response_model=TokenResponse)
def signup(payload: SignupRequest, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    user = models.User(email=payload.email, password_hash=hash_password(payload.password))
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)
    return TokenResponse(access_token=token)


@app.post("/api/auth/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password")

    token = create_access_token(user.id)
    return TokenResponse(access_token=token)


@app.get("/api/auth/me", response_model=UserResponse)
def get_me(current_user: models.User = Depends(get_current_user)):
    return current_user
