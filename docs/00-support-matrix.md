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
| `c_int` matches C | — | ✅ (16) | — | ❌ (32) | Zig footgun (exp 03/07) |
| C-compatible struct layout | ✅ | ✅ `#[repr(C)]` | ✅ | ⚠️ `align(1)` | Zig over-aligns (exp 08) |
| Zero-page address space | ✅ AS(1) | ❌ (not exposed) | ❌ | ✅ `.zp` | exp 08 |
| Standard library on MOS | ⚠️ freestanding libc | ⚠️ `core`/`alloc` | ❌ `-betterC` only | ⚠️ `std` partial | docs/01 |
| Inline asm | ✅ | ❌ | ✅ | ✅ | rust-mos#13 (exp 14) |
| LTO required | optional | ✅ required | optional | optional | rust target sets it |
| Float across FFI | ❌ avoid | ❌ avoid | ❌ avoid | ❌ avoid | soft-float rough (llvm-mos#10) |
| Float math (`sqrt`) on MOS | ❌ no `<math.h>` | ❌ std-only | ✅ `core.math` | ✅ `std.math` | soft-float; exp 15 |
| Compile-time eval (CTFE) | ⚠️ C++ `constexpr` only | ✅ `const fn` | ✅ CTFE | ✅ `comptime` | C has none; exp 10 |
| Compile-time reflection | ❌ | ❌ | ✅ `__traits` | ✅ `@typeInfo` | C++ P2996 = C++26; exp 19 |
| File embedding | ✅ `#embed` | ✅ `include_bytes!` | ✅ `import()` | ✅ `@embedFile` | also `.incbin`; exp 18 |
| Compile-time memory safety | ❌ | ✅ | ✅ `@safe` | ⚠️ runtime model | C/C++ none; exp 21 |
| Runtime memory safety | ❌ | ✅ bounds→trap | ❌ betterC | ❌ compiler bug | only Rust on MOS; exp 21 |
| RAII / scope-guard cleanup | ✅ | ✅ `Drop` | ✅ `scope(exit)` | ✅ `defer` | zero-cost, LIFO; exp 22 |
| DWARF debug info | ✅ v5 | ✅ v4 | ✅ v4 | ✅ v4 | no CFI; exp 11 |

**Co-ABI group:** C, C++, Rust, D, and Zig (with `align(1)` structs) are mutually
FFI-safe for scalars, pointers, callbacks and byte-packed structs. The only
hard outlier is Zig's default struct alignment.

**Compile-time leaders:** D and Zig (CTFE/reflection/embedding); C++ has
`constexpr`/`consteval` but no reflection (P2996 is C++26); C has neither.
**Safety leader:** Rust (compile-time *and* working runtime checks on MOS); D
matches the compile-time half via `@safe`.

**CPU coverage:** the backend accepts 14 `-mcpu` values
(`mos6502 mos6502x mos65c02 mosr65c02 mosw65c02 mos65ce02 mos65el02 mos65dtv02
mos4510 mos45gs02 moshuc6280 mosspc700 mossweet16 mosw65816`). All experiments
use the base `mos6502`.
