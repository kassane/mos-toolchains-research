#!/usr/bin/env bash
# D's ImportC (pass a .c straight to ldc2) on MOS. The rebuilt LDC (d5610c25) fixes the C
# `int` width to 16-bit — resolving dlang-mos-hello-world#1 at the ImportC layer. ImportC
# runs C through the D frontend, so it applies D's lowering RULES (by-value structs as
# first-class aggregates, `signext` attrs) rather than C's (scalar decomposition) — yet
# the machine-level ABI still matches, so C<->ImportC FFI (incl. by-value structs) works.
# NB: ImportC needs a MOS C preprocessor — `-gcc=$SDKBIN/mos-sim-clang` (+ `-P-I<dir>`);
# the default host /usr/bin/clang rejects `-mtriple=mos`.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502

# (A) same C, three frontends: int width agrees (the fix); by-value struct lowering diverges
echo "### (A) imc.c via ImportC vs mos-clang vs zig cc — int width + struct lowering ###"
"$MOSCLANG" --target=mos -mcpu=$CPU -Oz -S -emit-llvm "$HERE/imc.c" -I"$HERE" -o "$B/clang.ll" 2>/dev/null
"$ZIG" cc -target mos-freestanding -Oz -S -emit-llvm "$HERE/imc.c" -I"$HERE" -o "$B/zigcc.ll" 2>/dev/null
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -gcc="$SDKBIN/mos-sim-clang" -P-I"$HERE" --output-ll -of="$B/ldc.ll" -c "$HERE/imc.c" 2>/dev/null
for f in clang zigcc ldc; do
  add="$(grep -oE 'define[^@]*@add\([^)]*\)' "$B/$f.ll" | head -1 | sed 's/.*@add//;s/ noundef//g;s/ signext//g')"
  ps="$(grep -oE 'define[^@]*@psum\([^)]*\)' "$B/$f.ll" | head -1 | sed 's/.*@psum//')"
  printf "  %-7s add%s  psum%s\n" "$f" "$add" "$ps"
done
echo "  -> int=i16 in all (ImportC fix); psum: clang/zigcc decompose [C rules], LDC passes the aggregate [D rules]"

# (B) C driver <-> ImportC-compiled C on mos-sim: 16-bit int + by-value-struct FFI
echo "### (B) C driver <-> ImportC-compiled C, on mos-sim ###"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -gcc="$SDKBIN/mos-sim-clang" -P-I"$HERE" -c "$HERE/imc.c" -of="$B/imc.o"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -I"$HERE" -c "$HERE/driver.c" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/imc.o" -o "$B/imc.elf"
set +e; OUT="$("$SDKBIN/mos-sim" "$B/imc.elf")"; RC=$?; set -e
echo "$OUT"
echo "### exit=$RC (0 = sizeof(int)=2 + add=42 + by-value psum=42 across C<->ImportC) ###"
exit $RC
