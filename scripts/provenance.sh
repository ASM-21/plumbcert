#!/usr/bin/env bash
# Emit a provenance record for a findings run: what code, what data, what tools.
# The input digests are of the parsed slice each tool actually consumes, not of
# the file on disk, so reformatting the JSON does not change them.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "plumbcert provenance"
echo "generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "commit:    $(git rev-parse HEAD 2>/dev/null || echo '(no commits)')"
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "dirty:     YES -- results are not reproducible from a commit"
  else
    echo "dirty:     no"
  fi
else
  echo "commit:    (not a git repository)"
fi
echo "lean:      $(lean --version 2>/dev/null || echo 'not found')"
echo "python:    $(python3 --version 2>&1)"
echo "platform:  $(uname -srm)"
echo
echo "input digests (of the parsed slice, not the file):"
python3 - <<'PY'
import hashlib, json, pathlib
for f in sorted(pathlib.Path('.').glob('*/examples/*.json')):
    try:
        parsed = json.loads(f.read_text())
        canon = json.dumps(parsed, sort_keys=True, separators=(',', ':')).encode()
        print(f"  {hashlib.sha256(canon).hexdigest()[:16]}  {f}")
    except Exception as e:
        print(f"  UNPARSEABLE      {f}: {e}")
PY
