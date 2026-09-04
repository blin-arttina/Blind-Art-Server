#!/usr/bin/env bash
# cleanup-repo.sh
# Organizes the Render/Termux utility scripts that ended up scattered
# in the repo root (and one stray copy inside server/) into a single
# scripts/ folder, removes duplicate downloads (files with "(1)", "(2)"
# etc. in the name), and adds a .gitignore rule so future duplicate
# downloads don't get committed by accident.
#
# Safe to re-run.

set -uo pipefail

mkdir -p scripts

echo "Moving utility scripts into scripts/ ..."

# Known utility scripts that belong in scripts/, wherever they currently are
KNOWN_SCRIPTS=(
  "create-render-service.sh"
  "create-render-db.sh"
  "set-render-db-env.sh"
  "set-render-key.sh"
  "setup-database.sh"
  "push-project.sh"
)

for name in "${KNOWN_SCRIPTS[@]}"; do
  # Root copy
  if [ -f "$name" ]; then
    mv -v "$name" "scripts/$name"
  fi
  # Stray copy inside server/ (or anywhere else one level down)
  found=$(find . -maxdepth 3 -name "$name" -not -path "./scripts/*" 2>/dev/null)
  if [ -n "$found" ]; then
    while IFS= read -r f; do
      echo "Removing stray duplicate: $f"
      rm -v "$f"
    done <<< "$found"
  fi
done

echo ""
echo "Removing duplicate downloads (files with '(1)', '(2)', etc. in the name) ..."
find . -maxdepth 2 -regextype posix-extended -regex '.*\([0-9]+\)\.sh$' -not -path "./scripts/*" -print -delete

echo ""
echo "Adding .gitignore rule to prevent future duplicate-download clutter ..."
if ! grep -q '\* ([0-9]*).sh' .gitignore 2>/dev/null; then
  {
    echo ""
    echo "# Duplicate downloads (e.g. 'script (1).sh') — clean these up, don't commit them"
    echo "* ([0-9]*).sh"
  } >> .gitignore
  echo "Added rule to .gitignore"
else
  echo ".gitignore rule already present — skipping"
fi

echo ""
echo "Done. Current scripts/ contents:"
ls -la scripts/
echo ""
echo "Review with 'git status' and 'git diff', then commit and push when ready, e.g.:"
echo "  git add -A"
echo "  git commit -m \"Organize utility scripts into scripts/, remove duplicate downloads\""
echo "  git push"
