#!/usr/bin/env bash
# Full verification gate: Lean proofs, axiom audit, Lean/Python report parity,
# property tests, and the JSON -> Lean -> kernel-check round trip.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> lake build (proofs + axiom audit)"
lake build

echo "==> grep for sorry"
if grep -rn --include='*.lean' -E '(^|[^[:alnum:]_.])sorry([^[:alnum:]_]|$)' DimCert/ DimCert.lean; then
  echo "FAIL: sorry found"; exit 1
fi
echo "    none"

echo "==> regenerate library report from Lean"
cat > /tmp/dimcert_golden.lean <<'EOF'
import DimCert
def main : IO Unit := IO.print DimCert.libraryReport
EOF
lake env lean --run /tmp/dimcert_golden.lean > /tmp/dimcert_golden.txt
if ! diff -q /tmp/dimcert_golden.txt python/tests/golden/library_report.txt >/dev/null; then
  echo "FAIL: Lean report drifted from the golden file"
  diff /tmp/dimcert_golden.txt python/tests/golden/library_report.txt || true
  exit 1
fi
echo "    golden report matches"

echo "==> python tests"
(cd python && python3 -m unittest discover -s tests -t . -q)

echo "==> CLI on the interconnection example (expected to flag one formula)"
set +e
(cd python && python3 -m dimcert ../examples/interconnection.json)
rc=$?
set -e
if [ "$rc" -ne 1 ]; then
  echo "FAIL: expected exit code 1 from the example with a bad formula, got $rc"; exit 1
fi

echo
echo "ALL CHECKS PASSED"
