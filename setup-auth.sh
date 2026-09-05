#!/usr/bin/env bash
# setup-auth.sh
# Adds JWT-based authentication (signup, login, password hashing,
# current-user dependency) to the Blind Art Server FastAPI app.
# Safe to re-run — skips steps already applied.

set -uo pipefail

AUTH_FILE="server/main/auth.py"
SCHEMAS_FILE="server/main/schemas.py"
CONFIG_FILE="server/main/config.py"
SERVER_FILE="server/main/server.py"
REQ_FILE="requirements.txt"

# --- 1. schemas.py ---
if [ -f "$SCHEMAS_FILE" ]; then
  echo "$SCHEMAS_FILE already exists — skipping."
else
  cat > "$SCHEMAS_FILE" << 'PYEOF'
"""
Blind Art Server — request/response schemas for auth endpoints.
"""

from pydantic import BaseModel, EmailStr


class SignupRequest(BaseModel):
    email: EmailStr
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    id: int
    email: EmailStr

    class Config:
        from_attributes = True
PYEOF
  echo "Created $SCHEMAS_FILE"
fi

# --- 2. auth.py ---
if [ -f "$AUTH_FILE" ]; then
  echo "$AUTH_FILE already exists — skipping."
else
  cat > "$AUTH_FILE" << 'PYEOF'
"""
Blind Art Server — authentication

Password hashing (bcrypt) and JWT creation/verification. Multiple
Blind Art apps (Music Studio, Animation Studio, AI App Builder,
Avatar App) will send this token on every request to prove who the
user is.
"""

from datetime import datetime, timedelta

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from server.main.config import get_settings
from server.main.database import get_db
from server.main import models

settings = get_settings()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 1 week


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, password_hash: str) -> bool:
    return pwd_context.verify(plain_password, password_hash)


def create_access_token(user_id: int) -> str:
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": str(user_id), "exp": expire}
    return jwt.encode(payload, settings.jwt_secret_key, algorithm="HS256")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> models.User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=["HS256"])
        user_id = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(models.User).filter(models.User.id == int(user_id)).first()
    if user is None:
        raise credentials_exception
    return user
PYEOF
  echo "Created $AUTH_FILE"
fi

# --- 3. patch config.py for JWT_SECRET_KEY ---
if grep -q "jwt_secret_key" "$CONFIG_FILE"; then
  echo "$CONFIG_FILE already has jwt_secret_key — skipping."
else
  python3 << PYEOF
path = "$CONFIG_FILE"
with open(path) as f:
    content = f.read()

old = '            self.database_url = os.getenv("DATABASE_URL", "")'
new = '''            self.database_url = os.getenv("DATABASE_URL", "")
            self.jwt_secret_key = os.getenv("JWT_SECRET_KEY", "dev-only-insecure-secret-change-me")'''

if old not in content:
    print("ANCHOR NOT FOUND in config.py — no changes made")
else:
    content = content.replace(old, new, 1)
    with open(path, "w") as f:
        f.write(content)
    print("SUCCESS: jwt_secret_key added to config.py")
PYEOF
fi

# --- 4. patch server.py ---
if grep -q "api/auth/signup" "$SERVER_FILE"; then
  echo "$SERVER_FILE already has auth endpoints — skipping."
else
  python3 << PYEOF
path = "$SERVER_FILE"
with open(path) as f:
    content = f.read()

old_import = 'from server.main import models  # noqa: F401  (registers models with Base)'
new_import = '''from server.main import models  # noqa: F401  (registers models with Base)
from sqlalchemy.orm import Session
from fastapi import Depends, HTTPException, status
from server.main.database import get_db
from server.main.schemas import SignupRequest, LoginRequest, TokenResponse, UserResponse
from server.main.auth import hash_password, verify_password, create_access_token, get_current_user'''

if old_import not in content:
    print("ANCHOR NOT FOUND for imports — no changes made")
else:
    content = content.replace(old_import, new_import, 1)

    addition = '''

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
'''
    content = content.rstrip() + "\n" + addition

    with open(path, "w") as f:
        f.write(content)
    print("SUCCESS: server.py wired with auth endpoints")
PYEOF
fi

# --- 5. requirements.txt ---
touch "$REQ_FILE"
ADDED=""
for pkg in "passlib[bcrypt]" "python-jose[cryptography]" "python-multipart" "email-validator"; do
  base_name=$(echo "$pkg" | sed 's/\[.*\]//')
  if ! grep -qi "^${base_name}" "$REQ_FILE"; then
    echo "$pkg" >> "$REQ_FILE"
    ADDED="$ADDED $pkg"
  fi
done
if [ -n "$ADDED" ]; then
  echo "Added to requirements.txt:$ADDED"
else
  echo "requirements.txt already has the auth dependencies."
fi

echo ""
echo "Done. Note: JWT_SECRET_KEY falls back to an insecure dev value until you set it on Render."
echo "Review changes with 'git diff', then commit and push when ready."
