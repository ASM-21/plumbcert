#!/usr/bin/env bash
# Full gate: Lean proofs, axiom audit, certificate freshness, Python tests.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> lake build (proofs + axiom audit)"
lake build

echo "==> grep for sorry"
if grep -rn --include='*.lean' -E '(^|[^[:alnum:]_.])sorry([^[:alnum:]_]|$)' CarbonSched/ CarbonSched.lean; then
  echo "FAIL: sorry found"; exit 1
fi
echo "    none"

echo "==> regenerate certificates and check the committed Lean matches"
cp CarbonSched/Examples.lean /tmp/carbonsched_before.lean
(cd python && python3 -m carbonsched ../examples/scenarios.json --lean ../CarbonSched/Examples.lean >/dev/null)
if ! diff -q /tmp/carbonsched_before.lean CarbonSched/Examples.lean >/dev/null; then
  echo "FAIL: CarbonSched/Examples.lean is stale"
  diff /tmp/carbonsched_before.lean CarbonSched/Examples.lean || true
  exit 1
fi
echo "    certificates unchanged"

echo "==> rebuild the regenerated module"
lake build CarbonSched.Examples

echo "==> python tests"
(cd python && python3 -m unittest discover -s tests -t . -q)

echo "==> scheduling report"
(cd python && python3 -m carbonsched ../examples/scenarios.json)

echo
echo "ALL CHECKS PASSED"
