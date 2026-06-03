#!/usr/bin/env bash
# Compile-time reflection across frontends. D & Zig enumerate a struct's fields,
# sum their sizes, and read field NAMES at compile time; C/C++/Rust can only take
# whole-struct sizeof (no in-language field enumeration). Verified on mos-sim.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/refl_d.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/refl_zig.zig"
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -c "$HERE/refl_c.c"   -I"$HERE" -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-exceptions -fno-rtti -c "$HERE/refl_cpp.cpp" -I"$HERE" -o "$B/cpp.o"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust.log" 2>&1 ) \
  || { echo "rust build failed:"; tail -5 "$B/rust.log"; exit 1; }
RSA="$(find "$HERE/rust/target" -name 'librefl_rs.a'|head -1)"; [ -n "$RSA" ] || { echo "no rust archive"; exit 1; }
cp "$RSA" "$B/librs.a"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -I"$HERE" -c "$HERE/driver.c" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/d.o" "$B/zig.o" "$B/c.o" "$B/cpp.o" "$B/librs.a" -o "$B/refl.elf"
set +e; "$SDKBIN/mos-sim" "$B/refl.elf"; RC=$?; set -e
echo "### exit=$RC (0 = D/Zig compile-time reflection correct; C/C++/Rust sizeof agrees) ###"
exit $RC
