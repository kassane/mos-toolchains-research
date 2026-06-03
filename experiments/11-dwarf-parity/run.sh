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
# a DW_TAG_subprogram DIE named dbg_add WITH at least one formal_parameter child,
# counted within that DIE's block (until the next sibling at the same depth).
subprog(){ "$DD" "$1" 2>/dev/null | awk '
   /DW_TAG_subprogram/ {infn=0}
   /DW_AT_name.*"dbg_add"/ {infn=1; hit=1}
   infn && /DW_TAG_formal_parameter/ {p++}
   END { if(hit) printf "yes (%d params)", p+0; else printf "no" }'; }
report(){ printf "  %-6s DWARFv%-2s addr_size=%-2s CFI=%-3s subprogram=%-12s\n    secs: %s\n" \
          "$1" "$(dwver "$2")" "$(addrsz "$2")" "$(hascfi "$2")" "$(subprog "$2")" "$(secs "$2")"; }

echo "### C (clang) ###"
"$MOSCLANG" --target=mos -mcpu=$CPU -g -O0 -c "$HERE/dbg.c" -o "$B/c.o"; report C "$B/c.o"
echo "### D (LDC) ###"
"$LDC" -betterC $LDC_PE -g -O0 -mtriple=mos -mcpu=$CPU -mattr=$MOS_MATTR -c "$HERE/dbg.d" -of="$B/d.o"; report D "$B/d.o"
echo "### Rust (rust-mos; needs lto+debug=2, dev profile fails the G_UCMP gap) ###"
( cd "$HERE/rust" && RUSTC_BOOTSTRAP=1 PATH="$RUSTBIN:$PATH" "$CARGO" build --release >"$B/rust-build.log" 2>&1 ) \
  || echo "  Rust  BUILD FAILED (see build/rust-build.log)"
RSA="$(find "$HERE/rust/target" -name 'libdbg_rs.a'|head -1)"
[ -n "$RSA" ] && ( cd "$B" && "$SDKBIN/llvm-ar" x "$RSA" 2>/dev/null )
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

echo "### parity verdict (derived from the probes above, not hardcoded) ###"
bad=0
for pair in "C:$B/c.o" "D:$B/d.o" "Rust:$RSO" "Zig:$B/zig.o"; do
  lang="${pair%%:*}"; o="${pair##*:}"
  # invariant facts that MUST hold for every frontend (gated):
  "$RE" -SW "$o" 2>/dev/null | grep -q '\.debug_info' || { echo "  FAIL $lang: no .debug_info"; bad=$((bad+1)); }
  [ "$(addrsz "$o")" = 4 ] || { echo "  FAIL $lang: addr_size != 4 (was '$(addrsz "$o")')"; bad=$((bad+1)); }
  [ "$(hascfi "$o")" = no ] || { echo "  FAIL $lang: unexpected CFI (.eh_frame/.debug_frame)"; bad=$((bad+1)); }
  case "$(subprog "$o")" in yes*) ;; *) echo "  FAIL $lang: no dbg_add subprogram DIE"; bad=$((bad+1));; esac
done
# report the DWARF versions actually seen (self-updating, not a stale string)
printf "  observed DWARF versions: C=%s D=%s Rust=%s Zig=%s (all addr_size=4, no CFI)\n" \
  "$(dwver "$B/c.o")" "$(dwver "$B/d.o")" "$(dwver "$RSO")" "$(dwver "$B/zig.o")"
echo "  gaps: Zig Debug needs wrapping ops (safety panic -> returnaddress);"
echo "        Rust dev profile needs lto+debug (non-LTO hits the G_UCMP gap)."
echo "== $bad parity violation(s) (0 = every frontend: DWARF + addr_size=4 + no-CFI + subprogram) =="
exit $((bad>0))
