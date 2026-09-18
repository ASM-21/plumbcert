#!/usr/bin/env bash
# Full gate: Lean proofs, axiom audit, certificate freshness, Python tests.
# Note: the study deliberately contains failing screens, so the CLI's non-zero
# exit is the expected result and is checked for explicitly.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> lake build (proofs + axiom audit)"
lake build

echo "==> grep for sorry"
if grep -rn --include='*.lean' -E '(^|[^[:alnum:]_.])sorry([^[:alnum:]_]|$)' GridCert/ GridCert.lean; then
  echo "FAIL: sorry found"; exit 1
fi
echo "    none"

echo "==> regenerate certificates and check the committed Lean matches"
cp GridCert/Examples.lean /tmp/gridcert_before.lean
set +e
(cd python && python3 -m gridcert ../examples/study.json --lean ../GridCert/Examples.lean >/dev/null)
rc=$?
set -e
if [ "$rc" -ne 1 ]; then
  echo "FAIL: expected exit 1 from a study with overloaded branches, got $rc"; exit 1
fi
if ! diff -q /tmp/gridcert_before.lean GridCert/Examples.lean >/dev/null; then
  echo "FAIL: GridCert/Examples.lean is stale"
  diff /tmp/gridcert_before.lean GridCert/Examples.lean || true
  exit 1
fi
echo "    certificates unchanged"

echo "==> rebuild the regenerated module"
lake build GridCert.Examples

echo "==> python tests"
(cd python && python3 -m unittest discover -s tests -t . -q)

echo "==> study report"
set +e
(cd python && python3 -m gridcert ../examples/study.json)
set -e

echo
echo "ALL CHECKS PASSED"
