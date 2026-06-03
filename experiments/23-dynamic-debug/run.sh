#!/usr/bin/env bash
# Dynamic debugging on the 6502: are the DWARF line tables from exp 11 not just
# *inspectable* but *usable*? mos-sim attributes runtime cycles per PC (--profile)
# and dumps per-instruction state (--trace); llvm-symbolizer maps those runtime
# PCs back to source line through the -g DWARF in the linked ELF. This closes the
# loop exp 11 (static DWARF) left open: runtime PC -> source, on the simulator.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"
SIM="$SDKBIN/mos-sim"; SYM="$SDKBIN/llvm-symbolizer"
bad=0

# 1. Build WITH debug info. -save-temps=obj keeps the linked ELF (carrying DWARF)
#    next to the flat sim image, so we can symbolize against it.
"$SDKBIN/mos-sim-clang" -Os -g -save-temps=obj "$HERE/fib.c" -o "$B/fib.sim" 2>/dev/null
ELF="$B/fib.sim.elf"
[ -f "$ELF" ] || { echo "FAIL: -save-temps did not leave a DWARF ELF"; exit 1; }
have_line="$("$READELF" -SW "$ELF" 2>/dev/null | grep -oE '\.debug_line\b' | head -1)"
echo "### built fib.c -g -> image + ELF (${have_line:-NO}.debug_line) ###"
[ -n "$have_line" ] || { echo "FAIL: no .debug_line in ELF"; bad=$((bad+1)); }

# 2. Run on the sim. fib(12)=144, exit code = 144 & 0xFF. (No `set -e` in this
#    script: mos-sim returns the *program's* exit code, which we inspect.)
"$SIM" "$B/fib.sim"; rc=$?
printf "  ran on sim: exit=%s (expect 144 = fib(12)&0xFF) %s\n" "$rc" \
  "$([ "$rc" = 144 ] && echo OK || echo MISMATCH)"
[ "$rc" = 144 ] || bad=$((bad+1))

# 3. --profile: cycles per PC (mos-sim writes the profile to STDERR, not stdout).
"$SIM" --profile "$B/fib.sim" >/dev/null 2>"$B/prof.txt"
N="$(grep -cE '^[0-9a-f]{4} [0-9]+$' "$B/prof.txt")"
echo "### mos-sim --profile: $N distinct PCs sampled; hottest 5 -> source: ###"
grep -E '^[0-9a-f]{4} [0-9]+$' "$B/prof.txt" | sort -k2 -nr | head -5 > "$B/hot.txt"
[ "${N:-0}" -gt 0 ] || { echo "  FAIL: profile produced no PC samples"; bad=$((bad+1)); }

# 4. Symbolize the hot PCs back to source via the DWARF line table. Gate on the
#    hottest PC resolving to fib() at a real fib.c:line (the runtime->source proof).
top_ok=0
while read -r pc cyc; do
  loc="$("$SYM" --obj="$ELF" "0x$pc" 2>/dev/null | paste -sd' ' -)"
  printf "  0x%s %8s cyc  ->  %s\n" "$pc" "$cyc" "$loc"
  if [ "$top_ok" = 0 ] && printf '%s' "$loc" | grep -q 'fib' && printf '%s' "$loc" | grep -qE 'fib\.c:[0-9]'; then
    top_ok=1
  fi
done < "$B/hot.txt"
[ "$top_ok" = 1 ] || { echo "  GATE FAIL: hottest PC did not round-trip to fib() source"; bad=$((bad+1)); }

# 5. --trace: per-instruction PC + A/X/Y/S + decoded status flags + opcode bytes.
echo "### mos-sim --trace (first 3 instructions): PC regs (flags) insn ###"
"$SIM" --trace "$B/fib.sim" >/dev/null 2>"$B/trace.txt"
grep -E '^[0-9a-f]{4} a:' "$B/trace.txt" | head -3 | sed 's/^/  /'

# 6. addr2line cross-check (same DWARF, different tool) on the hottest PC.
top="$(head -1 "$B/hot.txt" | cut -d' ' -f1)"
echo "### llvm-addr2line cross-check (0x$top): $("$SDKBIN/llvm-addr2line" -fe "$ELF" "0x$top" 2>/dev/null | paste -sd' ' -) ###"

echo "== $bad failure(s) (0 = ran + profile PCs symbolize back to source) =="
exit $((bad>0))
