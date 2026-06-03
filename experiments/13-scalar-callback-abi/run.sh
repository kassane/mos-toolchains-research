#!/usr/bin/env bash
# Extended scalar + callback ABI: 64-bit integer round-trip (8 bytes across
# registers), signed negate (sign handling), and calling a C function pointer
# (callback ABI) -- in all 5 languages, verified on mos-sim.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -c "$HERE/ext_c.c"   -I"$HERE" -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-exceptions -fno-rtti -c "$HERE/ext_cpp.cpp" -I"$HERE" -o "$B/cpp.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/ext_d.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/ext_zig.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust-build.log" 2>&1 ) \
  || { echo "rust build failed (see $B/rust-build.log):"; tail -5 "$B/rust-build.log"; exit 1; }
RSA="$(find "$HERE/rust/target" -name 'libext_rs.a'|head -1)"
[ -n "$RSA" ] || { echo "rust archive missing after build"; exit 1; }
cp "$RSA" "$B/librs.a"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -I"$HERE" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/zig.o" "$B/librs.a" -o "$B/ext.elf"
set +e; "$SDKBIN/mos-sim" "$B/ext.elf"; RC=$?; set -e
echo "### exit=$RC (0 = i64 + signed + callback ABI shared across all 5) ###"
exit $RC
