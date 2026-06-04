#!/usr/bin/env bash
# Cross-language benchmark on llvm-mos: three canonical integer kernels from the
# 6502 benchmark canon (BYTE/Gilbreath sieve, recursive fib, CRC-16/XMODEM),
# implemented identically (same algorithm + u16 types) in C / C++ / Rust / D / Zig.
#
# Metrics are the ones the community C-Bench-64 suite uses -- per-kernel CYCLES
# and code SIZE -- but measured PER FUNCTION, not whole-image: C-Bench's .prg
# sizes are dominated by each toolchain's runtime floor (llvm-mos sits ~6.3 KB
# regardless of kernel), which hides codegen quality. We compare codegen.
#
# Built -fno-lto so each kernel stays a discrete, measurable function (LTO is
# llvm-mos's whole-program default and would inline these away). Cycles bracket
# only the kernel call ($FFF0 before/after), excluding crt0/startup. On llvm-mos
# -Os means "speed without trading size" (its recommended default), so it's the
# fair balanced setting; -Oz / -OReleaseSmall are the D / Zig analogues.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502

"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -fno-lto -c "$HERE/bench_c.c"   -o "$B/c.o"
"$SDKBIN/mos-sim-clang++" -mcpu=$CPU -Os -fno-lto -fno-exceptions -fno-rtti -c "$HERE/bench_cpp.cpp" -o "$B/cpp.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/bench_d.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/bench_zig.zig"
# std.crypto + std.hash pull a large (~50 KB) transitive closure that build-obj
# does not dead-code-eliminate, so these stdlib kernels run in their own binary.
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zigstd.o" "$HERE/bench_zig_std.zig"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust.log" 2>&1 ) \
  || { echo "Rust build FAILED"; tail -8 "$B/rust.log"; exit 1; }
RSA="$(find "$HERE/rust/target" -name 'libbench_rs.a'|head -1)"
( cd "$B" && "$SDKBIN/llvm-ar" x "$RSA" 2>/dev/null )
RSO="$(ls "$B"/*bench_rs*.o 2>/dev/null|head -1)"

# ---- per-kernel CODE SIZE (bytes of the function itself; llvm-nm --print-size) ----
fnsize(){ "$NM" --print-size --radix=d "$1" 2>/dev/null | awk -v f="$2" '$4==f{print $2+0}'; }
echo "### code size: bytes of each kernel function (llvm-nm), per frontend ###"
printf "  %-6s %6s %6s %6s %6s %6s\n" kernel C C++ Rust D Zig
for k in sieve fib crc16; do
  printf "  %-6s %6s %6s %6s %6s %6s\n" "$k" \
    "$(fnsize "$B/c.o" c_$k)" "$(fnsize "$B/cpp.o" cpp_$k)" \
    "$(fnsize "$RSO" rs_$k)" "$(fnsize "$B/d.o" d_$k)" "$(fnsize "$B/zig.o" zig_$k)"
done
# stdlib dimension (Zig only): code bytes of the std-backed kernels + the rodata
# tables they pull in. std.hash.crc is table-based: small code, 512-byte table.
echo "### stdlib (Zig std.hash.crc / std.crypto / std.math): code bytes + tables ###"
printf "  crc16_std=%sB  sha256=%sB  isqrt=%sB   (vs hand-rolled zig crc16=%sB)\n" \
  "$(fnsize "$B/zigstd.o" zig_crc16_std)" "$(fnsize "$B/zigstd.o" zig_sha256)" \
  "$(fnsize "$B/zigstd.o" zig_isqrt)" "$(fnsize "$B/zig.o" zig_crc16)"
printf "  zigstd.o footprint (code + CRC table + SHA-256 K[]): %s\n" \
  "$("$SIZE" "$B/zigstd.o" 2>/dev/null | awk 'NR==2{print "text="$1" data="$2" bss="$3}')"

# ---- per-kernel CYCLES + correctness, on mos-sim ----
echo "### cycles: mos-sim \$FFF0 (kernel call bracketed), and result correctness ###"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -I"$HERE" -o "$B/driver.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/cpp.o" "$B/d.o" "$B/zig.o" "$RSA" -o "$B/bench.elf"
# (no `set -e` in this script: mos-sim returns the *program's* exit code, captured)
"$SDKBIN/mos-sim" "$B/bench.elf"; RC=$?

# ---- stdlib dimension: Zig std on a 6502 (own binary -- heavy std closure) ----
echo "### stdlib (Zig std.hash.crc / std.crypto / std.math) on a 6502: correctness + cycles ###"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver_std.c" -I"$HERE" -o "$B/driver_std.o"
"$SDKBIN/mos-sim-clang" -Os "$B/driver_std.o" "$B/zigstd.o" -o "$B/benchstd.img"
"$SDKBIN/mos-sim" "$B/benchstd.img"; RC2=$?
echo "  (benchstd image = $(wc -c <"$B/benchstd.img") bytes: only Zig reaches CRC/crypto/sqrt from stdlib)"

# ---- bonus: mos6502 vs mos65c02 on the C kernels (size + cycles; under-measured) ----
echo "### bonus: same C kernels, -mcpu=mos65c02 (run --cmos) vs mos6502 ###"
"$SDKBIN/mos-sim-clang" -mcpu=mos65c02 -Os -fno-lto -c "$HERE/bench_c.c" -o "$B/c65.o"
printf "  size   6502: sieve=%s fib=%s crc16=%s    65C02: sieve=%s fib=%s crc16=%s\n" \
  "$(fnsize "$B/c.o" c_sieve)" "$(fnsize "$B/c.o" c_fib)" "$(fnsize "$B/c.o" c_crc16)" \
  "$(fnsize "$B/c65.o" c_sieve)" "$(fnsize "$B/c65.o" c_fib)" "$(fnsize "$B/c65.o" c_crc16)"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU      -Os -I"$HERE" -c "$HERE/driver_c.c" -o "$B/dc.o"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU      -Os "$B/dc.o"  "$B/c.o"  -o "$B/c6502.elf"
"$SDKBIN/mos-sim-clang" -mcpu=mos65c02  -Os -I"$HERE" -c "$HERE/driver_c.c" -o "$B/dc65.o"
"$SDKBIN/mos-sim-clang" -mcpu=mos65c02  -Os "$B/dc65.o" "$B/c65.o" -o "$B/c65c02.elf"
printf "  cycles 6502 : "; "$SDKBIN/mos-sim"        "$B/c6502.elf";  RC3=$?
printf "  cycles 65C02: "; "$SDKBIN/mos-sim" --cmos "$B/c65c02.elf"; RC4=$?

echo "== cross-lang=$RC, Zig-stdlib=$RC2, 6502-bonus=$RC3, 65C02-bonus=$RC4 (all 0 = canonical: 1899 / 46368 / 0x7E55; CRC/SHA-256/sqrt) =="
exit $(( RC || RC2 || RC3 || RC4 ))
