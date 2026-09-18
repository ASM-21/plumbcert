#!/usr/bin/env bash
# Full verification gate: Lean proofs, axiom audit, Python parity and property
# tests, and the JSON -> Lean -> kernel-check round trip.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> lake build (proofs + axiom audit)"
lake build

echo "==> grep for sorry"
if grep -rn --include='*.lean' -E '(^|[^[:alnum:]_.])sorry([^[:alnum:]_]|$)' TolStack/ TolStack.lean; then
  echo "FAIL: sorry found"; exit 1
fi
echo "    none"

echo "==> regenerate golden report from Lean"
cat > /tmp/tolstack_golden.lean <<'EOF'
import TolStack
open TolStack TolStack.Examples
def main : IO Unit := IO.print (report axialGap 250 600)
EOF
lake env lean --run /tmp/tolstack_golden.lean > /tmp/tolstack_golden.txt
if ! diff -q /tmp/tolstack_golden.txt python/tests/golden/axial_gap_report.txt >/dev/null; then
  echo "FAIL: Lean report drifted from the golden file"
  diff /tmp/tolstack_golden.txt python/tests/golden/axial_gap_report.txt || true
  exit 1
fi
echo "    golden report matches"

echo "==> python tests"
(cd python && python3 -m unittest discover -s tests -t . -q)

echo "==> CLI on the worked example"
(cd python && python3 -m tolstack ../examples/axial_gap.json)

echo
echo "ALL CHECKS PASSED"
