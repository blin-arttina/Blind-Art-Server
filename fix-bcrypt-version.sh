#!/usr/bin/env bash
# fix-bcrypt-version.sh
# Pins bcrypt to a version compatible with passlib (bcrypt>=4.1 breaks
# passlib's internal self-test with a ValueError about 72-byte limits).

set -uo pipefail

REQ_FILE="requirements.txt"

if grep -q "^bcrypt" "$REQ_FILE"; then
  echo "bcrypt already pinned in requirements.txt — updating version..."
  sed -i 's/^bcrypt.*/bcrypt==4.0.1/' "$REQ_FILE"
else
  echo "bcrypt==4.0.1" >> "$REQ_FILE"
fi

echo "Done. requirements.txt now pins bcrypt==4.0.1 (compatible with passlib)."
echo "Review with 'cat requirements.txt', then commit and push."
