#!/usr/bin/env bash
# RAII / scope-guard parity: each frontend registers two cleanups in a scope;
# all must fire LIFO at scope exit (trace "21"), verified on mos-sim. Covers
# C __attribute__((cleanup)), C++ dtor RAII, Rust Drop, D scope(exit), Zig defer.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -c "$HERE/sg_c.c"   -I"$HERE" -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-exceptions -fno-rtti -c "$HERE/sg_cpp.cpp" -I"$HERE" -o "$B/cpp.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/sg_d.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/sg_zig.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust.log" 2>&1 ) \
  || { echo "rust build failed:"; tail -5 "$B/rust.log"; exit 1; }
RSA="$(find "$HERE/rust/target" -name 'libsg_rs.a'|head -1)"; [ -n "$RSA" ] || { echo "no rust archive"; exit 1; }
cp "$RSA" "$B/librs.a"
# D scope(success)/scope(failure) are REJECTED in betterC (need exceptions) -- probe
printf 'module x; extern(C) void trace(char);\nextern(C) void g(){ scope(failure) trace(70); }\n' > "$B/sf.d"
if "$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -c "$B/sf.d" -of="$B/sf.o" 2>"$B/sf.err"; then
  echo "  note: D scope(failure) unexpectedly compiled in betterC"
else
  echo "  D scope(failure)/scope(success): rejected in betterC (need exceptions) -> only scope(exit) on MOS"
fi
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -I"$HERE" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/zig.o" "$B/librs.a" -o "$B/sg.elf"
set +e; "$SDKBIN/mos-sim" "$B/sg.elf"; RC=$?; set -e
echo "### exit=$RC (0 = all scope-guard/RAII mechanisms fire as documented) ###"

echo "### D move-semantics for RAII guards (compile-time, on mos) ###"
reject(){ # label  dsource  expect-substr
  printf 'module x;\n%s\n' "$2" > "$B/m.d"
  out="$("$LDC" -betterC $LDC_PE -mtriple=mos -mcpu=$CPU -c "$B/m.d" -of="$B/m.o" 2>&1 || true)"
  if [ -f "$B/m.o" ]; then echo "  $1: UNEXPECTEDLY compiled"; rm -f "$B/m.o"; RC=1; else
    echo "  $1: rejected ($(printf '%s' "$out" | grep -oiE "$3" | head -1))"; fi
}
reject "@disable this(this) -> non-copyable (move-only)" \
       'struct M{int c; @disable this(this);} int f(){M a={1}; M b=a; return b.c;}' \
       'not copyable because it has a disabled postblit'
reject "@disable this() -> no default construction" \
       'struct N{int x; @disable this(); this(int v){x=v;}} int f(){N n; return n.x;}' \
       'default construction is disabled'
echo "  (move-only + non-default-constructible structs = ownership-safe RAII guards)"
exit $RC
