#!/usr/bin/env bash
# Binary/codegen comparison: identical LCG loop in 5 languages -> compare 6502
# disassembly + per-function cycle counts (sim $FFF0 counter). Shared backend
# => expect identical/near-identical code & cycles. LDC gets -mattr=$MOS_MATTR.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502

# native ELF objects (-fno-lto) so we can disassemble per-function 6502 asm
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -fno-lto -c "$HERE/bench_c.c"   -I"$HERE" -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-lto -fno-exceptions -fno-rtti -c "$HERE/bench_cpp.cpp" -I"$HERE" -o "$B/cpp.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/bench_d.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/bench_zig.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >/dev/null 2>&1 )
cp "$(find "$HERE/rust/target" -name 'libbench_rs.a'|head -1)" "$B/librs.a"

echo "### 6502 instruction count per frontend for the SAME loop ###"
for pair in "c.o:c_lcg" "cpp.o:cpp_lcg" "d.o:d_lcg" "zig.o:zig_lcg" "librs.a:rs_lcg"; do
  o="${pair%%:*}"; fn="${pair##*:}"
  "$SDKBIN/llvm-objdump" -d --mcpu=$CPU "$B/$o" 2>/dev/null > "$B/full-$fn.txt" || true
  # every function header resets state (on iff it's ours); print our instr lines
  awk -v f="<$fn>:" '/^[0-9a-f]+ <.*>:/{g=index($0,f)?1:0} g&&/^ +[0-9a-f]+:/{print}' \
      "$B/full-$fn.txt" > "$B/disasm-$fn.txt"
  n=$(grep -cE '^ +[0-9a-f]+:' "$B/disasm-$fn.txt" || true)
  printf "  %-9s %s instructions\n" "$fn" "$n"
done

echo "### build combined timing program & run on mos-sim ###"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -I"$HERE" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/zig.o" "$B/librs.a" -o "$B/bench.elf"
set +e; "$SDKBIN/mos-sim" "$B/bench.elf"; RC=$?; set -e
echo "### exit=$RC (0 = all 5 languages computed identical result) ###"
exit $RC
