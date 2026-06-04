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
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$B/a.d" -of="$B/ad.o" 2>/dev/null; echo "  ldc inline-asm   : $(ok $?)  (LDC uses LLVM-style asm; betterC)"
# Rust: the rust-asm/ crate uses asm! with #![feature(asm_experimental_arch)] +
# register clobbers (incl. the imaginary zero-page reg rc2), built via build-std.
# rust-mos#13 is FIXED in the rebuilt toolchain (2026-06-04), so this COMPILES
# (older builds emitted 'inline assembly is unsupported on this target').
( cd "$HERE/rust-asm" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/ar.err" 2>&1 )
rc=$?
if grep -q 'inline assembly is unsupported on this target' "$B/ar.err"; then
  echo "  rust inline-asm  : NO  (rust-mos#13 — needs the rebuilt toolchain)"
else
  echo "  rust inline-asm  : $(ok $rc)  (asm!/global_asm!/naked_asm! + operands & clobbers, behind #![feature(asm_experimental_arch)]; #13 fixed)"
fi

echo "### asm clobber vocabulary — ONE LLVM-MOS register file, four frontend validators ###"
# Backend regs are identical everywhere (a/x/y, hw-stack s, flags c/v/p/n/z, imaginary
# rc0..255 / rs0..127). What each frontend lets you NAME as a clobber is a frontend
# validation artifact, and the four policies diverge. Representative tokens, accept/REJECT.
cbcc(){ printf 'void f(void){__asm__ volatile("nop":::"%s");}\n' "$1">"$B/cb.c"; "$MOSCLANG" --target=mos -mcpu=$CPU -c "$B/cb.c" -o "$B/cb.o" 2>/dev/null; }
cbz(){  printf 'export fn f() void { asm volatile("nop":::.{ .%s = true }); }\n' "$1">"$B/cb.zig"; "$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/cbz.o" "$B/cb.zig" 2>/dev/null; }
cbd(){  printf 'module cb; import ldc.llvmasm; extern(C) void f() @trusted { __asm("nop","~{%s}"); }\n' "$1">"$B/cb.d"; "$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$B/cb.d" -of="$B/cbd.o" 2>/dev/null; }
RCORE=$(ls "$HERE"/rust-asm/target/mos-unknown-none/release/deps/libcore-*.rlib 2>/dev/null | head -1)
cbr(){ [ -n "$RCORE" ] || return 2; printf '#![no_std]\n#![feature(asm_experimental_arch)]\nuse core::arch::asm;\n#[no_mangle] pub extern "C" fn f(){ unsafe { asm!("nop", out("%s") _, options(nomem,nostack)); } }\n' "$1">"$B/cb.rs"; RUSTC_BOOTSTRAP=1 "$RUSTC" --target mos-unknown-none -Ctarget-cpu=$CPU --crate-type=lib --emit=obj -L "$(dirname "$RCORE")" --extern core="$RCORE" -o "$B/cbr.o" "$B/cb.rs" 2>/dev/null; }
res(){ case "$1" in 0) echo accept;; 2) echo n/a;; *) echo REJECT;; esac; }
printf "  %-7s %-8s %-8s %-8s %-8s\n" token clang zig rust ldc
for t in a c rc2 s foo; do
  cbcc "$t"; c=$?; cbz "$t"; z=$?; cbr "$t"; r=$?; cbd "$t"; d=$?
  printf "  %-7s %-8s %-8s %-8s %-8s\n" "$t" "$(res $c)" "$(res $z)" "$(res $r)" "$(res $d)"
done
echo "  clang=curated allow-list (a/x/y,c/v/p,cc,rc0..255,rs0..127,memory; rejects s/n/z)"
echo "  zig  =struct fields (no imaginary-reg token; s/n/z only with the pending assembly.zig patch — and machine-inert)"
echo "  rust =reg_gpr a/x/y + reg rc2..rc29; flags clobbered-by-default (no per-flag token)"
echo "  ldc  =raw LLVM constraints, NO validation — bogus 'foo'/'rc999' compile but are silently ignored (footgun)"

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
  "$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$cpu -c "$B/g.d" -of="$B/gd.o" 2>/dev/null; d=$?
  "$ZIG" build-obj -target mos-freestanding -mcpu $cpu -OReleaseSmall -femit-bin="$B/gz.o" "$B/g.zig" 2>/dev/null; z=$?
  r=$( "$RUSTC" --print cfg --target mos-unknown-none -Ctarget-cpu=$cpu >/dev/null 2>&1; echo $? )
  printf "  %-9s clang=%s ldc=%s zig=%s rustc-accepts=%s\n" "$cpu" "$(ok $c)" "$(ok $d)" "$(ok $z)" "$(ok $r)"
done

echo "### SIMD/vector type (MOS is scalar 8-bit; expect rejection or scalarization) ###"
printf 'typedef int v4 __attribute__((vector_size(8)));\nv4 add(v4 a,v4 b){return a+b;}\n' > "$B/v.c"
"$MOSCLANG" --target=mos -mcpu=$CPU -c "$B/v.c" -o "$B/v.o" 2>/dev/null; echo "  clang vector_size(8) : $(ok $?)  (scalarized by backend if yes)"
echo "### done (probe is informational; exit 0) ###"
exit 0
