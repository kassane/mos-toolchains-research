#!/usr/bin/env bash
# Struct ABI round-trip: a C-defined struct {u8,u32,u8} is read back by each
# language's matching struct (extern struct / repr(C) / D struct). All must see
# the SAME byte-packed layout (sizeof 6, val@offset1) or FFI corrupts. Also
# probes the zero-page address space (datalayout p1:8:8 => 8-bit ZP pointers).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -c "$HERE/p_c.c"   -I"$HERE" -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-exceptions -fno-rtti -c "$HERE/p_cpp.cpp" -I"$HERE" -o "$B/cpp.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/p_d.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/p_zig.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >/dev/null 2>&1 )
cp "$(find "$HERE/rust/target" -name 'libp_rs.a'|head -1)" "$B/librs.a"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -I"$HERE" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/zig.o" "$B/librs.a" -o "$B/pkt.elf"
set +e; "$SDKBIN/mos-sim" "$B/pkt.elf"; RC=$?; set -e

echo "### zero-page address space (datalayout p1:8:8) ###"
# Zig: native .zp address space; clang: AS(1) attribute
cat > "$B/zp.zig" <<'ZEOF'
export fn zp_ptr_bytes() u8 { return @sizeOf(*addrspace(.zp) u8); }
export fn normal_ptr_bytes() u8 { return @sizeOf(*u8); }
// "addrspace from u16": narrow a normal 16-bit AS(0) pointer into the 8-bit
// zero page with @addrSpaceCast, and build one straight from an integer addr.
export fn to_zp(p: *u8) *addrspace(.zp) u8 { return @addrSpaceCast(p); }
export fn zp_from_int(a: u8) *addrspace(.zp) u8 { return @ptrFromInt(a); }
ZEOF
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -fno-emit-bin -femit-llvm-ir="$B/zp.ll" "$B/zp.zig"
echo "  Zig  *addrspace(.zp) u8 -> $(grep -oE 'ret i8 1' "$B/zp.ll" >/dev/null && echo '1 byte' || echo 'see zp.ll') ; normal *u8 -> 2 bytes"
echo "  Zig  @addrSpaceCast(*u8 -> .zp): $(grep -oE 'addrspacecast' "$B/zp.ll" | head -1 || echo 'folded') (16-bit ptr narrowed to 8-bit zero-page)"
printf 'int rd(__attribute__((address_space(1))) char *p){return *p;}\n' > "$B/zp.c"
if "$MOSCLANG" --target=mos -mcpu=$CPU -S -emit-llvm "$B/zp.c" -o "$B/zp_c.ll" 2>/dev/null; then
  echo "  clang AS(1) ptr in IR: $(grep -oE 'ptr addrspace\(1\)' "$B/zp_c.ll" | head -1) (8-bit zero-page pointer)"
fi
# D: no first-class addrspace pointer type, but ldc.llvmasm.__ir injects ptr
# addrspace(1). Prove it lowers to real zero-page opcodes AND round-trips on mos-sim.
ZP_BAD=0
cat > "$B/zp_d.d" <<'DEOF'
import ldc.llvmasm;
extern(C) ubyte d_zp_roundtrip(ubyte v) {     // save $40, write v, read back, restore
    return __ir!(`%p = inttoptr i8 64 to ptr addrspace(1)
                  %o = load volatile i8, ptr addrspace(1) %p
                  store volatile i8 %0, ptr addrspace(1) %p
                  %r = load volatile i8, ptr addrspace(1) %p
                  store volatile i8 %o, ptr addrspace(1) %p
                  ret i8 %r`, ubyte)(v);
}
DEOF
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR --output-ll -of="$B/zp_d.ll" -c "$B/zp_d.d" 2>/dev/null
grep -qE 'ptr addrspace\(1\)' "$B/zp_d.ll" \
  && echo "  D    ldc.llvmasm.__ir -> ptr addrspace(1) (no first-class type; ldc.dcompute's typed Pointer needs -mdcompute-targets)" \
  || { echo "  D    AS(1) MISSING in IR"; ZP_BAD=1; }
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$B/zp_d.d" -of="$B/zp_d.o" 2>/dev/null
echo "  D    AS(1) codegen: $("$SDKBIN/llvm-objdump" -d --mcpu=mos6502 "$B/zp_d.o" | grep -oE '(lda|sta)[[:space:]]+\$40' | tr '\n' ' ')(6502 zero-page)"
printf 'extern unsigned char d_zp_roundtrip(unsigned char);\nint main(void){return d_zp_roundtrip(123);}\n' > "$B/zpd_drv.c"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$B/zpd_drv.c" -o "$B/zpd_drv.o"
"$SDKBIN/mos-sim-clang" -Os "$B/zpd_drv.o" "$B/zp_d.o" -o "$B/zpd.elf"
set +e; "$SDKBIN/mos-sim" "$B/zpd.elf"; ZPRC=$?; set -e
echo "  D    AS(1) on mos-sim: round-trip 123 -> exit $ZPRC $([ "$ZPRC" = 123 ] && echo OK || echo FAIL)"
[ "$ZPRC" = 123 ] || ZP_BAD=1
echo "### exit=$((RC+ZP_BAD)) (0 = struct layout agrees + D reaches zero-page AS(1)) ###"
exit $((RC+ZP_BAD))
