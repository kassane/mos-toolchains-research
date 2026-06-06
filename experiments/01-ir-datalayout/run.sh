#!/usr/bin/env bash
# Emit LLVM IR for an identical add(int,int) from all 4 frontends; show that the
# target datalayout is byte-identical (shared backend) and surface the int-width
# divergence (C int -> i16; D int / Rust & Zig i32 -> i32). Both facts are now
# ASSERTED (exit != 0 on regression), so this is a regression test, not just a print.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$MOSCLANG" --target=mos -mcpu=$CPU -Oz -S -emit-llvm -ffreestanding -nostdlib "$HERE/add.c" -o "$B/add_c.ll"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -output-ll -of="$B/add_d.ll" -c "$HERE/add.d"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -fno-emit-bin -femit-llvm-ir="$B/add_zig.ll" "$HERE/add.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" rustc --release -- --emit=llvm-ir >/dev/null 2>&1 )
cp "$(find "$HERE/rust/target" -name 'add_rs*.ll'|head -1)" "$B/add_rs.ll"
fails=0
echo "### target datalayout (unique count across all 4) ###"
grep -h '^target datalayout' "$B"/*.ll | sort -u
uniq_dl=$(grep -h '^target datalayout' "$B"/*.ll | sort -u | wc -l)
echo "  unique: $uniq_dl (1 = shared)"
[ "$uniq_dl" -eq 1 ] || { echo "  UNEXPECTED: datalayout not shared ($uniq_dl != 1)"; fails=$((fails+1)); }
echo "### add() lowering per frontend (assert C int -> i16, D/Zig/Rust -> i32) ###"
for f in add_c add_d add_zig add_rs; do
  case $f in add_c) want=i16;; *) want=i32;; esac
  sig=$(grep -oE 'define [^@]*@(add|add\.add)\([^)]*\)' "$B/$f.ll" | head -1 || true)
  printf "  %-8s %s\n" "$f" "$sig"
  got=$(printf '%s' "$sig" | grep -oE '\((i8|i16|i32|i64)' | head -1 | tr -d '(' || true)
  [ "$got" = "$want" ] || { echo "    UNEXPECTED: $f param '${got:-<none>}', expected '$want'"; fails=$((fails+1)); }
done
echo "== $fails unexpected mismatch(es) (0 = shared datalayout + C int=i16 vs D/Zig/Rust i32) =="
exit $fails
