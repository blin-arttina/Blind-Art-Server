#!/usr/bin/env bash
# create-render-db.sh
# Creates a free-tier PostgreSQL database on Render via the Render API.
# Uses the same RENDER_API_KEY env var as create-render-service.sh.
#
# Usage:
#   bash create-render-db.sh <db-name> [postgres-version]

set -uo pipefail

DB_NAME="${1:-}"
PG_VERSION="${2:-16}"

if [ -z "$DB_NAME" ]; then
  echo "Usage: create-render-db.sh <db-name> [postgres-version]"
  exit 1
fi

if [ -z "${RENDER_API_KEY:-}" ]; then
  echo "RENDER_API_KEY not set — skipping Render database creation."
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $RENDER_API_KEY"

# Termux has no /tmp — use a local temp folder instead
WORKDIR="./.tmp-render"
mkdir -p "$WORKDIR"

# --- Step 1: look up workspace/owner ID ---
echo "Looking up your Render workspace..."

HTTP_STATUS=$(curl -s -o "$WORKDIR/owners.json" -w "%{http_code}" \
  -H "$AUTH_HEADER" "https://api.render.com/v1/owners")
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ]; then
  echo "ERROR: curl failed while looking up your workspace (curl exit code $CURL_EXIT)."
  exit 1
fi

if [ "$HTTP_STATUS" != "200" ]; then
  echo "ERROR: Render returned HTTP $HTTP_STATUS while looking up your workspace."
  cat "$WORKDIR/owners.json"
  exit 1
fi

OWNER_ID=$(python3 -c "
import json
with open('$WORKDIR/owners.json') as f:
    data = json.load(f)
print(data[0]['owner']['id'] if data else '')
" 2>/dev/null)

if [ -z "$OWNER_ID" ]; then
  echo "ERROR: Got HTTP 200 but no workspace was found for this API key. Raw response:"
  cat "$WORKDIR/owners.json"
  exit 1
fi

# --- Step 2: create the database ---
echo "Creating Postgres database '$DB_NAME' ..."

HTTP_STATUS=$(curl -s -o "$WORKDIR/create_db.json" -w "%{http_code}" \
  -X POST "https://api.render.com/v1/postgres" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$DB_NAME\",
    \"ownerId\": \"$OWNER_ID\",
    \"plan\": \"free\",
    \"version\": \"$PG_VERSION\",
    \"region\": \"oregon\"
  }")
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ]; then
  echo "ERROR: curl failed while creating the database (curl exit code $CURL_EXIT)."
  exit 1
fi

if [ "$HTTP_STATUS" != "200" ] && [ "$HTTP_STATUS" != "201" ]; then
  echo "ERROR: Render returned HTTP $HTTP_STATUS while creating the database."
  cat "$WORKDIR/create_db.json"
  echo "You can also just create it manually in the dashboard this one time."
  exit 1
fi

DB_ID=$(python3 -c "
import json
with open('$WORKDIR/create_db.json') as f:
    data = json.load(f)
print(data.get('id', ''))
" 2>/dev/null)

if [ -z "$DB_ID" ]; then
  echo "ERROR: Got HTTP $HTTP_STATUS but no database ID was in the response. Raw response:"
  cat "$WORKDIR/create_db.json"
  echo "You can also just create it manually in the dashboard this one time."
  exit 1
fi

echo "Render Postgres database created (id: $DB_ID)."
echo ""
echo "Fetching connection details (this can take a minute while the DB provisions)..."
sleep 5

# --- Step 3: fetch connection info ---
HTTP_STATUS=$(curl -s -o "$WORKDIR/conn_info.json" -w "%{http_code}" \
  -H "$AUTH_HEADER" "https://api.render.com/v1/postgres/$DB_ID/connection-info")
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ]; then
  echo "ERROR: curl failed while fetching connection details (curl exit code $CURL_EXIT)."
  echo "The database was created (id: $DB_ID) — check the Render dashboard for the connection string."
  exit 1
fi

if [ "$HTTP_STATUS" != "200" ]; then
  echo "The database was created (id: $DB_ID), but fetching connection details returned HTTP $HTTP_STATUS."
  echo "It's likely still provisioning — check the Render dashboard for '$DB_NAME' in a minute."
  exit 0
fi

INTERNAL_URL=$(python3 -c "
import json
with open('$WORKDIR/conn_info.json') as f:
    data = json.load(f)
print(data.get('internalConnectionString', ''))
" 2>/dev/null)

if [ -z "$INTERNAL_URL" ]; then
  echo "Database created (id: $DB_ID), but the connection string isn't ready yet."
  echo "Check the Render dashboard for '$DB_NAME' in a minute or two."
  exit 0
fi

echo "Internal Database URL: $INTERNAL_URL"
echo ""
echo "Note: it may take a minute or two for the database to finish provisioning even after this URL appears."

rm -rf "$WORKDIR"
