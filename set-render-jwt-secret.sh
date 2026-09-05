#!/usr/bin/env bash
# set-render-jwt-secret.sh
# Generates a secure random JWT_SECRET_KEY and sets it as an env var
# on a Render web service, preserving existing env vars. Uses the same
# RENDER_API_KEY auth pattern as the other scripts.
#
# Usage:
#   bash set-render-jwt-secret.sh <service-id>

set -uo pipefail

SERVICE_ID="${1:-}"

if [ -z "$SERVICE_ID" ]; then
  echo "Usage: set-render-jwt-secret.sh <service-id>"
  exit 1
fi

if [ -z "${RENDER_API_KEY:-}" ]; then
  echo "RENDER_API_KEY not set — skipping."
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $RENDER_API_KEY"

# Termux has no /tmp — use a local temp folder instead
TMPDIR="./.tmp-render"
mkdir -p "$TMPDIR"

SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(48))")

echo "Fetching existing env vars on service '$SERVICE_ID' ..."

HTTP_STATUS=$(curl -s -o "$TMPDIR/existing_env.json" -w "%{http_code}" \
  -H "$AUTH_HEADER" \
  "https://api.render.com/v1/services/$SERVICE_ID/env-vars")
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ] || [ "$HTTP_STATUS" != "200" ]; then
  echo "ERROR: could not fetch existing env vars (HTTP $HTTP_STATUS, curl exit $CURL_EXIT)."
  echo "Response body:"
  cat "$TMPDIR/existing_env.json" 2>/dev/null
  exit 1
fi

python3 << PYEOF
import json

with open("$TMPDIR/existing_env.json") as f:
    existing = json.load(f)

env_vars = {}
for item in existing:
    ev = item.get("envVar", item)
    key = ev.get("key")
    value = ev.get("value")
    if key:
        env_vars[key] = value

env_vars["JWT_SECRET_KEY"] = "$SECRET"

payload = [{"key": k, "value": v} for k, v in env_vars.items()]
with open("$TMPDIR/merged_env.json", "w") as f:
    json.dump(payload, f)

print("Existing keys found:", list(env_vars.keys()))
PYEOF

echo "Setting JWT_SECRET_KEY (and preserving the above keys) ..."

HTTP_STATUS=$(curl -s -o "$TMPDIR/set_response.json" -w "%{http_code}" \
  -X PUT "https://api.render.com/v1/services/$SERVICE_ID/env-vars" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  --data "@$TMPDIR/merged_env.json")
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ]; then
  echo "ERROR: curl failed while setting env vars (curl exit code $CURL_EXIT)."
  exit 1
fi

if [ "$HTTP_STATUS" != "200" ] && [ "$HTTP_STATUS" != "201" ]; then
  echo "ERROR: Render returned HTTP $HTTP_STATUS while setting JWT_SECRET_KEY."
  echo "Response body:"
  cat "$TMPDIR/set_response.json"
  exit 1
fi

echo "SUCCESS: JWT_SECRET_KEY set (existing env vars preserved). Render will redeploy automatically."

# Clean up
rm -rf "$TMPDIR"
