#!/usr/bin/env bash
# MMIO hardware-register parity (the mos-hardware poke! / mega65-libc POKE pattern):
# each frontend writes a byte to the fixed MMIO register $FFF9 via its own volatile
# idiom. (1) all must lower to the SAME 6502 store `sta $fff9`; (2) linked together
# they drive the sim console -> "C+RDZ".
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
# native objects (-fno-lto) so each poke fn is disassemblable
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -fno-lto -c "$HERE/hal_c.c"   -I"$HERE" -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-lto -fno-exceptions -fno-rtti -c "$HERE/hal_cpp.cpp" -I"$HERE" -o "$B/cpp.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/hal_d.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/hal_zig.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust.log" 2>&1 ) \
  || { echo "rust build failed:"; tail -5 "$B/rust.log"; exit 1; }
RSA="$(find "$HERE/rust/target" -name 'libhal_rs.a'|head -1)"; [ -n "$RSA" ] || { echo "no rust archive"; exit 1; }
cp "$RSA" "$B/librs.a"

echo "### codegen parity: each poke must emit a store to \$fff9 (= 65529) ###"
bad=0
for pair in "c.o:c_poke" "cpp.o:cpp_poke" "d.o:d_poke" "zig.o:zig_poke" "librs.a:rs_poke"; do
  o="${pair%%:*}"; fn="${pair##*:}"
  asm="$("$SDKBIN/llvm-objdump" -d --mcpu=$CPU "$B/$o" 2>/dev/null \
        | awk -v f="<$fn>:" '/^[0-9a-f]+ <.*>:/{g=index($0,f)?1:0} g&&/sta/{print}')"
  if printf '%s' "$asm" | grep -qiE 'sta.*(fff9|65529|\$fff9)'; then
    printf "  %-9s sta \$fff9  OK\n" "$fn"
  else printf "  %-9s NO sta \$fff9 (%s)\n" "$fn" "$(printf '%s' "$asm"|tr -s ' '|head -1)"; bad=$((bad+1)); fi
done

echo "### run: all 5 drive the same MMIO register ###"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -I"$HERE" -c "$HERE/driver.c" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/zig.o" "$B/librs.a" -o "$B/hal.elf"
OUT="$("$SDKBIN/mos-sim" "$B/hal.elf" | head -1)"
echo "  console output: '$OUT'"
[ "$OUT" = "C+RDZ" ] || { echo "  expected 'C+RDZ'"; bad=$((bad+1)); }
echo "== $bad issue(s) (0 = identical MMIO codegen + correct console output) =="
exit $((bad>0))
