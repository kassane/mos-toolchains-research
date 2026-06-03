#!/usr/bin/env bash
# Compile-time ABI assertions. A successful COMPILE is the test: each frontend
# checks the MOS ABI facts at compile time (sizeof/alignof). Note ct_c.c asserts
# int==2 while ct_d.d asserts int==4 -- both COMPILE, proving the keyword
# footgun at compile time. No runtime needed.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
ok(){ printf "  %-5s compile-time assertions: PASS\n" "$1"; }
# set -e aborts on any failed compile (a failed compile-time assertion).
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -std=c11 -Os -c "$HERE/ct_c.c"     -o "$B/c.o";   ok C
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-exceptions -fno-rtti -c "$HERE/ct_cpp.cpp" -o "$B/cpp.o"; ok C++
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/ct_d.d" -of="$B/d.o"; ok D
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/ct_zig.zig"; ok Zig
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >/dev/null 2>&1 ); ok Rust
echo "  each frontend asserts its OWN true sizes at compile time; the contrast"
echo "  (C int==2 vs D int==4; C align==1 vs Zig align==4) IS the FFI evidence."
