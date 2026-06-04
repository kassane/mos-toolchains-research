# 05 — Type widths & struct ABI (exp 03, 07, 08)

This is where "shared backend" stops being enough. The backend agrees on the
*memory model* (docs/02); the **frontends disagree on what their types mean**.

## Scalar widths (exp 03, runtime `sizeof` on mos-sim)

```
type        C   D   Zig Rust
int/i32 kw  2   4   -   -     <- C 'int'  vs D 'int'  DIFFER (footgun)
long        4   8   -   -     <- C 'long' vs D 'long' DIFFER
size_t      2   2   2   2     <- agree (== pointer)
pointer     2   2   2   2
c_int       2   -   4   2     <- Zig c_int=4 != C int=2 (footgun); Rust c_int=2 OK
i32 fixed   4   4   4   4     <- agree
```

- **C `int` is 16-bit** (the LLVM-MOS C ABI, `c_int_width=16`). D mandates
  `int`=32 / `long`=64; Rust/Zig `i32`=32. So the **keyword `int` is not
  ABI-compatible** between C and the others.
- **Zig `c_int` is 16-bit** on the current `mos-freestanding` build — it now
  tracks clang's 16-bit `int`, so Zig↔C `c_int` is safe. It was **32-bit on older
  0.17-dev builds** (the target lacked MOS C-ABI data); dev-build ABI can drift, so
  pin a build. (Rust's `core::ffi::c_int` is 16-bit too.)
- **D `size_t` is 2 bytes** (= pointer). The historical `i32`-wide `size_t`
  (dlang-mos-hello-world#1, ldc#4466) is **fixed in LDC 1.42**.

The `int` IR types confirm it (exp 01): clang `define i16 @add`, but D/Zig/Rust
`define i32 @add`.

## Alignment (exp 07, compile-time)

Each frontend's own `static_assert`/`comptime`/`const _:()=assert!` compiles
only if its facts hold — so the build *is* the test. The contrast:

- C/C++/D/Rust: `_Alignof(i32) == 1` ✔ (matches datalayout `i32:8`).
- Zig: `@alignOf(i32) == 4` ✔ (natural alignment) — **diverges**.

Both files compile (each asserts its own truth); that's the proof they disagree.

## Struct layout (exp 08, runtime round-trip)

A C-built `struct {u8 tag; u32 val; u8 flag;}` (= 6 bytes, `val` at offset 1)
read back through each language's matching struct:

```
C/C++/Rust/D/Zig(align1)  size 6   0xDEADBEEF   PASS
Zig(packed struct)        size 8   0xDEADBEEF   val OK, size!=6 (u48 backing rounds up)
Zig(plain extern struct)  size 12  0x….22DE     DIVERGES  <- reads garbage
```

Zig's `extern struct` places `u32` at its natural offset 4 (sizeof 12), so it
**misreads a C struct**. Two fixes:

- `val: u32 align(1)` per field → exact C layout (6 bytes). **Recommended.**
- `packed struct {…}` → byte-packed bits read correctly, but `@sizeOf` rounds the
  `u48` backing integer up to 8 — value-compatible, not size-compatible.

`#[repr(C)]` (Rust), D `struct`, and clang structs all match C automatically.

## Zero-page address space (exp 08)

Datalayout `p1:8:8` → address space 1 is the 8-bit zero page. Supported:

- Zig: `*addrspace(.zp) u8` has `@sizeOf == 1`; `@addrSpaceCast` narrows a normal
  16-bit pointer into it (emits `addrspacecast` in IR); `@ptrFromInt` builds one.
- clang: `__attribute__((address_space(1))) char*` lowers to `ptr addrspace(1)`.
- Rust/D: no surface syntax for it.

## Rules

1. Boundary types: `uint8_t/uint16_t/uint32_t` ↔ `u8/u16/u32` ↔ `ubyte/ushort/uint`.
   Never `int`/`long`. In Rust prefer `core::ffi::*` for C-keyword parity.
2. Structs: byte-packed everywhere; in Zig add `align(1)` to every non-byte field
   of an `extern struct`, or pass the struct **by pointer to a C-defined layout**.
