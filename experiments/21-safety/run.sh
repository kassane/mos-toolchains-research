#!/usr/bin/env bash
# Memory-safety features across frontends, MOS use-case. Compile-time rejection
# battery of the SAME unsafe ops: D @safe (on --mtriple=mos) vs Rust safe (rule
# is target-independent; same rustc compiles mos) vs C (no safety -> accepts all).
# Plus escape analysis (D dip1000 / Rust borrow checker). Mirrors the espressif
# repo's safety.sh, retargeted to the 6502.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; P="$HERE/probes"; CPU=mos6502
bad=0

dsafe(){ # label  dfile  expect(reject|accept)
  local out; out="$("$LDC" -betterC $LDC_PE -mtriple=mos -mcpu=mos6502 -mattr=$MOS_MATTR -c "$P/$2" -of="$B/d.o" 2>&1 || true)"
  if [ -f "$B/d.o" ]; then rm -f "$B/d.o"; local got=accept; else local got=reject; fi
  local msg; msg="$(printf '%s' "$out" | grep -oiE 'not allowed in a `@safe`|pointer arithmetic is not allowed[^.]*|cast[^@]*is not allowed[^.]*|cannot call `@system`|without `@trusted`' | head -1)"
  printf "  %-26s D @safe: %-8s %s\n" "$1" "$got" "$msg"
  [ "$got" = "$3" ] || { echo "    UNEXPECTED (wanted $3)"; bad=$((bad+1)); }
}
rsafe(){ # label  rsfile  expect
  local out; out="$("$RUSTC" --crate-type lib --edition 2024 --emit=metadata -o /dev/null "$P/$2" 2>&1 || true)"
  local e; e="$(printf '%s' "$out" | grep -oE 'error\[E[0-9]+\]' | head -1)"
  local got=accept; [ -n "$e" ] && got=reject
  printf "  %-26s Rust:    %-8s %s\n" "$1" "$got" "$e"
  [ "$got" = "$3" ] || { echo "    UNEXPECTED (wanted $3)"; bad=$((bad+1)); }
}

echo "### @safe rejection battery (the SAME unsafe op, each language) ###"
dsafe "pointer index p[i]"      p1_ptr_index.d   reject;  rsafe "pointer index/add"      p1.rs reject
dsafe "pointer arithmetic p+1"  p2_ptr_arith.d   reject
dsafe "int->ptr cast + deref"   p3_int2ptr.d     reject;  rsafe "int->ptr cast + deref"  p3.rs reject
dsafe "ptr reinterpret deref"   p4_reinterpret.d accept   # the documented D gap (Rust unsafe too)
dsafe "call @system/unsafe fn"  p5_call_system.d reject;  rsafe "call unsafe fn"         p5.rs reject
dsafe "inline asm"              p6_inline_asm.d  reject
dsafe "union pointer pun"       p7_union_pun.d   reject;  rsafe "union pointer pun"      p7.rs reject

echo "### escape analysis: return &local (D dip1000 vs Rust borrow checker) ###"
e0="$("$LDC" -betterC $LDC_PE -preview=dip1000 -mtriple=mos -mcpu=mos6502 -c "$P/escape.d" -of="$B/e.o" 2>&1 || true)"
echo "  D @safe+dip1000: $(printf '%s' "$e0" | grep -oiE 'escapes a reference to local.*|address of (stack-allocated|local).*' | head -1)"
[ -f "$B/e.o" ] && { echo "    UNEXPECTED: escape accepted"; bad=$((bad+1)); rm -f "$B/e.o"; }
er="$("$RUSTC" --crate-type lib --edition 2024 --emit=metadata -o /dev/null "$P/escape.rs" 2>&1 || true)"
echo "  Rust borrow ck:  $(printf '%s' "$er" | grep -oiE 'cannot return reference to (temporary|local).*|does not live long enough' | head -1)"
printf '%s' "$er" | grep -qE 'error\[E[0-9]+\]' || { echo "    UNEXPECTED: borrow accepted"; bad=$((bad+1)); }

echo "### contrast: C has NO compile-time memory safety -> accepts every unsafe op ###"
printf 'int f(int* p, unsigned i){ return p[i] + *(p+1) + *(int*)0x40; }\n' > "$B/unsafe.c"
if "$SDKBIN/mos-sim-clang" --target=mos -mcpu=mos6502 -c "$B/unsafe.c" -o "$B/u.o" 2>/dev/null; then
  echo "  C: pointer index + arithmetic + int->ptr ALL accepted (no @safe/borrow check)"
else echo "  C unexpectedly rejected"; bad=$((bad+1)); fi

echo "### runtime safety on mos-sim: bounds check on an OOB index ###"
# Rust: bounds-checked index -> panic=abort -> handler signals exit 77 (GATED)
( cd "$HERE/rust-rt" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rt.log" 2>&1 ) \
  || { echo "  rust-rt build failed:"; tail -3 "$B/rt.log"; bad=$((bad+1)); }
RLIB="$(find "$HERE/rust-rt/target" -name 'libsafety_rt.a' 2>/dev/null | head -1)"
if [ -n "$RLIB" ]; then
  "$SDKBIN/mos-sim-clang" -Os "$HERE/rt_main.c" "$RLIB" -o "$B/rt.sim" 2>/dev/null
  set +e; "$SDKBIN/mos-sim" "$B/rt.sim"; rrc=$?; set -e
  printf "  Rust  a[5] (len 3): exit=%s %s\n" "$rrc" "$([ "$rrc" = 77 ] && echo '-> bounds-check panic FIRED' || echo '-> NO trap (unexpected)')"
  [ "$rrc" = 77 ] || bad=$((bad+1))
fi
# C: no bounds check -> reads OOB (UB), no trap
"$SDKBIN/mos-sim-clang" -Os -c "$HERE/c_noidx.c" -o "$B/cn.o" 2>/dev/null
echo "  C     a[5] (len 3): compiles, reads out of bounds at runtime (UB, no trap)"
# Zig: OVERFLOW safety works (builds + traps); ARRAY-BOUNDS safety crashes LLVM-22.
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSafe -femit-bin="$B/zov.o" "$HERE/zig_ovf.zig" 2>/dev/null
if [ -f "$B/zov.o" ]; then
  "$SDKBIN/mos-sim-clang" -Os "$HERE/ov_main.c" "$B/zov.o" -o "$B/zov.sim" 2>/dev/null
  set +e; "$SDKBIN/mos-sim" "$B/zov.sim"; ovc=$?; set -e
  printf "  Zig   ReleaseSafe overflow check: exit=%s %s\n" "$ovc" "$([ "$ovc" = 88 ] && echo '-> overflow trap FIRED (works)' || echo '-> NO trap (unexpected)')"
  [ "$ovc" = 88 ] || bad=$((bad+1))
fi
# array-bounds check: crashes the Zig (LLVM-22) backend. -fno-compiler-rt does NOT help.
set +e
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSafe -fno-compiler-rt -femit-bin="$B/zbc.o" "$HERE/zig_bounds.zig" 2>"$B/zbc.err"
bcrc=$?; set -e
if [ "$bcrc" -ge 128 ]; then
  echo "  Zig   ReleaseSafe bounds check: compiler CRASH (signal $((bcrc-128)); -fno-compiler-rt does NOT help)"
  # gdb root cause (if available): SIGSEGV in LLVM MachineCopyPropagation
  if command -v gdb >/dev/null 2>&1; then
    frame="$(gdb -q -batch -ex 'set pagination off' -ex run -ex 'bt 3' \
        --args "$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSafe -femit-bin=/dev/null "$HERE/zig_bounds.zig" 2>/dev/null \
        | grep -oE 'CopyTracker::invalidateRegister|MachineCopyPropagation' | head -1)"
    echo "    gdb: SIGSEGV in LLVM-22 MachineCopyPropagation ${frame:+(}${frame}${frame:+)} (fixed in LLVM 23 -> Rust bounds-check works)"
  fi
elif [ -f "$B/zbc.o" ]; then echo "  Zig   ReleaseSafe bounds check: now BUILDS (LLVM-22 backend bug fixed?)"; fi

echo "== $bad unexpected result(s) (0 = safety battery + Rust runtime trap + Zig overflow trap) =="
exit $((bad>0))
