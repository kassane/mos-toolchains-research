#!/usr/bin/env bash
# Emit LLVM IR for an identical add(i32,i32) from all 4 frontends; show that the
# target datalayout is byte-identical (shared backend) and surface the int-width
# divergence (C int -> i16; D/Rust/Zig -> i32).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$MOSCLANG" --target=mos -mcpu=$CPU -Oz -S -emit-llvm -ffreestanding -nostdlib "$HERE/add.c" -o "$B/add_c.ll"
"$LDC" -betterC -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -output-ll -of="$B/add_d.ll" -c "$HERE/add.d"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -fno-emit-bin -femit-llvm-ir="$B/add_zig.ll" "$HERE/add.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" rustc --release -- --emit=llvm-ir >/dev/null 2>&1 )
cp "$(find "$HERE/rust/target" -name 'add_rs*.ll'|head -1)" "$B/add_rs.ll"
echo "### target datalayout (unique count across all 4) ###"
grep -h '^target datalayout' "$B"/*.ll | sort -u
echo "  unique: $(grep -h '^target datalayout' "$B"/*.ll | sort -u | wc -l) (1 = shared)"
echo "### add() lowering per frontend (note i16 vs i32) ###"
for f in add_c add_d add_zig add_rs; do
  printf "  %-8s " "$f"; grep -oE 'define [^@]*@(add|add\.add)\([^)]*\)' "$B/$f.ll" | head -1
done
