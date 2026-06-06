# mos-research-ai

Research & test bed for **cross-language FFI on the MOS 6502** (and the wider
65xx family), riding the shared **LLVM-MOS** backend. Four LLVM frontends in
scope — clang (C/C++), rustc, zig, ldc2 (D) — all *unofficial / non-upstream*
ports that reach the 6502 through some build of `llvm-mos/llvm-mos`.

The central question:

> Four LLVM-frontend toolchains target the 6502 through forks of LLVM-MOS. Does
> that shared backend actually give a shared ABI — can the languages call each
> other on a real (simulated) 6502, and can their LLVM IRs and binaries be mixed?

Short answer, established empirically here (every claim is a re-runnable
experiment that executes on the `mos-sim` 6502 simulator):

> **Yes for scalars (every width), pointers and callbacks — five co-linkable
> language objects (C, C++, Rust, D, Zig) share one C ABI and run correctly in a
> single 6502 binary (`experiments/02, 13`).** The holes are narrow and specific:
> (1) *types* — the keyword `int` is 16-bit in C but 32-bit in D/Rust/Zig (Zig's
> `c_int` used to be 32-bit too, now fixed to 16-bit = C's); (2) *struct layout* — Zig's
> `extern struct` over-aligns (`u32`→4-byte) so structs corrupt unless fields are
> `align(1)`; (3) *one call-ABI corner, now closed* — **by-value structs ≤4 bytes**
> are decomposed into registers (the MOS C ABI) by **all five** frontends; D and Rust
> were the indirect holdouts and **both were fixed in their callconv rebuilds**
> (`experiments/12`). **Fix: cross the boundary with fixed-width scalars; passing
> aggregates by pointer stays the version-proof choice (no ABI-stability promise).**

See **[Research.md](Research.md)** for the write-up and **[docs/](docs/)** for the
evidence. Toolchain quirks worth knowing up front are in **[CLAUDE.md](CLAUDE.md)**.

## The four toolchains

| Lang | Toolchain | Version | LLVM | Triple / CPU |
|------|-----------|---------|------|--------------|
| C / C++ | LLVM-MOS SDK | clang **23.0.0git** | **23** | `--target=mos -mcpu=mos6502` |
| Rust | Rust-MOS | rustc **1.98.0-dev** | **23** | `--target mos-unknown-none -Ctarget-cpu=mos6502` |
| Zig | Zig-MOS | **0.17.0-mos-dev** | **22** | `-target mos-freestanding -mcpu mos6502` |
| D | LDC2-MOS | LDC **1.42.0** (DMD 2.112.1) | **22** | `--mtriple=mos -mcpu=mos6502 -mattr=…` |

All four emit the **byte-identical** LLVM data layout, which is the whole basis
for interop:

```
e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8
```

(little-endian; 16-bit pointers; **address space 1 = 8-bit zero-page pointers**;
every scalar byte-aligned; 8-bit native int.) Two LLVM *versions* are in play —
SDK+Rust on 23, Zig+D on 22 — so they form two **clusters** for bitcode/LTO
purposes (docs/04), but ELF objects link freely across both.

## Quickstart

```bash
scripts/setup.sh          # download the 4 toolchains into /home/user/tools (~360 MB)
source scripts/env.sh     # export $ZIG $LDC $RUSTC $SDKBIN $MOS_MATTR …
scripts/run-all.sh        # build+run all 26 experiments on mos-sim (expect 0 failing)
```

Each `experiments/NN-*/run.sh` is self-contained and ends by executing its
binary on `mos-sim` (exit code = its own pass/fail). The toolchains live
**outside** the repo and are never committed (`.gitignore`).

## Experiments

| # | Dir | What it proves |
|---|-----|----------------|
| 01 | `ir-datalayout` | All 4 frontends emit one identical datalayout; `int`→`i16`(C) vs `i32`(D/Rust/Zig) |
| 02 | `ffi-matrix` | C+C+++Rust+D+Zig in **one** 6502 binary, run on sim, incl. D→Rust & Zig→C cross-calls |
| 03 | `int-width` | Runtime `sizeof` table: the `int`/`long`/`c_int` divergences (and what agrees) |
| 04 | `llvm-ir-mix` | LLVM-23 `clang`/`lld` merges LLVM-22 (D, Zig) textual IR; LTO across languages |
| 05 | `codegen-cycles` | Same loop, 5 languages: identical result, different instruction count & cycles |
| 06 | `cpu-features` | `ldc -mcpu` leaves features empty (ldc#4919 class); `-mattr` is benign for base mos6502 |
| 07 | `comptime-abi` | Compile-time ABI assertions; C/D/Rust byte-align vs Zig natural-align |
| 08 | `struct-abi` | Struct round-trip: Zig `extern struct` corrupts (over-aligns); `align(1)` fixes it; zero-page AS |
| 09 | `zero-cost` | Monomorphized generic + higher-order callable: C++ ties C exactly, lambdas inline away |
| 10 | `tmp-parity` | factorial(10) via constexpr/consteval/CTFE/const-fn folds at `-O0` (lang guarantee); C doesn't |
| 11 | `dwarf-parity` | Debug info: clang=DWARF5/others=DWARF4, addr_size=4 (deliberate), no CFI (unforceable; designed upstream); `returnaddress` gap both clusters; Rust-dev G_UCMP |
| 12 | `byval-struct` | By-value struct ABI: **all five** decompose ≤4B into registers — D & Rust were the indirect holdouts, both fixed in their callconv rebuilds |
| 13 | `scalar-callback-abi` | i64 round-trip, signed negate, function-pointer callbacks: shared across all 5 |
| 14 | `feature-probe` | Capability matrix: inline-asm (all 4 — rust via `asm_experimental_arch`), interrupts, atomics(8-bit), multi-CPU, SIMD ✗ |
| 15 | `std-support` | Stdlib reach: C libc, C++ STL subset, Zig std (richest), Rust `alloc::Vec`, D core.stdc+ldc |
| 16 | `mos-sim-realworld` | Interactive stdin→stdout filter (libc `getchar` + Zig FFI uppercase) + `$FFF0` cycles |
| 17 | `zigcc-rust-linker` | `zig cc` as Rust's linker: compiles MOS objs but hits the LLVM-22/23 bitcode cluster wall |
| 18 | `embed-file` | Compile-time file embedding 6 ways (`#embed`/`include_bytes!`/`import`/`@embedFile`/`.incbin`) → identical bytes |
| 19 | `reflection` | Compile-time reflection: D & Zig enumerate fields/names; C/C++/Rust manage only `sizeof` |
| 20 | `mmio-hal` | MMIO register parity (mos-hardware/mega65-libc pattern): all 5 frontends emit identical `sta $fff9` |
| 21 | `safety` | `@safe`/borrow rejection battery (D & Rust) vs C (none); runtime bounds check: Rust traps, Zig traps w/ `mos_panic` (default handler crashes LLVM-22) |
| 22 | `raii-scopeguard` | Scope-guard/RAII LIFO cleanup in all 5 (zero-cost); Zig `errdefer`, D move-semantics & `extern(C++,class)` |
| 23 | `dynamic-debug` | Runtime PC→source on the sim: `mos-sim --profile`/`--trace` PCs symbolize back via `llvm-symbolizer` (DWARF line tables are usable) |
| 24 | `benchmarks` | Canonical kernels (BYTE sieve / recursive fib / CRC-16) in all 5: per-kernel cycles + size (codegen spread, size/speed inverts); Zig `std.hash.crc` + `std.crypto` SHA-256 + `std.math` on a 6502; 6502-vs-65C02 |
| 25 | `global-asm-symbols` | Real-world asm in all 5: the llvm-mos-sdk iNES global-asm linker-symbol trick (`asm(".globl x\nx=N")` → absolute symbol) — clang/C++ file-scope, Rust `global_asm!`, Zig `comptime asm`, D `__asm_trusted`; verified absolute via `llvm-nm` + read on mos-sim; + inline-asm MMIO putchar w/ clobbers |
| 26 | `float-runtime` | Float math at **runtime**: soft-float `+-*/` runs in all; `sqrt` lowers to a `sqrtf` libcall the SDK lacks → Zig/D/C compile but don't link; the Rust **`libm` crate** runs sqrt natively + (exported as C `sqrtf`) gives all four **parity** → `sqrt(2)·100=141` on mos-sim |
| 27 | `importc` | D's **ImportC** (pass a `.c` to `ldc2`) compiles C for MOS with a **16-bit `int`** (rebuilt LDC fixes the width — dlang-mos-hello-world#1); needs `-gcc=<mos clang>`. IR vs `mos-clang`/`zig cc`: int agrees, by-value structs lower by D rules (first-class aggregate) not C (scalars) — but C↔ImportC FFI (incl. by-value struct) still works on mos-sim |

> This repo studies *unofficial* 6502 support. None of these targets are upstream
> in clang/rustc/zig/ldc; pin one toolchain set (the versions above) — there is no
> cross-version ABI-stability promise on LLVM-MOS.
