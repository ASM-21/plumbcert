#!/usr/bin/env bash
# Rebrand the whole repo in one command, in case you want a different name.
#   ./scripts/rename.sh newname "New Tagline"
# Renames every occurrence of the project name in docs and metadata. It does not
# touch the five subprojects, whose names (TolStack, DimCert, LyapCert,
# CarbonSched, GridCert) are independent of the umbrella brand.
set -euo pipefail
cd "$(dirname "$0")/.."
NEW="${1:?usage: rename.sh <newname> [tagline]}"
OLD="plumbcert"
grep -rl --include='*.md' --include='*.cff' --include='*.yml' "$OLD" . \
  | xargs sed -i "s/\b$OLD\b/$NEW/g"
echo "renamed $OLD -> $NEW in docs and metadata"
echo "remaining references (should be none):"
grep -rn --include='*.md' --include='*.cff' "\b$OLD\b" . || echo "  none"
echo
echo "Now rename the directory and the GitHub repo to match."
