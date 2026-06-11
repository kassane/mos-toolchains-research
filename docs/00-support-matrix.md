# 00 — Support matrix

What works, per language, for 6502 FFI over LLVM-MOS. ✅ works · ⚠️ caveat · ❌ no.
Evidence in the linked experiments; all verified on `mos-sim`.

| Capability | C/C++ (clang) | Rust | D (LDC) | Zig | Notes |
|---|:--:|:--:|:--:|:--:|---|
| Reaches 6502 (LLVM-MOS) | ✅ | ✅ | ✅ | ✅ | all *non-upstream* forks |
| Same data layout | ✅ | ✅ | ✅ | ✅ | byte-identical (exp 01) |
| Emit LLVM IR | ✅ `-emit-llvm` | ✅ `--emit=llvm-ir` | ✅ `-output-ll` | ✅ `-femit-llvm-ir` | exp 04 |
| Native ELF object | ✅ | ✅ (staticlib) | ✅ | ✅ | e_machine 0x1966 |
| Links into shared FFI binary | ✅ | ✅ | ✅ | ✅ | 0 undef (exp 02) |
| Calls / called-by other langs | ✅ | ✅ | ✅ | ✅ | D→Rust, Zig→C tested |
| `int` keyword = C's 16-bit | ✅ | ❌ (32) | ❌ (32) | ❌ (32) | use fixed width (exp 03) |
| `c_int` matches C | — | ✅ (16) | — | ✅ (16) | Zig fixed — was 32 on older builds (exp 03/07) |
| C-compatible struct layout | ✅ | ✅ `#[repr(C)]` | ✅ | ⚠️ `align(1)` | Zig over-aligns (exp 08) |
| Zero-page address space | ✅ AS(1) | ❌ (not exposed) | ⚠️ `ldc.llvmasm` IR | ✅ `.zp` | exp 08 |
| Standard library on MOS | ⚠️ freestanding libc | ⚠️ `core`/`alloc` | ❌ `-betterC` only | ⚠️ `std` partial | docs/01 |
| Inline asm | ✅ | ✅ | ✅ | ✅ | Rust via `asm_experimental_arch` (rust-mos#13 fixed); exp 14 |
| LTO required | optional | ✅ required | optional | optional | rust target sets it |
| Float across FFI | ❌ avoid | ❌ avoid | ❌ avoid | ❌ avoid | soft-float rough (llvm-mos#10) |
| Float `sqrt` at runtime | ⚠️ link `libm` crate | ✅ `libm` crate (native) | ⚠️ link `libm` crate | ⚠️ link `libm` crate | arith ✓ all; SDK has no `sqrtf` → the Rust `libm` crate gives all parity (exp 26) |
| Compile-time eval (CTFE) | ⚠️ C++ `constexpr`/`consteval` (C: none) | ✅ `const fn` | ✅ CTFE | ✅ `comptime` | C has none; exp 10 |
| Compile-time reflection | ❌ | ❌ | ✅ `__traits` | ✅ `@typeInfo` | C++ P2996 = C++26; exp 19 |
| File embedding | ✅ `#embed` | ✅ `include_bytes!` | ✅ `import()` | ✅ `@embedFile` | also `.incbin`; exp 18 |
| Compile-time memory safety | ❌ | ✅ | ✅ `@safe` | ⚠️ runtime model | C/C++ none; exp 21 |
| Runtime memory safety | ❌ | ✅ bounds+overflow→trap | ❌ betterC | ✅ w/ `mos_panic` | Zig needs zig-mos-examples' panic handler (default crashes LLVM‑22); exp 21 |
| RAII / scope-guard cleanup | ✅ | ✅ `Drop` | ✅ `scope(exit)` | ✅ `defer` | zero-cost, LIFO; exp 22 |
| DWARF debug info | ✅ v5 | ✅ v4 | ✅ v4 | ✅ v4 | usable (PC→src); no CFI; exp 11/23 |

**Co-ABI group:** C, C++, Rust, D, and Zig (with `align(1)` structs) are mutually
FFI-safe for scalars, pointers, callbacks and byte-packed structs. The only
hard outlier is Zig's default struct alignment.

**Compile-time leaders:** D and Zig (CTFE/reflection/embedding); C++ has
`constexpr`/`consteval`/`constinit` but no reflection (P2996 is C++26); C has neither.
**Safety leader:** Rust (compile-time *and* working runtime checks on MOS); D
matches the compile-time half via `@safe`.

## Gap-closure taxonomy

*How* each gap closed, not just whether — so the engineering cost is visible.
Categories: **pure-composition** (FFI/link only, no rebuild or source change) ·
**runtime-rebuild** (a toolchain/fork rebuild changed runtime behavior) ·
**callconv/frontend-patch** (the frontend's ABI/codegen was patched) ·
**source-workaround** (fixed in user source, toolchain untouched) · **open**
(not closed). Every row cites a re-runnable experiment; an entry without evidence
would be marked `unverified` (none currently are).

| gap | how it closed | evidence |
|--|--|--|
| soft-float `sqrtf` absent in SDK libm | **pure-composition** — link the Rust `libm` crate (exports C `sqrtf`/`sqrt`); C/D/Zig sqrt then resolve, no rebuild | exp 26 |
| cross-LLVM-version IR mixing (Zig 22 ↔ rest 23) | **pure-composition** — newer SDK driver parses/LTOs the older textual IR; link with the newest toolchain | exp 04 |
| by-value struct ≤4B passed indirect → garbage | **callconv/frontend-patch** — D (LDC) & Rust callconv rebuilds decompose ≤4B aggregates into registers | exp 12 |
| Rust inline asm rejected on MOS | **callconv/frontend-patch** — rust-mos#13 fixed in the rebuild (`asm!`/`global_asm!`/`clobber_abi("C")`) | exp 14 |
| Zig `c_int` = 32-bit (≠ C's 16) | **runtime-rebuild** — rebuilt 0.17-dev Zig gained MOS C-ABI data → `c_int` = 16 | exp 03, 07 |
| LDC `size_t` was ≥32-bit | **runtime-rebuild** — fixed in LDC 1.42 → `size_t` = 2 (pointer width) | exp 03 |
| Zig `extern struct` over-aligns (`u32` → offset 4) | **source-workaround** — `align(1)` per field, or pass by pointer | exp 08 |
| D has no first-class zero-page (AS1) pointer type | **source-workaround** — `ldc.llvmasm.__ir` injects `ptr addrspace(1)` (→ `lda/sta $nn`, runs on sim) | exp 08 |
| Zig ReleaseSafe bounds-check default panic crash | **source-workaround** — use the `mos_panic` handler (zig-mos-examples) | exp 21 |
| `int` keyword width (C 16 vs D/Rust/Zig 32) & `c_int` semantics | **open / by-design** — language specs differ; cross with fixed-width types | exp 01, 03 |
| CFI / stack unwinding (`.eh_frame` not emitted) | **open** — designed upstream (llvm-mos PR #519, dual-stack CFA), unmerged | exp 11 |
| `__builtin_return_address` / `@returnAddress` | **open** — no MOS lowering in either LLVM cluster | exp 11 |

**CPU coverage:** the backend accepts 14 `-mcpu` values
(`mos6502 mos6502x mos65c02 mosr65c02 mosw65c02 mos65ce02 mos65el02 mos65dtv02
mos4510 mos45gs02 moshuc6280 mosspc700 mossweet16 mosw65816`). All experiments
use the base `mos6502`.
