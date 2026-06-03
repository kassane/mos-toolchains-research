#!/usr/bin/env bash
# Standard-library reach per frontend on bare MOS: each language exercises its
# OWN stdlib (C libc / C++ STL subset / Zig std / Rust alloc / D core.stdc+ldc),
# all linked into one binary and run on mos-sim.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -c "$HERE/c_std.c"   -I"$HERE" -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-exceptions -fno-rtti -std=c++20 -c "$HERE/cpp_std.cpp" -I"$HERE" -o "$B/cpp.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/d_std.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/zig_std.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust-build.log" 2>&1 ) \
  || { echo "rust build failed:"; tail -5 "$B/rust-build.log"; exit 1; }
RSA="$(find "$HERE/rust/target" -name 'librs_std.a'|head -1)"; [ -n "$RSA" ] || { echo "no rust archive"; exit 1; }
cp "$RSA" "$B/librs.a"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -I"$HERE" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/zig.o" "$B/librs.a" -o "$B/std.elf"
set +e; "$SDKBIN/mos-sim" "$B/std.elf"; RC=$?; set -e
echo "### exit=$RC (0 = every language's stdlib demo computed correctly) ###"
exit $RC
