#!/usr/bin/env bash
# Can `zig cc` be the LINKER for Rust-on-MOS? Tests the goal's
# `zig cc -lunwind -fno-sanitize=all` idea and documents the outcome:
#   1. zig cc COMPILES a MOS object (LLVM 22 clang)                 -> works
#   2. zig cc -lunwind                                              -> no MOS libc
#   3. zig cc + the SDK's LLVM-23 *bitcode* libc (LLVM-22 lld)      -> CLUSTER WALL
#   4. the SDK driver (mos-sim-clang, LLVM 23) links the SAME objs  -> runs (42)
# Exit 0 iff every documented outcome holds.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
SDK=/home/user/tools/sdk/llvm-mos; SIMLIB="$SDK/mos-platform/sim/lib"
bad=0

echo "### 1. zig cc compiles a MOS object ###"
if "$ZIG" cc -target mos-freestanding -fno-sanitize=all -c "$HERE/main.c" -o "$B/main.o" 2>"$B/1.err" \
   && [ "$(file -b "$B/main.o" | cut -d, -f1)" = "ELF 32-bit LSB relocatable" ]; then
  echo "  OK: zig cc -> ELF MOS object"
else echo "  FAIL: zig cc could not compile a MOS object"; bad=$((bad+1)); fi

echo "### 2. zig cc -lunwind (no libc/libunwind for mos-freestanding) ###"
"$ZIG" cc -target mos-freestanding -fno-sanitize=all -lunwind "$HERE/main.c" -o "$B/u.out" 2>"$B/2.err"
if grep -q 'unable to provide libc for target' "$B/2.err"; then
  echo "  OK (documented): $(grep -oE 'unable to provide libc.*' "$B/2.err" | head -1)"
else echo "  unexpected: -lunwind did not fail on missing libc"; bad=$((bad+1)); fi

echo "### 3. zig cc (LLVM-22 lld) + SDK LLVM-23 bitcode libc -> cluster wall ###"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust.log" 2>&1 ) \
  || { echo "  rust build failed"; tail -3 "$B/rust.log"; exit 1; }
RLIB="$(find "$HERE/rust/target" -name 'libzl_rs.a'|head -1)"
"$ZIG" cc -target mos-freestanding -nostdlib -fno-sanitize=all "$B/main.o" "$RLIB" \
   "$SIMLIB"/libc.a -o "$B/zc.sim" 2>"$B/3.err"
if grep -qE "Producer: 'LLVM ?23.*Reader: 'LLVM ?22" "$B/3.err"; then
  echo "  OK (documented cluster wall): $(grep -oE 'Not an int attribute.*' "$B/3.err" | head -1)"
else echo "  unexpected: no LLVM23/22 bitcode mismatch error"; cat "$B/3.err" | head -3; bad=$((bad+1)); fi

echo "### 4. the SDK driver (LLVM 23) links the SAME rust .a + main -> runs ###"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/main.c" -o "$B/main_sdk.o" 2>"$B/4.err"
"$SDKBIN/mos-sim-clang" -Os "$B/main_sdk.o" "$RLIB" -o "$B/sdk.sim" 2>>"$B/4.err"
"$SDKBIN/mos-sim" "$B/sdk.sim"; rc=$?
if [ "$rc" = 42 ]; then echo "  OK: SDK linker produced a runnable image (rs_sub16(50,8)=$rc)"; else
  echo "  FAIL: SDK link/run returned $rc (expected 42)"; bad=$((bad+1)); fi

echo "### verdict ###"
echo "  zig cc COMPILES MOS objs and its LLVM-22 lld links LLVM-23 *native ELF*,"
echo "  but the SDK's libc is LLVM-23 *bitcode* -> LLVM-22 lld rejects it, and zig"
echo "  ships no MOS libc. Use the SDK's mos-*-clang (LLVM 23) to link Rust on MOS."
echo "== $bad unexpected outcome(s) (0 = behaves exactly as documented) =="
exit $((bad>0))
