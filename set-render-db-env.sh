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
#
# Example (using the IDs from this project):
#   bash set-render-db-env.sh dpg-dacmiaafngtc73e0rsa0-a srv-daclsp61egvs73d3um80

set -euo pipefail

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

echo "Fetching connection info for database '$DB_ID' ..."

CONN_INFO=$(curl -s -H "$AUTH_HEADER" "https://api.render.com/v1/postgres/$DB_ID/connection-info")

DB_URL=$(echo "$CONN_INFO" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('internalConnectionString', ''))
" 2>/dev/null || echo "")

if [ -z "$DB_URL" ]; then
  echo "Could not fetch the database connection URL. Response from Render:"
  echo "$CONN_INFO"
  echo "The database may still be provisioning — wait a minute and try again."
  exit 1
fi

echo "Setting DATABASE_URL on service '$SERVICE_ID' ..."

RESPONSE=$(curl -s -X PUT "https://api.render.com/v1/services/$SERVICE_ID/env-vars" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "[
    {\"key\": \"DATABASE_URL\", \"value\": \"$DB_URL\"}
  ]")

echo "$RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        print('SUCCESS: DATABASE_URL set. Render will redeploy the service automatically.')
    else:
        print('Response from Render:')
        print(json.dumps(data, indent=2))
except Exception:
    print('Could not parse response.')
"
