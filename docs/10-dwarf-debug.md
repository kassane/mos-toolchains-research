# 10 — DWARF / debug-info parity (exp 11)

Does each frontend emit usable debug info for the 6502, and does it agree? One
function (`dbg_add` with two params + a local) compiled with debug info from each
frontend, inspected with `llvm-dwarfdump` / `llvm-readelf`.

## Result

| | DWARF ver | addr_size | CFI | subprogram DIE | distinctive sections |
|--|:--:|:--:|:--:|:--:|--|
| clang | **5** | 4 | none | yes (params) | `.debug_addr`, `.debug_line_str`, `.debug_str_offsets` |
| LDC | **4** | 4 | none | yes (params) | `.debug_pubnames`, `.debug_pubtypes` |
| Rust | **4** | 4 | none | yes (params) | `.debug_aranges` |
| Zig | **4** | 4 | none | yes (params) | `.debug_pubnames`, `.debug_pubtypes` |

All four **do** emit DWARF with a `DW_TAG_subprogram` for `dbg_add` and a working
line table (PC↔line, `is_stmt`/`prologue_end`). Two shared quirks and two gaps:

- **`address_size = 4` everywhere**, although MOS pointers/code addresses are
  **16-bit**. The DWARF claims 4-byte addresses — a debugger taking it literally
  will mis-size pointers. Consistent across all frontends (it's the llvm-mos
  backend's choice), so at least it's uniformly "wrong".
- **No CFI** — no `.eh_frame` / `.debug_frame` in any object. There is no stack
  unwinding on MOS (matches "no backtraces"); the soft/static stack model has no
  CFA description.
- **clang is DWARF 5; everyone else is DWARF 4.** A version-skew a debugger must
  tolerate when a binary mixes objects from several frontends.

## Two debug-build gaps (fixed/worked-around here)

- **Zig `-ODebug` fails** on an ordinary `a + b`:
  `unable to legalize ... @llvm.returnaddress`. Debug-mode safety checks insert an
  overflow trap whose panic handler calls `@returnAddress()`, and the MOS
  GlobalISel backend can't legalize that intrinsic. Use wrapping ops (`+%`) — or
  a release mode — to build with debug info. (The experiment shows both: a
  wrapping `dbg_add` that emits DWARF, and the non-wrapping version that fails.)
- **Rust dev profile fails** the same `G_UCMP` legalization gap as docs/02 (core's
  `Ord::cmp`). Getting DWARF out of rust-mos needs `lto = true` + `debug = 2`
  (release profile); the non-LTO `dev` profile doesn't build.

## Takeaway

Debug info is broadly at parity — every frontend produces inspectable DWARF with
line tables and parameter DIEs — but expect a **DWARF 4/5 version mix**, a
**16-bit-vs-32-bit address-size mismatch**, and **no unwinding**. Symbolic
debugging (Mesen + an ELF→label tool) works; CFI-based backtraces do not.
