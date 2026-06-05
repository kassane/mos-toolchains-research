#!/usr/bin/env bash
# Compile-time file embedding across 5 frontends: C23 #embed, C++ #embed,
# D import("file") (-J), Zig @embedFile, Rust include_bytes!. Each embeds the
# SAME payload.bin at compile time and returns its byte-sum; all must agree with
# the actual sum (computed below and passed as -DEXPECT).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
# C23 (#embed clean in c23/gnu23; warns "c23-extensions" in older dialects)
"$SDKBIN/mos-sim-clang"   -std=c23 -mcpu=$CPU -Os -I"$HERE" -c "$HERE/embed_c.c" -o "$B/c.o"
# C++ #embed is a Clang extension (standard in C++26); silence its warning
"$SDKBIN/mos-sim-clang++" -std=c++2c -Wno-c23-extensions -mcpu=$CPU -Os -fno-exceptions -fno-rtti -I"$HERE" -c "$HERE/embed_cpp.cpp" -o "$B/cpp.o"
# D needs -J<dir> for the string-import search path
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -J"$HERE" -c "$HERE/embed_d.d" -of="$B/d.o"
# Zig resolves @embedFile relative to the source file
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/embed_zig.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust.log" 2>&1 ) \
  || { echo "rust build failed:"; tail -5 "$B/rust.log"; exit 1; }
RSA="$(find "$HERE/rust/target" -name 'libembed_rs.a'|head -1)"; [ -n "$RSA" ] || { echo "no rust archive"; exit 1; }
cp "$RSA" "$B/librs.a"

# mos-sim has NO filesystem, so a correct runtime byte-sum can only come from
# bytes embedded at COMPILE time. (At -Os the sum even const-folds to the literal,
# since the payload is known at compile time -- embedding composes with CTFE.)

# asm-inline .incbin (the SDK's NES-mapper config technique; -I resolves the file)
"$SDKBIN/mos-sim-clang" -std=c23 -mcpu=$CPU -Os -I"$HERE" -c "$HERE/embed_incbin.c" -o "$B/incbin.o"
SUM=$(python3 -c "print(sum(open('$HERE/payload.bin','rb').read()) & 0xffff)")
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -DEXPECT=$SUM -I"$HERE" -c "$HERE/driver.c" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/zig.o" "$B/librs.a" "$B/incbin.o" -o "$B/embed.elf"
set +e; "$SDKBIN/mos-sim" "$B/embed.elf"; RC=$?; set -e
echo "### exit=$RC (0 = all 6 embed methods produced identical bytes at compile time) ###"
exit $RC
