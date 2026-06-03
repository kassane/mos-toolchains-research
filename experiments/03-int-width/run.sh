#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$LDC" -betterC -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/sizes_d.d" -of="$B/sizes_d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/sizes_zig.o" "$HERE/sizes_zig.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >/dev/null 2>&1 )
cp "$(find "$HERE/rust/target" -name 'libsizes_rs.a' | head -1)" "$B/libsizes_rs.a"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/sizes.c" -I"$HERE" -o "$B/sizes.o"
"$SDKBIN/mos-sim-clang" -Os "$B/sizes.o" "$B/sizes_d.o" "$B/sizes_zig.o" "$B/libsizes_rs.a" -o "$B/sizes.elf"
set +e; "$SDKBIN/mos-sim" "$B/sizes.elf"; RC=$?; set -e
echo "(exit $RC)"
