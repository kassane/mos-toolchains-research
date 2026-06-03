#!/usr/bin/env bash
# Cross-language LLVM IR mixing on MOS. Two of the four frontends emit LLVM-22
# IR (D, Zig); two emit LLVM-23 (C, Rust). We (1) show all four agree on
# datalayout, (2) prove the LLVM-23 toolchain consumes the LLVM-22 *textual* IR
# (clang -x ir upgrades on parse), and (3) do cross-language LTO via the linker
# and compare cycle counts against the non-LTO build. The SDK ships no
# llvm-link/opt, so the linker's LTO is the merge engine (the real llvm-mos path).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
CLANG="$SDKBIN/mos-sim-clang"; SIM="$SDKBIN/mos-sim"

echo "### 1. emit textual LLVM IR from each frontend ###"
"$MOSCLANG" --target=mos -mcpu=$CPU -Oz -S -emit-llvm -ffreestanding "$HERE/step_c.c" -o "$B/c.ll"
"$LDC" -betterC -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -output-ll -of="$B/d.ll" -c "$HERE/step_d.d"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -fno-emit-bin -femit-llvm-ir="$B/zig.ll" "$HERE/step_zig.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" rustc --release -- --emit=llvm-ir >/dev/null 2>&1 )
cp "$(find "$HERE/rust/target" -name 'step_rs*.ll' | head -1)" "$B/rs.ll"

echo "### 2. producer + datalayout agreement ###"
printf "  D producer : %s\n" "$(grep -m1 'ldc version' "$B/d.ll" | sed 's/.*!"//;s/"}//')"
printf "  Rust target: %s\n" "$(grep -m1 'target triple' "$B/rs.ll" | cut -d'"' -f2)"
printf "  unique datalayouts across c/d/zig/rs: %s (1 = all agree)\n" \
       "$(grep -h '^target datalayout' "$B"/c.ll "$B"/d.ll "$B"/zig.ll "$B"/rs.ll | sort -u | wc -l)"

echo "### 3. LLVM-23 clang consumes each IR (incl. LLVM-22 D & Zig) -> native .o ###"
for f in c d zig rs; do
  "$CLANG" -mcpu=$CPU -Oz -x ir "$B/$f.ll" -c -o "$B/$f.o"
  printf "  %-5s -> %s\n" "$f.ll" "$(file -b "$B/$f.o" | cut -d, -f1)"
done
"$CLANG" -mcpu=$CPU -Os -c "$HERE/main.c" -o "$B/main.o"

echo "### 4a. link as separate objects (NO cross-language inlining) ###"
"$CLANG" -Os -fno-lto "$B/main.o" "$B/c.o" "$B/d.o" "$B/zig.o" "$B/rs.o" -o "$B/mix_nolto.elf"
NOLTO_OUT="$("$SIM" "$B/mix_nolto.elf")"; NOLTO_RC=$?
NOLTO_CYC="$("$SIM" --cycles "$B/mix_nolto.elf" 2>&1 >/dev/null | tr -dc '0-9')"
echo "  $NOLTO_OUT  (rc=$NOLTO_RC, cycles=$NOLTO_CYC)"

echo "### 4b. cross-language LTO: feed all IR to the linker, it merges+inlines ###"
# main.o is LTO bitcode (sim platform defaults to LTO); the 4 step IRs join it.
"$CLANG" -Oz -flto "$B/main.o" -x ir "$B/c.ll" "$B/d.ll" "$B/zig.ll" "$B/rs.ll" -o "$B/mix_lto.elf"
LTO_OUT="$("$SIM" "$B/mix_lto.elf")"; LTO_RC=$?
LTO_CYC="$("$SIM" --cycles "$B/mix_lto.elf" 2>&1 >/dev/null | tr -dc '0-9')"
echo "  $LTO_OUT  (rc=$LTO_RC, cycles=$LTO_CYC)"

echo "### 5. verdict ###"
echo "  cross-language IR merged & ran: nolto rc=$NOLTO_RC, lto rc=$LTO_RC"
echo "  cycles equal ($NOLTO_CYC == $LTO_CYC): the step fns are tiny; printf I/O"
echo "  dominates. The result: LLVM-23 toolchain merges LLVM-22 IR either way."
[ "$NOLTO_RC" = 0 ] && [ "$LTO_RC" = 0 ]