# 02 — The MOS / LLVM-MOS ABI

The 6502 has three 8-bit registers (A, X, Y) and a 256-byte hardware stack — far
too little to host a normal ABI. LLVM-MOS solves this in the **backend**, so
every frontend that lowers to it inherits one calling convention.

## Data layout (exp 01, identical across all 4 frontends)

```
e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8
```

| field | meaning |
|---|---|
| `e` | little-endian |
| `m:e` | ELF name mangling |
| `p:16:8` | default pointer = **16-bit**, 8-bit (1-byte) aligned |
| `p1:8:8` | address-space-1 pointer = **8-bit** → the **zero page** |
| `i16:8 i32:8 i64:8 f32:8 f64:8` | every scalar **byte-aligned** (ABI align = 1) |
| `a:8` | aggregates byte-aligned |
| `n8` | native integer width = 8 bits |

The two consequences that bite FFI: **16-bit pointers/`size_t`** and
**1-byte alignment for everything**. C, clang-C++, Rust and D honor the latter;
Zig does not (docs/05).

## Imaginary registers (zero-page)

The backend reserves zero page as pseudo-registers, resolved to concrete ZP
addresses by the linker:

- `__rc0..__rc31` — thirty-two 8-bit registers.
- `__rs0..__rs15` — sixteen 16-bit registers, each a little-endian `__rc` pair.

These appear `U` (undefined) in object `nm` output and are assigned by the
platform linker script.

## Calling convention

- **Integer/scalar args:** byte-by-byte, first in **A**, then **X**, then
  **RC2..RC15**, left-to-right.
- **Pointers:** in 16-bit regs **RS1..RS7**.
- **Returns:** same scheme (A, X, RC2..).
- **Aggregates ≤ 4 bytes:** decomposed into scalar fields, passed in registers.
- **Aggregates > 4 bytes:** by hidden pointer (sret); caller allocates.
- **Overflow args / varargs:** on the soft stack (zero page; `RS0` = soft SP).
- **`static-stack`:** non-recursive frames are allocated statically (indexed
  addressing is slow); the dynamic soft stack is used only where reentrancy needs it.

This is why **passing by fixed-width scalar or by pointer always works** across
languages (exp 02) even when the higher-level type model disagrees.

## Alignment is the subtle part

`@alignOf`/`_Alignof`/`align_of` for `i32` on MOS:

| C (`_Alignof`) | D (`.alignof`) | Rust (`align_of`) | Zig (`@alignOf`) |
|:--:|:--:|:--:|:--:|
| 1 | 1 | 1 | **4** |

C/D/Rust follow the datalayout (1); Zig uses natural alignment (i16→2, i32→4,
i64→8). For scalars passed in registers this is invisible; for **struct layout**
it corrupts (docs/05, exp 08).

## Not covered by the shared ABI

- **Floating point** — soft-float, rough (llvm-mos#10); avoid across FFI.
- **PIC** — limited (llvm-mos#222), though the rust target reports `pic`.
- **No DWARF CFI / stack unwinding** on MOS *today* — no backtraces. But this is
  in progress, not infeasible: there's a designed dual-stack CFA and a closed-only-
  to-be-split PR ([llvm-mos#519](https://github.com/llvm-mos/llvm-mos/pull/519)).
  Verified still absent on the pinned SDK (and unforceable); details in docs/10.
- **No published ABI-stability guarantee** — pin one toolchain set.
