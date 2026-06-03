#!/usr/bin/env bash
# CPU-features parity (the ldc#4919 question applied to MOS).
# `ldc2 -mcpu=mos6502` reports features '' (empty); clang/rust/zig auto-enable
# +mos6502,+mos-insns-6502,+mos-insns-6502bcd,+static-stack. Does that empty
# string actually change D's codegen? Answer: NO for base mos6502 -- the
# LLVM-MOS backend derives the CPU's implied features regardless of -mattr.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"

echo "### feature strings each frontend feeds LLVM for -mcpu=mos6502 ###"
echo "  clang : (implied by target-cpu=mos6502; not spelled in IR)"
echo "  rust  : (implied by target-cpu=mos6502; not spelled in IR)"
echo "  zig   : +mos6502,+mos-insns-6502,+mos-insns-6502bcd,+static-stack (explicit in IR)"
printf "  ldc   : "; "$LDC" -betterC $LDC_PE -o- -c "$HERE/bench_d.d" --mtriple=mos -mcpu=mos6502 -vv 2>&1 | grep -oE "features '[^']*'"
printf "  ldc+  : "; "$LDC" -betterC $LDC_PE -o- -c "$HERE/bench_d.d" --mtriple=mos -mcpu=mos6502 -mattr="$MOS_MATTR" -vv 2>&1 | grep -oE "features '[^']*'"

echo "### does -mattr change D's 6502 asm? ###"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=mos6502                       -output-s -of="$B/d_plain.s"  -c "$HERE/bench_d.d"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=mos6502 -mattr="$MOS_MATTR"   -output-s -of="$B/d_mattr.s"  -c "$HERE/bench_d.d"
if diff -q "$B/d_plain.s" "$B/d_mattr.s" >/dev/null; then
  echo "  IDENTICAL 6502 asm -> -mcpu implies features in the backend; -mattr is"
  echo "  cosmetic for base mos6502 (the -vv '' display is harmless). Still passed"
  echo "  in all experiments for parity with clang/rust/zig and non-base CPUs."
  RC=0
else
  echo "  DIFFERENT -> -mattr matters; see diff:"; diff "$B/d_plain.s" "$B/d_mattr.s" | head; RC=1
fi
exit $RC
