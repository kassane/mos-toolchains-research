#!/usr/bin/env bash
# Zero-cost abstractions: monomorphized generic `sum` + higher-order `apply2`
# in C++/D/Rust vs a hand-written C baseline. Compares per-symbol 6502
# instruction counts (zero-cost => abstraction ~matches C) and runs on mos-sim.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -fno-lto -c "$HERE/zc_c.c"   -I"$HERE" -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-lto -fno-exceptions -fno-rtti -std=c++17 -c "$HERE/zc_cpp.cpp" -I"$HERE" -o "$B/cpp.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/zc_d.d" -of="$B/d.o"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >/dev/null 2>&1 )
cp "$(find "$HERE/rust/target" -name 'libzc_rs.a'|head -1)" "$B/librs.a"

echo "### per-symbol 6502 instruction count (zero-cost => ~= C baseline) ###"
ic(){ "$SDKBIN/llvm-objdump" -d --mcpu=$CPU "$1" 2>/dev/null \
      | awk -v f="<$2>:" '/^[0-9a-f]+ <.*>:/{g=index($0,f)?1:0} g&&/^ +[0-9a-f]+:/{c++} END{print c+0}'; }
printf "  %-12s sum16=%s  apply=%s\n" "C"    "$(ic "$B/c.o" c_sum16)"   "$(ic "$B/c.o" c_apply)"
printf "  %-12s sum16=%s  apply=%s\n" "C++"  "$(ic "$B/cpp.o" cpp_sum16)" "$(ic "$B/cpp.o" cpp_apply)"
printf "  %-12s sum16=%s  apply=%s\n" "D"    "$(ic "$B/d.o" d_sum16)"   "$(ic "$B/d.o" d_apply)"
printf "  %-12s sum16=%s  apply=%s\n" "Rust" "$(ic "$B/librs.a" rs_sum16)" "$(ic "$B/librs.a" rs_apply)"

echo "### run on mos-sim ###"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -I"$HERE" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/librs.a" -o "$B/zc.elf"
set +e; "$SDKBIN/mos-sim" "$B/zc.elf"; RC=$?; set -e
echo "### exit=$RC (0 = all abstractions produce correct results) ###"
exit $RC
