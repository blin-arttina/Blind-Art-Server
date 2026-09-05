#!/usr/bin/env bash
# patch-config-jwt.sh
# Adds jwt_secret_key to config.py's Settings class. More tolerant of
# whitespace differences than the version bundled in setup-auth.sh.

set -uo pipefail

CONFIG_FILE="server/main/config.py"

if grep -q "jwt_secret_key" "$CONFIG_FILE"; then
  echo "$CONFIG_FILE already has jwt_secret_key — skipping."
  exit 0
fi

python3 << 'PYEOF'
path = "server/main/config.py"
with open(path) as f:
    lines = f.readlines()

out = []
found = False
for line in lines:
    out.append(line)
    if "self.database_url" in line and "DATABASE_URL" in line:
        # Match the indentation of this line exactly
        indent = line[:len(line) - len(line.lstrip())]
        out.append(f'{indent}self.jwt_secret_key = os.getenv("JWT_SECRET_KEY", "dev-only-insecure-secret-change-me")\n')
        found = True

if not found:
    print("ANCHOR NOT FOUND — no changes made. Check config.py manually.")
else:
    with open(path, "w") as f:
        f.writelines(out)
    print("SUCCESS: jwt_secret_key added to config.py")
PYEOF
