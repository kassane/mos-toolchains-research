# 10 — DWARF / debug-info parity, CFI & dynamic debug (exp 11, 23)

Does each frontend emit usable debug info for the 6502, does it agree, and is it
*usable* at runtime? One function (`dbg_add`, two params + a local) compiled with
`-g` from each frontend, inspected with `llvm-dwarfdump`/`llvm-readelf` (exp 11);
plus a runtime PC→source round-trip on `mos-sim` (exp 23). All facts below are
backed by tool output; upstream status is cited to llvm-mos PRs.

## Result — static DWARF (exp 11)

| | DWARF ver | addr_size | CFI | subprogram DIE | distinctive sections |
|--|:--:|:--:|:--:|:--:|--|
| clang | **5** | 4 | none | yes (params) | `.debug_addr`, `.debug_line_str`, `.debug_str_offsets` |
| LDC | **4** | 4 | none | yes (params) | `.debug_pubnames`, `.debug_pubtypes` |
| Rust | **4** | 4 | none | yes (params) | `.debug_aranges` |
| Zig | **4** | 4 | none | yes (params) | `.debug_pubnames`, `.debug_pubtypes` |

All four emit DWARF with a `DW_TAG_subprogram` for `dbg_add` and a working line
table (PC↔line, `is_stmt`/`prologue_end`). Locals get locations: the frame base
is `DW_AT_frame_base (DW_OP_regx RS0)` (the soft-stack imaginary register) and
statics use `DW_OP_addrx` — a direct consequence of `+static-stack` (no
`.debug_loclists`). `DW_TAG_call_site` DIEs are present (the closest thing to
backtrace metadata MOS emits).

## Two shared quirks

- **`address_size = 4` everywhere, though MOS pointers/code are 16-bit.** This is
  *deliberate*, not an oversight: [PR #351](https://github.com/llvm-mos/llvm-mos/pull/351)
  (Sep 2023) set `CodePointerSize = 4` in `MOSMCAsmInfo.cpp` because llvm-mos ELF
  uses 4-byte pointers to carry **banking** info, and the DWARF header must agree
  with the line-table pointers. A *generic* DWARF consumer that trusts `addr_size`
  literally still mis-sizes 16-bit pointers — but llvm-mos's **own lldb** now
  compensates on the consumer side: [PR #524](https://github.com/llvm-mos/llvm-mos/pull/524)
  (Jan 2026) made lldb treat MOS addresses as 2 bytes (`ArchSpec.cpp`), *without*
  changing what clang emits. So the emitted `4` is unchanged; the fix lives in the
  debugger.
- **clang is DWARF 5; LDC/Rust/Zig are DWARF 4.** Purely frontend-driven (no
  llvm-mos backend override) — a version skew a debugger must tolerate when a
  binary mixes objects from several frontends.

## No CFI — but designed, not infeasible (the headline)

No frontend emits `.eh_frame`/`.debug_frame`, and **it cannot be forced**: clang
silently accepts `-funwind-tables` and `-fasynchronous-unwind-tables` yet emits
**zero `.cfi_` directives** (exp 11), and `clang++ -fexceptions` is *rejected*
(`error: cannot use 'throw' with exceptions disabled`) — there is no unwinder, so
C++ EH is hard-off. The backend has no CFI emission at all (upstream `main`'s
`MOSFrameLowering.cpp`/`MOSAsmPrinter.cpp` emit no `MCCFIInstruction`;
`MOSMCAsmInfo` leaves `ExceptionsType = None`).

But "no CFI" is now a *not-yet*, not a *can't*: as of mid-2026 there is an active,
documented effort to add it.

- The official **[DWARF implementation guide](https://llvm-mos.org/wiki/DWARF_implementation_guide)**
  describes a **dual-stack CFA** — return address on the hardware stack (S, at
  `$0100–$01FF`), locals on the soft stack (RS0) — recovered with
  `DW_CFA_def_cfa_expression` / `DW_CFA_expression` / `DW_CFA_val_expression`. So
  the soft/static-stack model *does* have a workable CFA description.
- **[PR #519](https://github.com/llvm-mos/llvm-mos/pull/519)** (Dec 2025)
  implemented CFI emission in `MOSFrameLowering`, `.debug_frame` GC in LLD, and an
  LLDB MOS ABI **unwind** plugin (DWARF numbers for A/X/Y/S/P/PC + imaginary
  registers). It was **closed only to be split into smaller PRs** (maintainer:
  "it will go smaller and smaller until eventually landed") — *not* rejected on
  feasibility. Enabling fixes have merged (#535 legalizer terminal actions for
  debug builds, #540 RS8 spill scratch, the lldb-side #521/#522/#524), but the
  **CFI-emission core is not yet merged**, so the pinned SDK still emits none.

## Two debug-build gaps (both still live on the pinned toolchains)

- **`@llvm.returnaddress` has no MOS lowering — in *both* LLVM clusters.** Zig
  `-ODebug` on a non-wrapping `a + b` fails (`unable to legalize … @llvm.returnaddress`:
  the overflow-check panic handler calls `@returnAddress()`), and so does **SDK
  clang 23** on `__builtin_return_address(0)` (same legalize error). Upstream
  [PR #536](https://github.com/llvm-mos/llvm-mos/pull/536) fixed a related bug (an
  `i16` depth arg where the intrinsic needs `i32`), but it did **not** add a MOS
  *lowering* for the intrinsic — so backtrace primitives remain unavailable on
  either cluster (verified, exp 11). Build with wrapping ops (`+%`) or a release
  mode to get DWARF out of Zig.
- **Rust dev profile fails the `G_UCMP` gap.** Building rust-mos `core` without LTO
  still hits `unable to legalize G_UCMP s8 from s32` in
  `core::panic::Location::cmp` (verified on rust-mos 1.98/LLVM 23). Upstream added
  generic `G_UCMP` legalization in LLVM 20, but it does **not** cover this
  narrowing on the MOS GlobalISel path — so `lto = true` + `debug = 2` remains
  required (LTO defers codegen and dodges it).

## Dynamic debug works: line tables are *usable*, not just inspectable (exp 23)

The line tables aren't decoration. `mos-sim --profile` attributes cycles per PC
and `--trace` dumps per-instruction PC + A/X/Y/S + decoded status flags; feeding
those runtime PCs to **`llvm-symbolizer --obj=<elf>`** (or `llvm-addr2line`)
resolves them back to source. exp 23 builds `fib` with `-g`, profiles it, and the
hottest PCs round-trip to `fib.c:9` (the recursive line) — a runtime→source map on
the simulator. For emulator debugging, the SDK ships **`llvm-mlb`** (the concrete
"ELF→Mesen label" tool), and upstream targets **LLDB over an emulator's
GDB-remote stub** (MAME) as the source-level path.

## Takeaway

Debug info is broadly at parity — every frontend emits inspectable DWARF with line
tables and parameter DIEs, *usable* for runtime→source on `mos-sim` — but expect a
**DWARF 4/5 mix**, a deliberate (lldb-compensated) **`addr_size = 4`**, and **no
CFI / no unwinding today**. The no-CFI gap is being actively closed upstream
(designed dual-stack CFA + PR #519 splitting into merges), so it is a *not-yet*.
Symbolic + dynamic debugging work now; CFI-based backtraces do not.
