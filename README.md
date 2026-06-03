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

> **Yes for scalars, pointers and callbacks — five co-linkable language objects
> (C, C++, Rust, D, and Zig) share one C ABI and run correctly in a single
> 6502 binary (`experiments/02`).** The holes are at the *type* level, not the
> call level: the keyword `int` is 16-bit in C but 32-bit in D/Rust/Zig; Zig's
> `c_int` is 32-bit (≠ C's 16-bit); and **Zig's `extern struct` over-aligns**
> (`u32`→4-byte) so by-pointer structs corrupt across the boundary unless fields
> are `align(1)`. C, clang-C++, Rust and D agree on the byte-packed MOS struct
> layout; Zig is the outlier. **Fix: cross the boundary with fixed-width
> scalars, or byte-aligned structs.**

See **[Research.md](Research.md)** for the write-up and **[docs/](docs/)** for the
evidence. Toolchain quirks worth knowing up front are in **[CLAUDE.md](CLAUDE.md)**.

## The four toolchains

| Lang | Toolchain | Version | LLVM | Triple / CPU |
|------|-----------|---------|------|--------------|
| C / C++ | [llvm-mos-sdk](https://github.com/llvm-mos/llvm-mos-sdk) `v23.0.1` | clang **23.0.0git** | **23** | `--target=mos -mcpu=mos6502` |
| Rust | [mrk-its/rust-mos](https://github.com/mrk-its/rust-mos) (via [zig-mos-bootstrap](https://github.com/kassane/zig-mos-bootstrap)) | rustc **1.98.0-dev** | **23** | `--target mos-unknown-none -Ctarget-cpu=mos6502` |
| Zig | [kassane/zig-mos-bootstrap](https://github.com/kassane/zig-mos-bootstrap) `0.17.0-dev` | **0.17.0-mos-dev** | **22** | `-target mos-freestanding -mcpu mos6502` |
| D | [kassane/zig-mos-bootstrap](https://github.com/kassane/zig-mos-bootstrap) (LDC) | LDC **1.42.0** (DMD 2.112.1) | **22** | `--mtriple=mos -mcpu=mos6502 -mattr=…` |

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
scripts/run-all.sh        # build+run all 8 experiments on mos-sim (expect 0 failing)
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

> This repo studies *unofficial* 6502 support. None of these targets are upstream
> in clang/rustc/zig/ldc; pin one toolchain set (the versions above) — there is no
> cross-version ABI-stability promise on LLVM-MOS.
