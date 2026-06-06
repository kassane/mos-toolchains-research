# 07 — Upstream issues & references

The issue trail behind this repo's findings (researched from the GitHub HTML, not
the rate-limited API). Where an issue maps to one of our experiments, it's noted.

## llvm-mos / llvm-mos-sdk (the backend)

- C calling convention & imaginary registers — the shared ABI we rely on (docs/02).
  Backend uses **GlobalISel**; not upstreamed to LLVM (~22k-line diff; LLVM core
  rejects 8-bit targets).
- `#10` Floating-point support — soft-float, incomplete → we keep floats out of the
  FFI matrix.
- `#66` interrupt attributes (`interrupt`, `interrupt_norecurse`, `no_isr`); `#459`
  CBM interrupt codegen still rough.
- `#249` optimizer can't see through function pointers; `#222` PIC limited.
- `#229`/`#68`/`#122`/`#127` calling-convention evolution → **no ABI-stability
  promise**; pin a toolchain (our headline caveat).
- SDK v23.0.1 = LLVM 23 line; ships `mos-sim` and 42 platform drivers (docs/01).

## rust-mos (mrk-its/rust-mos)

- Target `mos-unknown-none`: `c_int_width=16`, `panic=Abort`, `requires_lto=true`,
  8-bit atomics, `cpu=mos6502` hard-coded. **Not upstream** in rustc.
- `#35` `c_uint`/`c_int` width regressed 16→32 on a build — the FFI hazard our
  exp 03 measures (here Rust `c_int` is correctly **16-bit**).
- `#13` **FIXED** (rebuilt toolchain): inline `asm!`, `global_asm!` and `naked_asm!`
  work behind `#![feature(asm_experimental_arch)]`, with register operands and clobbers
  (incl. imaginary zero-page regs like `rc2`) — verified `clc; adc #3` → 8 on mos-sim
  (exp 14). (The issue also covered an early fixed-ROM `JSR` miscompile.) The same
  rebuild fixed the **by-value-struct callconv** — Rust now register-decomposes ≤4-byte
  structs (exp 12, docs/11). The newest rebuild also accepts **`clobber_abi("C")`**,
  which expands to the MOS C caller-saved set `={x},={y},={rc2}..={rc19},~{cc}` (exp 14).
- `#26` `build-std` vs `compiler-builtins` undefined `precondition_check` at link.
- `#21` the fork carries a patched `compiler-builtins` + `cargo` — the maintenance
  burden that keeps it downstream.
- Our own observation (exp 07/01): native `core` codegen hits
  `unable to legalize G_UCMP` in `core::panic::Location::cmp`; `lto = true` is the workaround.

## ldc2 / LDC (D)

- **`ldc-developers/ldc#4919`** "Missing default LLVM cpu-features in some targets"
  — **about wasm32, not MOS** (the task premise was slightly off). It documents the
  same `-mcpu`/`-mattr`/`-vv` mechanism we exercise; on MOS the empty feature
  string is benign (docs/06).
- `#4466` (draft) make `size_t`/`ptrdiff_t` match pointer size on 8/16-bit targets —
  the fix for the old wide-`size_t` problem; effectively present in LDC 1.42 (our D
  `size_t` is 2 bytes, exp 03).
- `#2520` 16-bit bounds-check `ICmp` type-mismatch (MSP430) — same 16-bit-target
  family. `#2194` (merged) original MSP430 / 16-bit support that 8/16-bit targets
  build on.
- **By-value-struct callconv FIXED in the rebuilt LDC** (`40c2f8c8…`): ≤4-byte
  aggregates now lower as a first-class aggregate (`@d_small(%Small)`, **no `byval`**)
  and the backend decomposes them to registers — matching the MOS C ABI. This closes
  the last FFI call-ABI hole (D was the final indirect holdout after Rust; exp 12,
  docs/11). Re-verified gaps that **persist** on this build: empty `-mcpu` feature
  string (#4919 class), `core.stdc.stdio`/`stdlib` unported (`"unsupported system"`),
  `import std.math` (`undefined c_long`), `scope(failure)` rejected under `-betterC`,
  DMD-style `asm{}` needs `@trusted` under `-preview=safer`, and `--edition=2026` is
  rejected. `size_t` stays 2 bytes (#4466).
- D on MOS is **`-betterC` only**; no druntime/Phobos.

## kassane/dlang-mos-hello-world

- **`#1` "Struct size mismatch for mos6502"** — LDC emitted struct length/`size_t`
  as `i32` while Zig used `i16`. Marked `wontfix` then; **resolved by LDC 1.42** (exp 03
  shows D `size_t` == 2 == pointer; root cause was the historical `size_t ≥ 32-bit`
  frontend rule, ldc#4466). The **rebuilt LDC (`d5610c25…`) also fixes ImportC's `int`
  width on MOS**: `import`ed C now sees a **16-bit `int`** (`sizeof(int)==2`,
  `struct{int}==2`), matching the real MOS C ABI — closing #1 at the ImportC layer too
  (exp 27, verified on mos-sim). ImportC must be pointed at a MOS C compiler
  (`-gcc=$SDKBIN/mos-sim-clang`, `-P-I…` for headers); the default host `/usr/bin/clang`
  rejects `-mtriple=mos`. The same repo demonstrates the D→C build pattern we mirror:
  `-betterC`, `-mtriple=mos`, link via `-gcc=mos-*-clang -linker=lld`, FFI through ImportC.

## zig-mos (kassane/zig-mos-bootstrap)

- **`c_int` width drifts across dev builds:** older `0.17.0-dev` builds gave a
  **32-bit** `c_int` (the `mos-freestanding` target lacked MOS C-ABI data — the
  Zig↔C footgun exp 03/07 measured); the **current build fixed it to 16-bit** (= C).
  A live reminder that a rolling dev tag's ABI can move — pin a build.
- **`@typeInfo` Struct API drift:** the comptime field list is now parallel
  `field_names`/`field_types` arrays (`Type` moved to `std.lang`), not the older
  `.fields` list (exp 19).
- **asm clobber vocabulary grew:** the `.mos` clobber struct in `std/lang/assembly.zig`
  now ships the *entire* register file — `a`/`x`/`y`/`s`, flags `c`/`n`/`v`/`z`/`p`, and
  the imaginary `rc0`..`rc255` / `rs0`..`rs127`. Earlier builds exposed **no**
  imaginary-register token at all; the new ones make `rc`/`rs` clobbers effective (s/n/z
  remain machine-inert). Another rolling-tag capability bump (exp 14, docs/12).
- **`@llvm.returnaddress` is unlowerable** → Zig `-ODebug` fails on safety-checked
  ops (use wrapping ops / a release mode; exp 11, docs/10). **ReleaseSafe's default
  panic handler crashes** the LLVM-22 backend (upstream llvm#167336) → use the
  `mos_panic` handler; the full `MachineCopyPropagation` mechanism is in docs/12
  (exp 21). Both **persist** on the current build (LLVM 22).
- **`extern struct` over-aligns** (`@alignOf(u32)`=4 ≠ the MOS datalayout's 1) so a
  Zig struct misreads a C struct unless fields are `align(1)` (exp 08, docs/05).

## References

- llvm-mos backend & SDK: https://github.com/llvm-mos/llvm-mos ·
  https://github.com/llvm-mos/llvm-mos-sdk (v23.0.1)
- rust-mos: https://github.com/mrk-its/rust-mos
- LDC issue 4919: https://github.com/ldc-developers/ldc/issues/4919
- dlang-mos-hello-world #1: https://github.com/kassane/dlang-mos-hello-world/issues/1
- zig-mos: https://github.com/kassane/zig-mos-bootstrap ·
  https://github.com/kassane/zig-mos-examples ·
  https://kassane.github.io/blog/zig_mos_6502/
- Toolchain tarballs are pinned (SHA256) in `scripts/setup.sh`; the download verifies
  each against its pin and aborts on mismatch. Current pins (verified 2026-06):
  - zig  `8f45d896…` (rolling `0.17.0-dev`)
  - ldc2 `d5610c25…` (`0.1.0`)
  - rust `26f8e362…` (`0.1.0`)

  These forks move fast — **all three were rebuilt again** this round. **rust-mos**
  moved `3c7c1407…` → `26f8e362…`, but the rustc *version* is unchanged (`1.98.0-dev`;
  the binary reports no commit hash), so the fixes ride in the bundled target specs/std:
  `c_int`=16, the G_UCMP `lto` workaround, and the `asm!`/callconv #13 fix all still
  hold, and the newest adds `clobber_abi("C")`. **LDC** was rebuilt again
  (`40c2f8c8…` → `d5610c25…`) — it fixes ImportC's MOS `int` width (now 16-bit;
  resolves dlang-mos-hello-world#1 at the ImportC layer, exp 27) and keeps the
  by-value-struct callconv fix. **Zig's rolling `0.17.0-dev`** keeps drifting too: this build
  ships the full asm-clobber register file (was: none) on top of the earlier
  `c_int`→16-bit and `@typeInfo` reshapes. Pin a build for reproducibility — when a
  rolling tag rolls, the SHA check trips and the pin must be refreshed.
- Methodology mirrors https://github.com/kassane/espressif-toolchains-research
  (the Xtensa/RISC-V sibling of this study).
