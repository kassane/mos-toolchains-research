#!/usr/bin/env bash
# exp 25 — real-world MOS asm idioms across all five frontends, in one binary:
#  (A) global-asm defining an ABSOLUTE linker symbol — the llvm-mos-sdk iNES
#      mapper-config idiom: asm(".globl __x\n__x = N"). Each frontend's mechanism:
#        C/C++  file-scope asm()          Rust  global_asm!
#        Zig    comptime { asm(...); }     D     ldc.llvmasm.__asm_trusted (never-called fn)
#      Verified with llvm-nm: the symbol must be ABSOLUTE ('A'), value = its constant.
#  (B) a real-world inline-asm MMIO putchar (store to $FFF9) with A + memory clobbers.
# The driver reads each frontend's config symbol (for an absolute symbol &sym == value,
# exactly how the NES linker reads __mirroring) and calls each MMIO putchar; on mos-sim.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502

# --- build each frontend's object (global-asm config symbol + inline-asm MMIO putchar) ---
# -fno-lto on the clang steps: the SDK driver defaults to LTO bitcode for `-c`, which
# defers the file-scope asm symbol to link time (nm of bitcode shows `-------- T`). A
# real ELF object materializes the absolute symbol so the (A) nm check below is uniform
# with the other four frontends (which all emit real ELF). The LTO link still works.
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -fno-lto -c "$HERE/cfg_c.c"   -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-lto -fno-exceptions -fno-rtti -c "$HERE/cfg_cpp.cpp" -o "$B/cpp.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/cfg.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/cfg.zig"
( cd "$HERE/cfg-rs" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust-build.log" 2>&1 ) \
  || { echo "rust build failed (see $B/rust-build.log):"; tail -5 "$B/rust-build.log"; exit 1; }
RSA="$(find "$HERE/cfg-rs/target" -name 'libcfg_rs.a'|head -1)"
[ -n "$RSA" ] || { echo "rust archive missing after build"; exit 1; }
cp "$RSA" "$B/librs.a"

# --- (A) each frontend must emit its config as an ABSOLUTE symbol (llvm-nm type 'A') ---
echo "### (A) global-asm config symbols — ABSOLUTE symbol per frontend (llvm-nm) ###"
NM_BAD=0
check_abs(){ # obj symbol
  local line; line="$("$SDKBIN/llvm-nm" "$1" 2>/dev/null | grep -E " $2\$" | head -1)"
  if echo "$line" | grep -qE ' A '; then printf "  %-9s %s\n" "$2" "$line"
  else printf "  %-9s NOT-ABSOLUTE/MISSING (%s)\n" "$2" "${line:-none}"; NM_BAD=1; fi
}
check_abs "$B/c.o"     __cfg_c
check_abs "$B/cpp.o"   __cfg_cpp
check_abs "$B/zig.o"   __cfg_zig
check_abs "$B/librs.a" __cfg_rs
check_abs "$B/d.o"     __cfg_d

# --- (B) link all five + driver, run on mos-sim (verifies the symbol VALUES + putchar) ---
echo "### (B) cross-language link + run on mos-sim ###"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/zig.o" "$B/d.o" "$B/librs.a" -o "$B/cfg.elf"
set +e; OUT="$("$SDKBIN/mos-sim" "$B/cfg.elf")"; RC=$?; set -e
echo "$OUT"
# (B) is checked too: every frontend's inline-asm MMIO putchar must emit its byte.
B_BAD=0; echo "$OUT" | grep -qF 'C+ZRD' || { echo "  (B) MMIO putchar string 'C+ZRD' missing -> a frontend's inline-asm store regressed"; B_BAD=1; }
echo "### exit=$((RC+NM_BAD+B_BAD)) (0 = absolute symbols+values [A] and MMIO 'C+ZRD' [B] all verified) ###"
exit $((RC+NM_BAD+B_BAD))
