#!/usr/bin/env bash
# Float-sqrt PARITY on the 6502 via the Rust `libm` crate. The SDK libm has no `sqrtf`,
# so Zig std.math.sqrt / D core.math.sqrt / C <math.h> all COMPILE but fail to LINK
# (undefined sqrtf). The Rust `libm` crate (pure-Rust software math) exports `sqrtf`/
# `sqrt` as C symbols — linking it gives ALL FOUR frontends a working sqrt: each computes
# sqrt(2)*100 = 141 on mos-sim. Float arithmetic (+ - * /) already works everywhere
# (soft-float libcalls __mulsf3/__divsf3/__fixsfsi ship in the SDK). docs/13.
# Cast note: the f32->int cast must be NON-saturating (to_int_unchecked / @intFromFloat
# -> __fixsfsi); the saturating cast (`as i32`) hits the unlowerable G_FPTOSI_SAT gap.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502

# Rust libm crate -> shared soft-math provider (exports sqrtf/sqrt) + native rust sqrt.
# (Fetches the `libm` crate from crates.io once; pinned in Cargo.lock.)
( cd "$HERE/mathf-rs" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust.log" 2>&1 ) \
  || { echo "rust build failed (needs network for the libm crate):"; tail -8 "$B/rust.log"; exit 1; }
RSA="$(find "$HERE/mathf-rs/target" -name 'libmathf_rs.a' | head -1)"
[ -n "$RSA" ] || { echo "rust archive missing"; exit 1; }
"$SDKBIN/mos-sim-clang"   -mcpu=$CPU -Os -c "$HERE/sqrt_c.c" -o "$B/c.o"
"$LDC" -betterC $LDC_PE -Oz -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/sqrt_d.d" -of="$B/d.o"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -OReleaseSmall -femit-bin="$B/zig.o" "$HERE/sqrt_zig.zig"
"$SDKBIN/mos-sim-clang" -mcpu=$CPU -Os -c "$HERE/driver.c" -o "$B/driver.o"

echo "### the gap the Rust libm crate fills: C/D/Zig sqrt carry an UNDEFINED sqrtf ###"
for pair in "c.o:C" "d.o:D" "zig.o:Zig"; do o="${pair%%:*}"; n="${pair##*:}"
  "$SDKBIN/llvm-nm" "$B/$o" | grep -qE ' U sqrtf' && echo "  $n  std-math/core-math/<math.h> -> undefined sqrtf"
done
echo "  Rust libm provides: $("$SDKBIN/llvm-nm" "$RSA" | grep -E ' T sqrtf?$' | sed 's/.* T //' | tr '\n' ' ')"

echo "### parity: link all four against the Rust-libm provider, run on mos-sim ###"
"$SDKBIN/mos-sim-clang" -Os "$B/driver.o" "$B/c.o" "$B/d.o" "$B/zig.o" "$RSA" -o "$B/float.elf"
set +e; OUT="$("$SDKBIN/mos-sim" "$B/float.elf")"; RC=$?; set -e
echo "$OUT"
echo "### exit=$RC (0 = all four run sqrt(2)*100=141 via Rust libm + soft-float divide runs) ###"
exit $RC
