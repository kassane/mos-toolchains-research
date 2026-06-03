#!/usr/bin/env bash
# Run every experiment; print a PASS/FAIL summary. Exit 0 iff all pass.
# Logs go to a TOP-LEVEL build/run-all/ (gitignored) -- NOT each experiment's own
# build/, which its run.sh `rm -rf`s on start (that would truncate an open log,
# and wouldn't exist yet on a clean checkout).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGDIR="$HERE/build/run-all"; mkdir -p "$LOGDIR"
fails=0
for d in "$HERE"/experiments/*/; do
  [ -x "$d/run.sh" ] || continue
  name="$(basename "$d")"
  if ( cd "$d" && ./run.sh ) >"$LOGDIR/$name.log" 2>&1; then
    printf "  PASS  %s\n" "$name"
  else
    printf "  FAIL  %s (see %s/%s.log)\n" "$name" "$LOGDIR" "$name"; fails=$((fails+1))
  fi
done
echo "== $fails failing experiment(s) =="
exit $((fails>0))
