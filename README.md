# Blind Art Server

Centralized, cloud-based backend for the Blind Art application ecosystem.
See `docs/` and the Master Project Outline for the full plan.

**Status:** Phase 1 — First Build Target. Minimal server with a health
check only. Database, auth, and app connections come in later phases.

## Run locally

```bash
docker compose up --build
```

Then visit http://localhost:8000/api/health — should return `{"status": "ok"}`.

## Deploy

This repo includes `render.yaml`. Connect it to [Render](https://render.com)
as a Blueprint and every push to `main` deploys automatically — no manual
steps after the first connection.
