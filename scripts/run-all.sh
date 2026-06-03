#!/usr/bin/env bash
# Run every experiment; print a PASS/FAIL summary. Exit 0 iff all pass.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fails=0
for d in "$HERE"/experiments/*/; do
  [ -x "$d/run.sh" ] || continue
  name="$(basename "$d")"
  if ( cd "$d" && ./run.sh >build/run.log 2>&1 ); then
    printf "  PASS  %s\n" "$name"
  else
    printf "  FAIL  %s (see %sbuild/run.log)\n" "$name" "$d"; fails=$((fails+1))
  fi
done
echo "== $fails failing experiment(s) =="
exit $((fails>0))
