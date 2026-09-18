#!/usr/bin/env bash
# Full gate: Lean proofs, axiom audit, certificate freshness, Python tests.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> lake build (proofs + axiom audit)"
lake build

echo "==> grep for sorry"
if grep -rn --include='*.lean' -E '(^|[^[:alnum:]_.])sorry([^[:alnum:]_]|$)' LyapCert/ LyapCert.lean; then
  echo "FAIL: sorry found"; exit 1
fi
echo "    none"

echo "==> regenerate certificates and check the committed Lean matches"
cp LyapCert/Examples.lean /tmp/lyapcert_examples_before.lean
(cd python && python3 -m lyapcert ../examples/systems.json --lean ../LyapCert/Examples.lean >/dev/null)
if ! diff -q /tmp/lyapcert_examples_before.lean LyapCert/Examples.lean >/dev/null; then
  echo "FAIL: LyapCert/Examples.lean is stale; the solver now produces different certificates"
  diff /tmp/lyapcert_examples_before.lean LyapCert/Examples.lean || true
  exit 1
fi
echo "    certificates unchanged"

echo "==> rebuild the regenerated module"
lake build LyapCert.Examples

echo "==> python tests"
(cd python && python3 -m unittest discover -s tests -t . -q)

echo "==> synthesis report"
(cd python && python3 -m lyapcert ../examples/systems.json)

echo
echo "ALL CHECKS PASSED"
