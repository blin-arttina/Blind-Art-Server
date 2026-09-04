#!/usr/bin/env bash
# setup-database.sh
# Adds SQLAlchemy database setup (engine, session, models) to the
# Blind Art Server FastAPI app and wires table creation + a DB health
# check into server.py. Safe to re-run — skips steps already applied.

set -uo pipefail

DB_FILE="server/main/database.py"
MODELS_FILE="server/main/models.py"
SERVER_FILE="server/main/server.py"
REQ_FILE="requirements.txt"

# --- 1. database.py ---
if [ -f "$DB_FILE" ]; then
  echo "$DB_FILE already exists — skipping (delete it first if you want it regenerated)."
else
  cat > "$DB_FILE" << 'PYEOF'
"""
Blind Art Server — database setup

Creates the SQLAlchemy engine and session factory from DATABASE_URL
(see config.py). Import get_db as a FastAPI dependency to get a
request-scoped session.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

from server.main.config import get_settings

settings = get_settings()

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
PYEOF
  echo "Created $DB_FILE"
fi

# --- 2. models.py ---
if [ -f "$MODELS_FILE" ]; then
  echo "$MODELS_FILE already exists — skipping (delete it first if you want it regenerated)."
else
  cat > "$MODELS_FILE" << 'PYEOF'
"""
Blind Art Server — database models

Core tables shared across all Blind Art apps (Music Studio, Animation
Studio, AI App Builder, Avatar App).
"""

from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from server.main.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    projects = relationship("Project", back_populates="owner")


class Project(Base):
    __tablename__ = "projects"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    filename = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    owner = relationship("User", back_populates="projects")
PYEOF
  echo "Created $MODELS_FILE"
fi

# --- 3. patch server.py ---
if grep -q "server.main.database" "$SERVER_FILE"; then
  echo "$SERVER_FILE already wired to the database — skipping."
else
  python3 << PYEOF
path = "$SERVER_FILE"
with open(path) as f:
    content = f.read()

# Add imports after the existing config import
old_import = 'from server.main.config import get_settings'
new_import = '''from server.main.config import get_settings
from server.main.database import engine, Base
from server.main import models  # noqa: F401  (registers models with Base)'''

if old_import not in content:
    print("ANCHOR NOT FOUND for imports — no changes made")
else:
    content = content.replace(old_import, new_import, 1)

    # Add table creation + db health check at the end of the file
    addition = '''

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
'''
    content = content.rstrip() + "\n" + addition

    with open(path, "w") as f:
        f.write(content)
    print("SUCCESS: server.py wired to the database")
PYEOF
fi

# --- 4. requirements.txt ---
touch "$REQ_FILE"
ADDED=""
for pkg in sqlalchemy psycopg2-binary; do
  if ! grep -qi "^${pkg}" "$REQ_FILE"; then
    echo "$pkg" >> "$REQ_FILE"
    ADDED="$ADDED $pkg"
  fi
done
if [ -n "$ADDED" ]; then
  echo "Added to requirements.txt:$ADDED"
else
  echo "requirements.txt already has sqlalchemy and psycopg2-binary."
fi

echo ""
echo "Done. Review the changes with 'git diff', then commit and push when ready."
