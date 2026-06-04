# HANDOFF.md — status

State of the `mos-research-ai` test bed. All claims are backed by re-runnable
experiments that execute on `mos-sim`.

## Done

- [x] 4 toolchains pinned + scripted (`scripts/setup.sh`): SDK clang 23, rust-mos
      1.98 (LLVM 23), Zig 0.17-mos (LLVM 22), LDC 1.42 (LLVM 22).
- [x] `scripts/env.sh` + `scripts/run-all.sh`; **24/24 experiments pass** (exit 0).
      All LDC calls carry `$LDC_PE` (`-preview=all --edition=2025`); Rust crates
      on edition 2024.
- [x] Compile-time file embedding 6 ways — C/C++ `#embed`, Rust `include_bytes!`,
      D `import()`, Zig `@embedFile`, asm `.incbin` — all identical bytes (exp 18).
- [x] Compile-time reflection: D & Zig enumerate fields/names (`__traits`/`@typeInfo`);
      C/C++/Rust only `sizeof` (P2996 not in clang 23; Rust = build-time macro) (exp 19).
- [x] MMIO HAL parity (mos-hardware/mega65-libc pattern): all 5 frontends emit
      identical `sta $fff9` for a volatile register poke (exp 20).
- [x] Memory safety (exp 21): compile-time `@safe`/borrow rejection battery (D
      rejects 6/7, Rust all; C none) + escape analysis on MOS; runtime bounds
      check — Rust traps (exit 77); Zig `ReleaseSafe` traps for overflow (88)
      AND array-bounds (77) when using the zig-mos-examples `mos_panic` handler;
      the default/FullPanic handler crashes LLVM-22 `MachineCopyPropagation`
      (gdb-confirmed; `-fno-compiler-rt` doesn't help; fixed in LLVM 23).
- [x] RAII / scope guards (exp 22): LIFO cleanup in all 5 (zero-cost, no unwind);
      Zig `errdefer` (error-path only); D `scope(exit)` + `~this()` +
      `extern(C++,class)` RAII + move-semantics (`@disable this(this)`/`this()`);
      D `scope(success/failure)` rejected in betterC.
- [x] Shared datalayout proven across all 4 frontends (exp 01).
- [x] 5-language FFI binary links (0 undef) and runs on mos-sim, with D→Rust and
      Zig→C cross-calls (exp 02).
- [x] Type-width divergences characterized at runtime + compile time (exp 03, 07).
- [x] Cross-LLVM-version IR mixing + cross-language LTO (exp 04).
- [x] Codegen/cycle comparison (exp 05); `ldc -mattr` parity (exp 06).
- [x] Benchmark suite (exp 24): BYTE sieve / recursive fib / CRC-16 in all 5
      (canonical 1899 / 46368 / 0x7E55), per-kernel cycles + size -- codegen spread
      is real and size/speed **inverts** (Zig smallest code, often slowest; D's
      crc16 largest but fastest). Aligns with C-Bench-64 (llvm-mos > cc65, 2nd to
      Oscar64). + Zig `std.hash.crc` / `std.crypto` SHA-256 / `std.math` run on a
      6502 (only Zig reaches them); 6502-vs-65C02 measured (not a uniform win).
- [x] Struct-ABI hole (Zig over-alignment) reproduced + fixed; zero-page address
      space incl. `@addrSpaceCast` from a 16-bit pointer (exp 08).
- [x] Zero-cost abstractions: C++ template ties C, lambdas/closures inline away;
      Rust slice-sum heavier but still static dispatch (exp 09).
- [x] TMP / CTFE parity: constexpr/consteval/CTFE/const-fn fold at `-O0`
      (language guarantee), C doesn't; D introspection strongest (exp 10).
- [x] DWARF/debug parity (objdump/dwarfdump/readelf): clang=DWARF5, others=DWARF4,
      addr_size=4 (deliberate ELF-banking; lldb compensates), no CFI — and CFI is
      **unforceable** (`-funwind-tables`/`-fexceptions` emit 0 `.cfi_`), though
      designed upstream (PR #519, dual-stack CFA); `@llvm.returnaddress` has no MOS
      lowering in **either** cluster; Zig-Debug & Rust-dev G_UCMP gaps (exp 11).
- [x] Dynamic debug (exp 23): DWARF line tables are *usable* — `mos-sim --profile`/
      `--trace` runtime PCs symbolize back to source via `llvm-symbolizer`/`addr2line`.
- [x] By-value struct ABI found by IR reverse-engineering: C/C++/Zig **and now Rust**
      decompose ≤4B structs to registers; **D** still passes indirect → garbage. Rust
      was fixed by the 2026-06-04 rust-mos callconv rebuild (exp 12).
- [x] Extended scalar/callback ABI (i64, signed, fn-pointer) shared by all 5 (exp 13).
- [x] Feature/capability probe: inline-asm (all 4 — rust via `asm_experimental_arch`), interrupts, atomics(8-bit),
      multi-CPU 65c02/w65816, SIMD ✗ (exp 14).
- [x] Stdlib reach + float math (exp 15): C libc / C++ STL subset (no sort) / Zig
      std (richest: mem,sort,fmt,meta,math) / Rust `alloc::Vec` / D core.stdc+ldc.
      Float `sqrt`: Zig `std.math` & D `core.math` ✓; C `<math.h>` & no_std Rust ✗.
- [x] Real-world mos-sim I/O (exp 16): interactive stdin filter (libc getchar +
      Zig FFI) + `$FFF0` cycle counting. (Heap malloc is exercised in exp 15.)
- [x] `zig cc` as Rust linker (exp 17): compiles MOS objs, links native LLVM-23
      ELF, but the SDK's LLVM-23 *bitcode* libc trips zig's LLVM-22 lld (cluster
      wall); use the SDK driver. Documented in docs/04.
- [x] Docs `00..14`, README, Research, CLAUDE. rust-mos version noted as 1.98.0-dev.

## Key results (the numbers a reviewer will check)

| | result |
|--|--------|
| datalayout (all 4) | `e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8` |
| FFI matrix | mos-sim exit 0, 0 undefined symbols, ELF e_machine `0x1966` |
| `int` width | C 2 / D 4 / Rust i32 4 / Zig i32 4; Zig `c_int` 4 (≠ C 2); Rust `c_int` 2 |
| struct `{u8,u32,u8}` | C/C++/Rust/D/Zig-align1 = 6 B ok; Zig plain = 12 B garbage |
| by-value small struct | C/C++/Zig/Rust decompose→registers; D indirect→garbage (Rust fixed 2026-06; exp 12) |
| i64/signed/callback | shared across all 5 (exp 13) |
| DWARF | clang v5, LDC/Rust/Zig v4, addr_size=4, no CFI (exp 11) |
| same loop | identical result 14836; cycles C 191272 … Zig 111055 |
| benchmark (exp 24) | sieve/fib/crc16 identical across 5 langs; size/speed inverts; SHA-256 from Zig `std.crypto` runs on a 6502 |

## Known limitations / gaps (honest)

- **Floating point not exercised across FFI** — soft-float on MOS is rough
  (llvm-mos#10); the matrix deliberately uses integers/pointers only.
- **No real hardware** — verification is the `mos-sim` simulator (cycle-accurate
  enough for ABI/behavior; not a C64/NES runtime test).
- **Zig↔C struct passing** only safe with `align(1)` fields; by-value large
  structs not stress-tested beyond the round-trip in exp 08.
- **rust-mos `core` native codegen** trips `G_UCMP` legalization; worked around
  with `lto = true` (re-verified mid-2026: still fails without LTO on rust-mos
  LLVM 23 — the upstream generic-legalize fix doesn't cover the MOS narrowing
  path). Not all of `core`/`alloc` was exercised.
- **`ldc#4919` premise** in the task was about wasm32, not MOS; recorded in docs/07.

## Next steps (if resumed)

- Interrupt-handler **codegen** experiment: exp 14 already proves the `interrupt` /
  `no_isr` attributes compile (and that Rust now has inline asm + `clobber_abi("C")`,
  rust-mos#13 fixed); the
  remaining high-signal work is diffing the `interrupt` vs `interrupt_norecurse` vs
  `no_isr` epilogues (the SDK's `interrupt` attr emits `rti` + imaginary-reg
  save/restore).
- Try a non-base CPU (`mosw65816`, `mos65c02`) end-to-end to see if `-mattr`
  starts to matter (exp 06 only covers base mos6502).
- A C64 `.prg` build (mos-c64-clang) running in VICE for a hardware cross-check.
- Re-check CFI once llvm-mos#519's split-out PRs land the `.debug_frame`/CFI core
  (dual-stack CFA emission); demo `llvm-mlb` ELF→Mesen labels for source debug.
