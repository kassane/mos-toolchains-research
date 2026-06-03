#!/usr/bin/env bash
# TMP / compile-time computation parity: factorial(10) via C++ constexpr &
# consteval, D CTFE (enum), Rust const fn. Two results:
#   1. correctness on mos-sim (all return 3628800);
#   2. CTFE is a LANGUAGE GUARANTEE, not an optimization -- at -O0 the C runtime
#      loop stays a loop while constexpr/consteval/CTFE/const-fn still fold to a
#      constant. consteval is the strictest form (immediate fn, ~ Zig comptime).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
CXXSTD=-std=c++20

build(){ # opt suffix
  local O="$1" s="$2"
  "$SDKBIN/mos-sim-clang"   -mcpu=$CPU $O -fno-lto -c "$HERE/tmp_c.c"   -I"$HERE" -o "$B/c$s.o"
  "$SDKBIN/mos-sim-clang++" -mcpu=$CPU $O -fno-lto -fno-exceptions -fno-rtti $CXXSTD -c "$HERE/tmp_cpp.cpp" -I"$HERE" -o "$B/cpp$s.o"
  "$LDC" -betterC $LDC_PE $O -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/tmp_d.d" -of="$B/d$s.o"
}
folded(){ # obj sym
  "$SDKBIN/llvm-objdump" -d --mcpu=$CPU "$1" 2>/dev/null \
   | awk -v f="<$2>:" '/^[0-9a-f]+ <.*>:/{g=index($0,f)?1:0}
       g&&/^ +[0-9a-f]+:/{c++} g&&/\t(jsr|bne|bcc|bcs|beq|bpl|bmi)\t?/{j++}
       END{printf "instrs=%-3d branches/calls=%-2d -> %s", c+0, j+0, (j+0==0&&c+0<15)?"CONST-FOLDED":"runtime"}'
}

( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >/dev/null 2>&1 )
cp "$(find "$HERE/rust/target" -name 'libtmp_rs.a'|head -1)" "$B/librs.a"

echo "### -Os: everyone folds (optimizer agrees with CTFE) ###"
build -Os ""
for s in "c.o:c_fact10" "cpp.o:cpp_fact10" "cpp.o:cpp_fact10_ce" "d.o:d_fact10" "librs.a:rs_fact10"; do
  printf "  %-14s %s\n" "${s##*:}" "$(folded "$B/${s%%:*}" "${s##*:}")"
done

echo "### -O0: CTFE is a LANGUAGE guarantee -- only C (no constexpr) stays a loop ###"
build -O0 "0"
for s in "c0.o:c_fact10" "cpp0.o:cpp_fact10" "cpp0.o:cpp_fact10_ce" "d0.o:d_fact10" "librs.a:rs_fact10"; do
  printf "  %-14s %s\n" "${s##*:}" "$(folded "$B/${s%%:*}" "${s##*:}")"
done

echo "### run on mos-sim ###"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -I"$HERE" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/librs.a" -o "$B/tmp.elf"
set +e; "$SDKBIN/mos-sim" "$B/tmp.elf"; RC=$?; set -e
echo "### exit=$RC (0 = all return 3628800) ###"
exit $RC
