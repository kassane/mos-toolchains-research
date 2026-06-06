#!/usr/bin/env bash
# Cross-language FFI matrix on MOS 6502: compile each language to a NATIVE ELF
# object, link all into ONE binary with the SDK driver, run on mos-sim.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"
CPU=mos6502

echo "### compile each language -> native .o (mos-$CPU) ###"
# C  (SDK mos-sim-clang, LLVM 23) -- platform driver supplies libc include paths
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -c "$HERE/lib_c.c"   -I"$HERE/include" -o "$B/lib_c.o"
# C++ (SDK mos-sim-clang++, LLVM 23) -- no exceptions/rtti
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-exceptions -fno-rtti -c "$HERE/lib_cpp.cpp" -I"$HERE/include" -o "$B/lib_cpp.o"
# D  (LDC 1.42, LLVM 23) -- betterC, native object (no -flto => real .o)
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/lib_d.d" -of="$B/lib_d.o"
# Zig (0.17-mos, LLVM 22) -- build-obj => native .o
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/lib_zig.o" "$HERE/lib_zig.zig"
# Rust (rust-mos, LLVM 23) -- staticlib (.a of native objects)
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >/dev/null 2>&1 )
RS_A="$(find "$HERE/rust/target" -name 'libffi_rs.a' | head -1)"
cp "$RS_A" "$B/libffi_rs.a"
# driver main (C, uses stdio printf from the sim platform libc)
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -c "$HERE/driver.c" -I"$HERE/include" -o "$B/driver.o"

echo "### object kinds (must be ELF, not bitcode) ###"
for o in "$B"/*.o; do printf "  %-12s " "$(basename "$o")"; file -b "$o" | cut -d, -f1; done

echo "### link ALL languages into one mos-sim binary ###"
"$SDKBIN/mos-sim-clang" -Os \
    "$B/driver.o" "$B/lib_c.o" "$B/lib_cpp.o" "$B/lib_d.o" "$B/lib_zig.o" "$B/libffi_rs.a" \
    -o "$B/ffi_matrix.elf"
echo "  linked: $(file -b "$B/ffi_matrix.elf" | cut -d, -f1)  size=$("$SIZE" "$B/ffi_matrix.elf" 2>/dev/null | tail -1 | awk '{print $4}') bytes"

echo "### undefined symbols (must be none) ###"
UND="$("$NM" "$B/ffi_matrix.elf" 2>/dev/null | grep -c ' U ' || true)"
echo "  undefined count: $UND"

echo "### RUN on mos-sim ###"
set +e
"$SDKBIN/mos-sim" "$B/ffi_matrix.elf"
RC=$?
set -e
echo "### mos-sim exit code = $RC (0 = all FFI calls correct) ###"
exit $RC
