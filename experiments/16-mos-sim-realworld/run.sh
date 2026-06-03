#!/usr/bin/env bash
# Real-world mos-sim use-case: an interactive stdin->stdout line filter (C libc
# getchar/putchar) that uppercases each byte via a Zig FFI worker, driven by
# PIPED stdin, with a cycle count read from the $FFF0 MMIO counter.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/up.o" "$HERE/upcase.zig"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/main.c" -o "$B/main.o"
"$SDKBIN/mos-sim-clang" -Os "$B/main.o" "$B/up.o" -o "$B/filter.sim"

echo "### feed piped stdin; expect the text echoed UPPERCASED ###"
INPUT='hello from the 6502
mixed Case 123!'
OUT="$(printf '%s\n' "$INPUT" | "$SDKBIN/mos-sim" "$B/filter.sim")"; RC=$?
printf '%s\n' "$OUT" | sed 's/^/  /'
EXPECT="$(printf '%s\n' "$INPUT" | tr 'a-z' 'A-Z')"
GOT="$(printf '%s\n' "$OUT" | grep -v '^\[processed')"
echo "### verify ###"
if [ "$GOT" = "$EXPECT" ]; then echo "  uppercase output matches expected; rc=$RC"; else
  echo "  MISMATCH"; echo "  expected: $EXPECT"; exit 1; fi
echo "### cycle line present? ###"
printf '%s\n' "$OUT" | grep -qE '\[processed [0-9]+ chars in [0-9]+ cycles\]' && echo "  cycle counter read OK" || { echo "  no cycle line"; exit 1; }
exit $RC
