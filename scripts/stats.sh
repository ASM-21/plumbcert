#!/usr/bin/env bash
# Count theorems, definitions and lines per project. Used to keep the README
# table honest; run it after any change that adds or removes results.
set -euo pipefail
cd "$(dirname "$0")/.."
printf "%-14s %9s %6s %6s %7s\n" project theorems defs lean python
total_t=0; total_d=0
for p in tolstack dimcert lyapcert carbonsched gridcert; do
  ns=$(find "$p" -maxdepth 1 -type d -name "[A-Z]*" -printf "%f\n" | head -1)
  t=$(grep -rhE '^(@\[[a-z]+\] )?theorem ' "$p/$ns"/*.lean | wc -l)
  d=$(grep -rhE '^(private )?(def|abbrev|structure|inductive) ' "$p/$ns"/*.lean | wc -l)
  l=$(cat "$p/$ns"/*.lean "$p/$ns.lean" | wc -l)
  y=$(find "$p/python" -name '*.py' -exec cat {} + | wc -l)
  total_t=$((total_t+t)); total_d=$((total_d+d))
  printf "%-14s %9d %6d %6d %7d\n" "$p" "$t" "$d" "$l" "$y"
done
printf "%-14s %9d %6d\n" TOTAL "$total_t" "$total_d"
