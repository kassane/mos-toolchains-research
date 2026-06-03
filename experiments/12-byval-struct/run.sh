#!/usr/bin/env bash
# By-value struct ABI: pass Small(2B) by value (register-decomposed) and return
# Big(8B) by value (hidden sret pointer) across 5 languages; verify on mos-sim.
# Also shows the sret pointer appears in IR for the >4-byte return.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -c "$HERE/bv_c.c"   -I"$HERE" -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-exceptions -fno-rtti -c "$HERE/bv_cpp.cpp" -I"$HERE" -o "$B/cpp.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/bv_d.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/bv_zig.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust-build.log" 2>&1 ) \
  || { echo "rust build failed (see $B/rust-build.log):"; tail -5 "$B/rust-build.log"; exit 1; }
RSA="$(find "$HERE/rust/target" -name 'libbv_rs.a'|head -1)"
[ -n "$RSA" ] || { echo "rust archive missing after build"; exit 1; }
cp "$RSA" "$B/librs.a"

echo "### sret evidence: Big(8B) return lowers to a hidden pointer arg (clang IR) ###"
"$MOSCLANG" --target=mos -mcpu=$CPU -Oz -S -emit-llvm -ffreestanding "$HERE/bv_c.c" -I"$HERE" -o "$B/c.ll"
grep -oE 'define[^@]*@c_mkbig\([^)]*\)' "$B/c.ll" | head -1 | sed 's/^/  /'
SRET_BAD=0
if grep -qE '@c_mkbig\(ptr[^)]*sret' "$B/c.ll"; then
  echo "  -> sret pointer present (>4-byte aggregate returned by ref)"
else
  echo "  -> MISSING sret marker: the >4-byte aggregate ABI this test relies on regressed"; SRET_BAD=1
fi

echo "### run on mos-sim ###"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -I"$HERE" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/zig.o" "$B/librs.a" -o "$B/bv.elf"
set +e; "$SDKBIN/mos-sim" "$B/bv.elf"; RC=$?; set -e
echo "### exit=$((RC+SRET_BAD)) (0 = by-value struct ABI characterized + sret present) ###"
exit $((RC+SRET_BAD))
