# Server Setup — Blind Art Server

## First Success Test (Phase 1 goal)

1. Start the server locally: `docker compose up --build`
2. Open http://localhost:8000
3. Open http://localhost:8000/api/health — confirm it returns `{"status": "ok"}`

That's the whole Phase 1 target. Nothing else needs to work yet.

## Getting this onto GitHub

```bash
git init
git add .
git commit -m "Phase 1: server foundation"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/Blind-Art-Server.git
git push -u origin main
```

## Connecting Render for automatic deploys

1. Sign up at https://render.com (GitHub login is easiest).
2. Dashboard → **New** → **Blueprint**.
3. Connect the `Blind-Art-Server` GitHub repo.
4. Render reads `render.yaml` automatically and creates the web service.
5. Click **Apply**.

From this point on: every `git push` to `main` triggers a new build and
deploy automatically. No dashboard clicks needed after step 5.

## Notes

- Free tier spins the service down after 15 minutes with no traffic and
  wakes it back up (takes ~30–60 seconds) on the next request. Fine for
  Phase 1–2 development; revisit if the review/project apps need it to
  always be instantly responsive.
- `DATABASE_URL` is a placeholder until Phase 2 — leave it blank.
