# experiments-audit.md — load-bearing-green audit (GAP 2)

Anti-false-green check. `scripts/run-all.sh` calls each experiment's pass/fail the
sole exit code of its `run.sh`. This audit proves that exit 0 is **load-bearing**:
for each experiment a targeted mutation of the *thing under test* was applied
(never the assertion/expected side), `./run.sh` re-run, and the exit code checked.
A mutation that flips it to non-zero ⇒ the green earns its keep (**y**). One that
leaves it green ⇒ the green proves nothing (**n**, flagged below).

Mutations are transient probes (applied → run → `git checkout --` reverted); the
tree is unchanged. **No assertion was relaxed.** Re-run any row by re-applying its
mutation and running that experiment. Audited 2026-06 on the pinned toolchains.

## Result: 25 / 27 load-bearing; 2 flagged (06, 14)

| exp | claim (what exit 0 means) | mutation applied (thing-under-test) | rc | load-bearing |
|--|--|--|:--:|:--:|
| 01-ir-datalayout | shared datalayout; C `int`→`i16`, D/Zig/Rust→`i32` | `add.c`: `int`→`long` (C param now i32) | 1 | y |
| 02-ffi-matrix | 5 langs link into one binary, every cross-call correct | `lib_c.c`: `c_add8` returns `a+b+1` | 2 | y |
| 03-int-width | each lang's true type widths (C int=2, D int=4, …) | `sizes_d.d`: `d_int_bytes` → `short.sizeof` | 2 | y |
| 04-llvm-ir-mix | C→Rust→D→Zig IR pipeline merges (nolto+LTO) → 255 | `step_c.c`: `x+1`→`x+2` | 1 | y |
| 05-codegen-cycles | identical LCG result across 5 langs | `bench_c.c`: `s*31+i`→`s*30+i` | 1 | y |
| 06-cpu-features | `-mattr=$MOS_MATTR` doesn't change base-mos6502 D asm | append `,+mos-insns-w65c02` to the `-mattr` under test | 0 | **n** |
| 07-comptime-abi | each frontend's compile-time ABI asserts hold | `ct_c.c`: assert subject `sizeof(int)==2`→`sizeof(long)==2` | 1 | y |
| 08-struct-abi | all 5 read C `Pkt{u8,u32,u8}` byte-packed, round-trip 0xDEADBEEF | D `Pkt` field reorder → `val` to offset 2 | 1 | y |
| 09-zero-cost | monomorphized generic/HOF == C; `sum16=36`, `apply(5)=20` | D `apply2` lambda `v*2`→`v*3` | 1 | y |
| 10-tmp-parity | constexpr/consteval/CTFE/const-fn `factorial(10)=3628800` | D `d_fact10` → `fact(9)` (assert untouched) | 1 | y |
| 11-dwarf-parity | DWARF emitted: `.debug_info`, addr_size=4, subprogram DIE | C compile `-g`→`-g0` | 1 | y |
| 12-byval-struct | small ≤4B struct decomposes (round-trip 42); Big 8B via sret | D `d_small` drops `p.b` → 40 | 1 | y |
| 13-scalar-callback-abi | i64/signed/fn-ptr callback agree; `apply(triple,10)=31` | Rust `rs_apply` invokes callback with `x+1` | 1 | y |
| 14-feature-probe | capability matrix — "a clean compile = supported" | syntax error in a probe reported "supported" | 0 | **n** |
| 15-std-support | each stdlib computes its value, all co-linked | `c_std.c`: `memset(p,'A',15)`→`14` (strlen 14) | 1 | y |
| 16-mos-sim-realworld | stdin→stdout uppercaser via Zig FFI + cycle count | `upcase.zig`: `c-32`→`c-31` | 1 | y |
| 17-zigcc-rust-linker | 4 outcomes incl. cluster wall; SDK links Rust → 42 | Rust lib `wrapping_sub`→`wrapping_add` (58≠42) | 1 | y |
| 18-embed-file | 6 embed methods → identical byte-sum vs payload.bin | `embed_zig.zig`: sum init `0`→`1` | 1 | y |
| 19-reflection | D & Zig reflect fields=3/sizesum=7/namesum=294 | `refl_d.d`: `d_namesum` `m[0]`→`m.length` | 2 | y |
| 20-mmio-hal | all 5 poke → `sta $fff9`; prints `C+RDZ` | `hal_d.d`: MMIO `0xFFF9`→`0xFFF7` | 134 | y |
| 21-safety | compile rejections + runtime traps (Rust OOB→77, Zig ovf→88) | Rust `a[i]`→`get_unchecked(i)` (OOB no longer traps) | 1 | y |
| 22-raii-scopeguard | LIFO cleanup order (trace "21") in all 5 | `sg_c.c`: C cleanup value `'1'`→`'9'` | 1 | y |
| 23-dynamic-debug | runtime PC→source via DWARF; fib(12)=144 | `fib.c`: `r`→`r+1` (sim exit 145≠144) | 1 | y |
| 24-benchmarks | canonical sieve 1899 / fib 46368 / crc16 0x7E55 | `bench_c.c`: crc16 poly `0x1021`→`0x1031` | 1 | y |
| 25-global-asm-symbols | absolute linker-symbol VALUES + MMIO putchar | `cfg_c.c`: `__cfg_c = 10`→`11` | 1 | y |
| 26-float-runtime | Rust `libm` `sqrtf` gives C/D/Zig sqrt parity → 141 | rename Rust `sqrtf` export → C/D/Zig **fail to LINK** | 1 | y |
| 27-importc | ImportC C `int`=16-bit, `add=42`, by-value `psum=42` | `imc.c`: `add` returns `a+b+1` (43≠42) | 1 | y |

## Non-load-bearing greens (flagged, NOT fixed — needs approval)

Per the hard constraint these are **reported, not patched** (relaxing or papering
over an assertion is forbidden; fixing them is a separate step).

- **06-cpu-features** — pass hinges on `diff`ing D's asm built with vs without
  `-mattr=$MOS_MATTR`. But `$MOS_MATTR` lists exactly the features
  `-mcpu=mos6502` already implies, and LDC's `-mattr` does not alter base-mos6502
  codegen for the LCG source, so **no feature-string change can flip it red**
  (verified: appending `+mos-insns-w65c02` or disabling `-static-stack` both yield
  byte-identical asm). The green proves the diff plumbing runs, not that `-mattr`
  is genuinely inert. The documented conclusion is true; the test just doesn't
  *earn* it. *Fix (proposed):* use a BCD/CMOS-sensitive routine whose codegen
  actually responds to a feature delta, so a real `-mattr` regression diverges.

- **14-feature-probe** — `run.sh` prints each capability probe via `ok $?` but
  **never aggregates the exit codes and always ends in `exit 0`**. A real
  regression (clang losing inline-asm, the `interrupt` attribute, etc.) would
  still report PASS — the green proves only that the script ran. *Fix (proposed):*
  increment a `bad` counter when a capability the matrix asserts "yes" stops
  compiling (and when "no"-expected ones like 32-bit atomic CAS / `vector_size`
  start compiling), then `exit $((bad>0))`.

## Notes

- **exp 12 sret sub-check**: the small-struct-decomposition claim is fully
  load-bearing (above). The companion >4-byte-sret grep is correctly gated
  (`exit $((RC+SRET_BAD))`) but couldn't be flipped by an in-tree source mutation
  because `bv.h` is shared across all five frontends (shrinking `Big` breaks the
  C++ build first); verified sound in isolation (a 4-byte aggregate yields no
  sret marker → the check trips).
- **exp 24 mutation caution**: a wrong *fib* via `n-3` underflows `uint16_t`
  (`n=2 → 65535`) into runaway recursion that *hangs* mos-sim — a non-terminating
  failure, not a clean one. The audit instead perturbs the crc16 polynomial
  (terminates, canonical 0x7E55 fails). The green is load-bearing either way.
