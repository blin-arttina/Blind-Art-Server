#!/usr/bin/env bash
# get-render-logs.sh
# Fetches recent logs for a Render web service via the Render API.
# Uses the same RENDER_API_KEY env var as the other scripts.
#
# Usage:
#   bash get-render-logs.sh <service-id> [owner-id]

set -uo pipefail

SERVICE_ID="${1:-}"

if [ -z "$SERVICE_ID" ]; then
  echo "Usage: get-render-logs.sh <service-id>"
  exit 1
fi

if [ -z "${RENDER_API_KEY:-}" ]; then
  echo "RENDER_API_KEY not set — skipping."
  exit 1
fi

AUTH_HEADER="Authorization: Bearer $RENDER_API_KEY"
WORKDIR="./.tmp-render"
mkdir -p "$WORKDIR"

echo "Looking up your Render workspace..."
HTTP_STATUS=$(curl -s -o "$WORKDIR/owners.json" -w "%{http_code}" \
  -H "$AUTH_HEADER" "https://api.render.com/v1/owners")
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ] || [ "$HTTP_STATUS" != "200" ]; then
  echo "ERROR: could not fetch workspace (HTTP $HTTP_STATUS, curl exit $CURL_EXIT)."
  cat "$WORKDIR/owners.json" 2>/dev/null
  exit 1
fi

OWNER_ID=$(python3 -c "
import json
with open('$WORKDIR/owners.json') as f:
    data = json.load(f)
print(data[0]['owner']['id'] if data else '')
" 2>/dev/null)

if [ -z "$OWNER_ID" ]; then
  echo "ERROR: no workspace found."
  exit 1
fi

echo "Fetching recent logs for service '$SERVICE_ID' ..."
HTTP_STATUS=$(curl -s -o "$WORKDIR/logs.json" -w "%{http_code}" \
  -H "$AUTH_HEADER" \
  --get "https://api.render.com/v1/logs" \
  --data-urlencode "ownerId=$OWNER_ID" \
  --data-urlencode "resource=$SERVICE_ID" \
  --data-urlencode "limit=50")
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ]; then
  echo "ERROR: curl failed while fetching logs (curl exit code $CURL_EXIT)."
  exit 1
fi

if [ "$HTTP_STATUS" != "200" ]; then
  echo "ERROR: Render returned HTTP $HTTP_STATUS while fetching logs."
  cat "$WORKDIR/logs.json"
  exit 1
fi

echo ""
echo "=== Recent log lines (most relevant near the bottom) ==="
python3 -c "
import json
with open('$WORKDIR/logs.json') as f:
    data = json.load(f)
logs = data.get('logs', data if isinstance(data, list) else [])
for entry in logs:
    ts = entry.get('timestamp', '')
    msg = entry.get('message', entry)
    print(f'{ts} {msg}')
" 2>/dev/null || cat "$WORKDIR/logs.json"

rm -rf "$WORKDIR"
