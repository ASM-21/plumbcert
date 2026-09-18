#!/usr/bin/env bash
# Verify every project in the repo. This is the whole claim of the repo in one
# command: if it prints ALL PROJECTS VERIFIED, every theorem in every project
# type-checks, no proof depends on sorry, and every generated certificate is
# current with the solver that produced it.
set -uo pipefail
cd "$(dirname "$0")/.."

PROJECTS=(tolstack dimcert lyapcert carbonsched gridcert)
failed=()

for p in "${PROJECTS[@]}"; do
  echo
  echo "################ $p ################"
  if (cd "$p" && ./scripts/verify.sh); then
    echo "---- $p OK"
  else
    echo "---- $p FAILED"
    failed+=("$p")
  fi
done

echo
echo "################ prose guards ################"
if python3 scripts/check-prose.py; then
  echo "---- prose OK"
else
  echo "---- prose FAILED"
  failed+=("prose")
fi

echo
echo "################ guard self-test ################"
if python3 scripts/check-prose.py --inject; then
  echo "---- guard self-test OK"
else
  echo "---- guard self-test FAILED"
  failed+=("guard-self-test")
fi

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "ALL PROJECTS VERIFIED (${#PROJECTS[@]}/${#PROJECTS[@]}) + prose guards"
  exit 0
fi
echo "FAILED: ${failed[*]}"
exit 1
