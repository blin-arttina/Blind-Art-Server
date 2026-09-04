#!/usr/bin/env bash
# create-render-db.sh
# Creates a free-tier PostgreSQL database on Render via the Render API.
# Uses the same RENDER_API_KEY env var as create-render-service.sh.
#
# Usage:
#   bash create-render-db.sh <db-name> [postgres-version]
#
# Example:
#   bash create-render-db.sh blind-art-db

set -euo pipefail

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

echo "Looking up your Render workspace..."
OWNER_ID=$(curl -s -H "$AUTH_HEADER" "https://api.render.com/v1/owners" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if not data:
    print('')
else:
    print(data[0]['owner']['id'])
")

if [ -z "$OWNER_ID" ]; then
  echo "Could not find a Render workspace for this API key. Check RENDER_API_KEY."
  exit 1
fi

echo "Creating Postgres database '$DB_NAME' ..."

RESPONSE=$(curl -s -X POST "https://api.render.com/v1/postgres" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$DB_NAME\",
    \"ownerId\": \"$OWNER_ID\",
    \"plan\": \"free\",
    \"version\": \"$PG_VERSION\",
    \"region\": \"oregon\"
  }")

DB_ID=$(echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('id', ''))
" 2>/dev/null || echo "")

if [ -z "$DB_ID" ]; then
  echo "Something went wrong creating the database. Response from Render:"
  echo "$RESPONSE"
  echo "You can also just create it manually in the dashboard this one time."
  exit 1
fi

echo "Render Postgres database created (id: $DB_ID)."
echo ""
echo "Fetching connection details (this can take a minute while the DB provisions)..."
sleep 5

CONN_INFO=$(curl -s -H "$AUTH_HEADER" "https://api.render.com/v1/postgres/$DB_ID/connection-info")

INTERNAL_URL=$(echo "$CONN_INFO" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('internalConnectionString', 'not ready yet — check the Render dashboard'))
" 2>/dev/null || echo "not ready yet — check the Render dashboard")

echo "Internal Database URL: $INTERNAL_URL"
echo ""
echo "Note: it may take a minute or two for the database to finish provisioning."
echo "If the URL above says 'not ready yet', check the Render dashboard for '$DB_NAME' directly."
