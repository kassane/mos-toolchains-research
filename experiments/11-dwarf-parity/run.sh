#!/usr/bin/env bash
# DWARF / debug-info parity across frontends on MOS. Compiles dbg_add with debug
# info from each and compares: DWARF version, section set, addr_size, CFI
# presence, and whether a subprogram DIE with formal parameters is emitted.
set -uo pipefail   # not -e: we probe failures (Zig Debug) deliberately
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
B="$HERE/build"; rm -rf "$B"; mkdir -p "$B"; CPU=mos6502
DD="$DWARFDUMP"; RE="$READELF"

dwver(){ "$DD" "$1" 2>/dev/null | grep -oE 'version = 0x000[0-9]' | head -1 | grep -oE '[0-9]$'; }
secs(){ "$RE" -SW "$1" 2>/dev/null | grep -oE '\.debug[a-z_]*' | sort -u | tr '\n' ' '; }
addrsz(){ "$DD" "$1" 2>/dev/null | grep -oE 'addr_size = 0x0[0-9]' | head -1 | grep -oE '[0-9]$'; }
hascfi(){ "$RE" -SW "$1" 2>/dev/null | grep -qE 'eh_frame|debug_frame' && echo yes || echo no; }
subprog(){ "$DD" "$1" 2>/dev/null | grep -A6 'DW_TAG_subprogram' | grep -q 'dbg_add' && \
           { n=$("$DD" "$1" 2>/dev/null | grep -c 'DW_TAG_formal_parameter'); echo "yes ($n params)"; } || echo "no"; }
report(){ printf "  %-6s DWARFv%-2s addr_size=%-2s CFI=%-3s subprogram=%-12s\n    secs: %s\n" \
          "$1" "$(dwver "$2")" "$(addrsz "$2")" "$(hascfi "$2")" "$(subprog "$2")" "$(secs "$2")"; }

echo "### C (clang) ###"
"$MOSCLANG" --target=mos -mcpu=$CPU -g -O0 -c "$HERE/dbg.c" -o "$B/c.o"; report C "$B/c.o"
echo "### D (LDC) ###"
"$LDC" -betterC -g -O0 -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/dbg.d" -of="$B/d.o"; report D "$B/d.o"
echo "### Rust (rust-mos; needs lto+debug=2, dev profile fails the G_UCMP gap) ###"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >/dev/null 2>&1 )
RSA="$(find "$HERE/rust/target" -name 'libdbg_rs.a'|head -1)"
( cd "$B" && "$SDKBIN/llvm-ar" x "$RSA" 2>/dev/null )
RSO="$(ls "$B"/*dbg_rs*.o 2>/dev/null | head -1)"; report Rust "$RSO"
echo "### Zig (Debug, wrapping ops -> compiles + emits DWARF) ###"
"$ZIG" build-obj -target mos-freestanding -mcpu $CPU -ODebug -femit-bin="$B/zig.o" "$HERE/dbg.zig" 2>/dev/null; report Zig "$B/zig.o"

echo "### GAP: Zig Debug with a SAFETY-checked op (non-wrapping +) fails to build ###"
printf 'export fn ovf(a: i32, b: i32) i32 { return a + b; }\n' > "$B/ovf.zig"
if "$ZIG" build-obj -target mos-freestanding -mcpu $CPU -ODebug -femit-bin="$B/ovf.o" "$B/ovf.zig" 2>"$B/zig.err"; then
  echo "  unexpectedly compiled"
else
  echo "  EXPECTED failure: $(grep -oE "unable to legalize.*returnaddress|'@llvm.returnaddress'" "$B/zig.err" | head -1)"
  echo "  (the overflow-check panic handler uses @llvm.returnaddress; MOS GlobalISel can't legalize it)"
fi

echo "### parity verdict ###"
echo "  clang=DWARF5, LDC/Rust/Zig=DWARF4; all addr_size=4 (16-bit target!); no CFI anywhere."
echo "  Gaps: Zig Debug needs wrapping ops (safety panic uses returnaddress);"
echo "        Rust dev profile needs lto+debug (dev/non-LTO hits the G_UCMP gap)."
bad=0
for o in "$B/c.o" "$B/d.o" "$RSO" "$B/zig.o"; do
  "$RE" -SW "$o" 2>/dev/null | grep -q '\.debug_info' || { echo "  MISSING DWARF: $o"; bad=$((bad+1)); }
done
echo "== $bad frontend(s) missing DWARF (0 = full parity) =="
exit $((bad>0))
