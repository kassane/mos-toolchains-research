# 03 — The FFI matrix (exp 02)

The headline experiment: one function per language, all linked into a single
6502 binary and executed on `mos-sim`.

## Contract

`include/ffi.h` (C-ABI, fixed-width types only):

```c
uint8_t  c_add8   (uint8_t  a, uint8_t  b);  // C    (clang 23)
uint16_t cpp_mul16(uint16_t a, uint16_t b);  // C++  (clang++ 23)
uint16_t rs_sub16 (uint16_t a, uint16_t b);  // Rust (rust-mos 23)
uint16_t d_xor16  (uint16_t a, uint16_t b);  // D    (LDC 23)  -> calls rs_sub16
uint16_t zig_shl16(uint16_t a, uint8_t  n);  // Zig  (0.17 22) -> calls c_add8
```

The C++ side is `extern "C"`; the header is wrapped in `extern "C"` for C++. D
uses `extern(C) ushort`, Rust `#[no_mangle] extern "C" … u16`, Zig
`export fn … u16`. `d_xor16` and `zig_shl16` make **transitive cross-language
calls** (D→Rust, Zig→C) so the mesh isn't just "C calls everything".

## Build & link

Each language → object, then one `mos-sim-clang` link:

```
driver.o lib_c.o lib_cpp.o   -> LLVM-23 LTO bitcode (SDK platform defaults to LTO)
lib_zig.o                    -> LLVM-22 native ELF
lib_d.o  libffi_rs.a         -> LLVM-23 native objects
```

So the single link **mixes LLVM-22 native ELF (Zig) with LLVM-23 bitcode + ELF** — and it
works, because the SDK's LLVM-23 `ld.lld` LTO-compiles the bitcode and links the
ELF objects alongside (ELF `e_machine 0x1966` = 6502).

## Result

```
c_add8    =    70  expect    70  [PASS]
cpp_mul16 =   768  expect   768  [PASS]
rs_sub16  =   999  expect   999  [PASS]
d_xor16   = 65535  expect 65535  [PASS]
zig_shl16 =   512  expect   512  [PASS]
== 0 failure(s) ==
undefined count: 0
mos-sim exit code = 0
```

**Conclusion:** the LLVM-MOS C calling convention is genuinely shared. Five
languages, two LLVM versions, one running 6502 binary, zero undefined symbols.
The only discipline required is fixed-width types at the boundary (docs/05).
