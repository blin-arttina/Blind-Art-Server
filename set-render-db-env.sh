#!/usr/bin/env bash
# set-render-db-env.sh
# Fetches the internal connection URL for a Render Postgres database and
# sets it as the DATABASE_URL env var on a Render web service. This
# triggers an automatic redeploy of the service with the new variable.
#
# Uses the same RENDER_API_KEY env var as create-render-service.sh /
# create-render-db.sh.
#
# Usage:
#   bash set-render-db-env.sh <db-id> <service-id>

set -uo pipefail

DB_ID="${1:-}"
SERVICE_ID="${2:-}"

if [ -z "$DB_ID" ] || [ -z "$SERVICE_ID" ]; then
  echo "Usage: set-render-db-env.sh <db-id> <service-id>"
  exit 1
fi

if [ -z "${RENDER_API_KEY:-}" ]; then
  echo "RENDER_API_KEY not set — skipping."
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $RENDER_API_KEY"

# Termux has no /tmp — use a local temp folder instead
WORKDIR="./.tmp-render"
mkdir -p "$WORKDIR"

# --- Step 1: fetch DB connection info ---
echo "Fetching connection info for database '$DB_ID' ..."

HTTP_STATUS=$(curl -s -o "$WORKDIR/conn_info.json" -w "%{http_code}" \
  -H "$AUTH_HEADER" \
  "https://api.render.com/v1/postgres/$DB_ID/connection-info")
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ]; then
  echo "ERROR: curl failed while fetching connection info (curl exit code $CURL_EXIT)."
  exit 1
fi

if [ "$HTTP_STATUS" != "200" ]; then
  echo "ERROR: Render returned HTTP $HTTP_STATUS while fetching connection info."
  echo "Response body:"
  cat "$WORKDIR/conn_info.json"
  exit 1
fi

DB_URL=$(python3 -c "
import json
with open('$WORKDIR/conn_info.json') as f:
    data = json.load(f)
print(data.get('internalConnectionString', ''))
" 2>/dev/null)

if [ -z "$DB_URL" ]; then
  echo "ERROR: Got HTTP 200 but no connection string was in the response. Raw response:"
  cat "$WORKDIR/conn_info.json"
  echo "The database may still be provisioning — wait a minute and try again."
  exit 1
fi

# --- Step 2: push it into the web service's env vars ---
echo "Setting DATABASE_URL on service '$SERVICE_ID' ..."

HTTP_STATUS=$(curl -s -o "$WORKDIR/env_response.json" -w "%{http_code}" \
  -X PUT "https://api.render.com/v1/services/$SERVICE_ID/env-vars" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "[
    {\"key\": \"DATABASE_URL\", \"value\": \"$DB_URL\"}
  ]")
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ]; then
  echo "ERROR: curl failed while setting the env var (curl exit code $CURL_EXIT)."
  exit 1
fi

if [ "$HTTP_STATUS" != "200" ] && [ "$HTTP_STATUS" != "201" ]; then
  echo "ERROR: Render returned HTTP $HTTP_STATUS while setting DATABASE_URL."
  echo "Response body:"
  cat "$WORKDIR/env_response.json"
  exit 1
fi

echo "SUCCESS: DATABASE_URL set (HTTP $HTTP_STATUS). Render will redeploy the service automatically."
echo "NOTE: this call replaces ALL env vars on the service. If you've set others (like JWT_SECRET_KEY), re-set them after this or use a merge-aware script."

rm -rf "$WORKDIR"
