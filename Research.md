# Cross-language FFI on the MOS 6502 over LLVM-MOS

**Question.** clang, rustc, zig and ldc2 all reach the 6502 through forks of the
unofficial `llvm-mos/llvm-mos` backend. Does one shared backend buy one shared
ABI — can the languages call each other on a 6502, and can their LLVM IRs and
binaries be mixed? Everything below is produced by the `experiments/`, each of
which **executes on the `mos-sim` 6502 simulator** (exit code = pass/fail).

## TL;DR

- **One backend ⇒ one memory model.** All four frontends emit the *byte-identical*
  data layout `e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8`
  (exp 01). 16-bit pointers, 8-bit zero-page pointers (AS 1), everything
  byte-aligned, 8-bit native int.
- **The C ABI is genuinely shared.** C, C++, Rust, D and Zig objects link into a
  single 6502 binary with **0 undefined symbols** and run correctly on the sim,
  including transitive cross-calls D→Rust and Zig→C (exp 02).
- **The holes are at the type level, not the call level.** The keyword `int` is
  16-bit in C but 32-bit in D/Rust/Zig; Zig's `c_int` is 32-bit (≠ C); Zig
  over-aligns struct fields so `extern struct` corrupts by-pointer structs
  (exp 03, 05, 07, 08). Pass fixed-width scalars or byte-aligned structs.
- **IRs mix across LLVM versions.** The LLVM-23 toolchain (SDK, Rust) consumes
  LLVM-22 textual IR from D and Zig and links/LTOs it into a running binary
  (exp 04). Two version clusters, one for bitcode, but ELF is universal —
  `zig cc` can't be the Rust linker because it trips that wall on the SDK's
  bitcode libc (exp 17).
- **Stdlib reach is uneven, and float math inverts the usual order** (docs/13):
  Zig `std` is richest (mem/sort/fmt/meta/math), Rust adds `alloc::Vec` via a
  global allocator, C has full libc but the C++ STL is a stub (no `std::sort`),
  and **only Zig (`std.math`) and D (`core.math`) compute `sqrt` on MOS** — C's
  `<math.h>` and `no_std` Rust can't. mos-sim runs real interactive stdin I/O
  (exp 16).

## 1. The shared substrate (exp 01)

A trivial `add(i32,i32)` compiled by each frontend produces the same
`target datalayout`. That single fact is why FFI is even possible: identical
pointer width, integer/aggregate alignment and endianness across clang 23,
rustc 1.98 (LLVM 23), Zig 0.17 (LLVM 22) and LDC 1.42 (LLVM 22). The MOS C
calling convention lives in the backend (zero-page "imaginary registers"
`__rc0..31` / `__rs0..15`; args in A/X then RC2.., pointers in RS1.., aggregates
>4 bytes by hidden pointer), so every frontend that lowers to this backend
inherits it (docs/02).

## 2. Five languages, one binary (exp 02)

`include/ffi.h` declares five C-ABI functions, one implemented per language;
`driver.c` (C `main`) calls all five and checks results on the sim:

```
c_add8    = 70     [PASS]   C
cpp_mul16 = 768    [PASS]   C++
rs_sub16  = 999    [PASS]   Rust
d_xor16   = 65535  [PASS]   D   -> calls Rust
zig_shl16 = 512    [PASS]   Zig -> calls C
== 0 failures ==   mos-sim exit 0, 0 undefined symbols
```

The link mixes **LLVM-22 native ELF** (D, Zig) with **LLVM-23 LTO bitcode**
(C, C++, Rust — the SDK platforms default to LTO, `-mlto-zp=224`) in one
`mos-sim-clang` invocation. The output ELF `e_machine` is `0x1966` = 6502.

## 3. Where it breaks: types (exp 03, 07)

Same algorithm, fixed-width types → flawless. Same algorithm, language keywords →
silent corruption, because the keyword sizes diverge:

| type | C | D | Zig | Rust |
|------|---|---|-----|------|
| `int` keyword | **2** | **4** | (i32=4) | (i32=4) |
| `long` | 4 | **8** | — | — |
| `c_int` | 2 | — | **4** | 2 |
| `size_t`/`usize` | 2 | 2 | 2 | 2 |
| pointer | 2 | 2 | 2 | 2 |

C `int` is 16-bit (the LLVM-MOS C ABI); D and Rust/Zig keep `int`/`i32` at
32-bit per their language specs. **Zig's `c_int` is 32-bit — it does *not* match
clang's 16-bit `int`** (Zig lacks MOS C-ABI data on the `freestanding` target).
Rust's `core::ffi::c_int` *does* match C. D's `size_t` is 2 bytes — the
historical `i32`-size_t bug (dlang-mos-hello-world#1) is gone in LDC 1.42
(docs/07). Compile-time `static_assert`/`comptime` checks (exp 07) make each of
these self-verifying.

## 4. Where it really breaks: struct alignment (exp 08)

The datalayout says every scalar is byte-aligned (`i32:8`, `a:8`). C, clang-C++,
Rust (`#[repr(C)]`) and D agree: `struct {u8; u32; u8}` is **6 bytes, u32 at
offset 1**. **Zig uses natural alignment** (`@alignOf(u32)==4`), so its
`extern struct` puts the u32 at offset 4 (12 bytes) and *misreads a C-built
struct* — round-tripping `0xDEADBEEF` returns garbage:

```
C/C++/Rust/D/Zig(align1)  size 6   0xDEADBEEF   PASS
Zig(packed)               size 8   0xDEADBEEF   val OK, size!=6 (u48 backing rounds up)
Zig(plain extern)         size 12  0x….22DE     DIVERGES
```

**Fix:** annotate each field `align(1)` (exact C match) — `packed struct` reads
correctly but `@sizeOf` over-rounds. This is the same class of Zig struct-ABI
hole seen on Xtensa, here reproduced at runtime on the 6502.

The **zero-page address space** (datalayout `p1:8:8`) is supported both ways:
Zig `*addrspace(.zp) u8` is 1 byte and `@addrSpaceCast` narrows a 16-bit pointer
into it; clang `__attribute__((address_space(1)))` lowers to `ptr addrspace(1)`.

## 5. Mixing LLVM IR across versions (exp 04)

The SDK ships no `llvm-link`/`opt`, so the linker's LTO is the merge engine — the
real llvm-mos path. A 4-language pipeline (`zig(d(rust(c(x))))`) emits textual
`.ll` from each frontend; **LLVM-23 `clang -x ir` parses the LLVM-22 D and Zig IR
(upgrades on load)** and both a separate-objects link and a cross-language `-flto`
link produce a binary that runs (`pipeline(7)=255`). So: two LLVM **clusters**
(23 = SDK+Rust, 22 = Zig+D) for bitcode purposes, but the newer toolchain reads
the older IR and ELF objects link universally (docs/04).

## 6. Same source, different code (exp 05)

A shared backend does **not** mean identical codegen — the frontend's IR shape
and default opt pipeline dominate. One LCG loop, five languages, identical
result `14836`, but:

| | C | C++ | Rust | D | Zig |
|--|---|-----|------|---|-----|
| instrs | 105 | 105 | 87 | 54 | 47 |
| cycles | 191272 | 191272 | 147225 | 119446 | 111055 |

C/C++ are byte-identical (same frontend); Zig/D are leanest here. Useful as a
caution: "same backend" guarantees *interop*, not *parity*.

## 7. The `ldc2` cpu-features footnote (exp 06)

`ldc2 -mcpu=mos6502` reports `features ''` — the same gap as ldc#4919 (which is
actually about wasm32). On MOS it's **benign**: the backend derives the CPU's
features regardless, and D's 6502 asm is byte-identical with or without
`-mattr=+mos6502,+mos-insns-6502,+mos-insns-6502bcd,+static-stack`. We pass
`-mattr` anyway for parity with clang/rust/zig and for non-base CPUs.

## Practical FFI rules for LLVM-MOS

1. Pin one toolchain set; there is no cross-version ABI-stability promise.
2. Cross boundaries with **fixed-width scalars** (`uint16_t`/`u16`/`ushort`),
   never the `int`/`long` keyword. In Rust use `core::ffi::*`.
3. For structs, keep them byte-packed: C/D/Rust/`#[repr(C)]` are fine; in **Zig
   add `align(1)`** to every non-byte field of an `extern struct`.
4. Prefer passing aggregates **by pointer** (the backend already does for >4 bytes).
5. Link the final image with the **SDK driver** (`mos-*-clang`, LLVM 23) so the
   newer linker can consume every cluster's objects/IR.

See `docs/07` for the upstream issue trail behind each of these.
