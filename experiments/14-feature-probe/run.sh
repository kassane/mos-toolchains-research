#!/usr/bin/env bash
# Feature / capability probe: does feature X COMPILE for the 6502 in language Y?
# Compile-only (a clean exit = supported). Captures the support matrix + the
# multi-CPU acceptance (mos65c02 / mosw65816) per frontend.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
ok(){ [ "$1" = 0 ] && echo "yes" || echo "NO"; }

echo "### inline assembly (compile a tiny SEI/CLI-ish asm) ###"
printf 'void f(void){ __asm__ volatile("nop"); }\n' > "$B/a.c"
"$MOSCLANG" --target=mos -mcpu=$CPU -c "$B/a.c" -o "$B/a.o" 2>/dev/null; echo "  clang inline-asm : $(ok $?)"
printf 'export fn f() void { asm volatile ("nop"); }\n' > "$B/a.zig"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/az.o" "$B/a.zig" 2>/dev/null; echo "  zig inline-asm   : $(ok $?)"
printf 'module a; extern(C) void f(){ asm { "nop"; } }\n' > "$B/a.d"
"$LDC" -betterC -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$B/a.d" -of="$B/ad.o" 2>/dev/null; echo "  ldc inline-asm   : $(ok $?)  (LDC uses LLVM-style asm; betterC)"
# Rust: build via the rust-asm/ crate (build-std supplies `core`) so the ONLY
# possible failure is asm! support itself, not a missing-core false negative.
( cd "$HERE/rust-asm" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/ar.err" 2>&1 )
rc=$?
if grep -q 'inline assembly is unsupported on this target' "$B/ar.err"; then
  echo "  rust inline-asm  : NO  (rust-mos#13: 'inline assembly is unsupported on this target')"
else
  echo "  rust inline-asm  : $(ok $rc)"
fi

echo "### interrupt handler attribute (clang) ###"
printf '__attribute__((interrupt)) void isr(void){}\n' > "$B/i.c"
"$MOSCLANG" --target=mos -mcpu=$CPU -c "$B/i.c" -o "$B/i.o" 2>/dev/null; echo "  clang __attribute__((interrupt)) : $(ok $?)"
printf 'export fn isr() callconv(.{ .mos_interrupt = .{} }) void {}\n' > "$B/i.zig"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/iz.o" "$B/i.zig" 2>"$B/iz.err"
echo "  zig callconv(.mos_interrupt)     : $(ok $?)"

echo "### atomics (target reports 8-bit atomic load/store only) ###"
printf '#include <stdatomic.h>\nunsigned char L(_Atomic unsigned char*p){return atomic_load(p);}\n' > "$B/at.c"
"$MOSCLANG" --target=mos -mcpu=$CPU -c "$B/at.c" -o "$B/at.o" 2>/dev/null; echo "  clang 8-bit atomic_load : $(ok $?)"
printf '#include <stdatomic.h>\nunsigned long L(_Atomic unsigned long*p){return atomic_fetch_add(p,1);}\n' > "$B/at2.c"
"$MOSCLANG" --target=mos -mcpu=$CPU -c "$B/at2.c" -o "$B/at2.o" 2>/dev/null; echo "  clang 32-bit atomic_fetch_add (CAS) : $(ok $?)  (expect NO: no atomic CAS)"

echo "### multi-CPU acceptance: compile add() for mos65c02 and mosw65816 ###"
printf 'unsigned short g(unsigned short a,unsigned short b){return a+b;}\n' > "$B/g.c"
printf 'module g; extern(C) ushort g(ushort a,ushort b){return cast(ushort)(a+b);}\n' > "$B/g.d"
printf 'export fn g(a:u16,b:u16)u16{return a+%%b;}\n' > "$B/g.zig"
for cpu in mos65c02 mosw65816; do
  "$MOSCLANG" --target=mos -mcpu=$cpu -c "$B/g.c" -o "$B/g.o" 2>/dev/null; c=$?
  "$LDC" -betterC -Oz -mtriple=mos -mcpu=$cpu -c "$B/g.d" -of="$B/gd.o" 2>/dev/null; d=$?
  "$ZIG" build-obj -target mos-freestanding -mcpu $cpu -OReleaseSmall -femit-bin="$B/gz.o" "$B/g.zig" 2>/dev/null; z=$?
  r=$( "$RUSTC" --print cfg --target mos-unknown-none -Ctarget-cpu=$cpu >/dev/null 2>&1; echo $? )
  printf "  %-9s clang=%s ldc=%s zig=%s rustc-accepts=%s\n" "$cpu" "$(ok $c)" "$(ok $d)" "$(ok $z)" "$(ok $r)"
done

echo "### SIMD/vector type (MOS is scalar 8-bit; expect rejection or scalarization) ###"
printf 'typedef int v4 __attribute__((vector_size(8)));\nv4 add(v4 a,v4 b){return a+b;}\n' > "$B/v.c"
"$MOSCLANG" --target=mos -mcpu=$CPU -c "$B/v.c" -o "$B/v.o" 2>/dev/null; echo "  clang vector_size(8) : $(ok $?)  (scalarized by backend if yes)"
echo "### done (probe is informational; exit 0) ###"
exit 0
