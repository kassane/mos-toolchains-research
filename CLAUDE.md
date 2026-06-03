# CLAUDE.md — orientation for automated sessions

This repo is a **research & test bed**, not a shipping product. Goal: study
cross-language FFI (C / C++ / Rust / D / Zig) on the **MOS 6502** over the shared
**LLVM-MOS** backend — compare features / LLVM IR / binaries, run them on the
`mos-sim` simulator, and document what's real. Read `Research.md` first, then
`docs/`. Findings must be backed by **actual tool output**, never asserted.

## Environment facts

- Host: x86_64 Linux, 4 CPUs, ~15 GB RAM, ~31 GB free. Outbound network OK.
- **GitHub API is rate-limited** on this shared IP (unauthenticated 60/hr). To
  discover release assets use the download CDN / `releases/expanded_assets/<tag>`
  or `WebFetch`, **not** `api.github.com`.

## Toolchains (live OUTSIDE the repo)

`scripts/setup.sh` downloads into `$TOOLS` (default `/home/user/tools`); **never
commit them** (`.gitignore` guards `tools/`, `build/`, `target/`, `*.tar.xz`).
`source scripts/env.sh` exports:

| var | points at |
|-----|-----------|
| `$ZIG` | Zig **0.17.0-mos-dev** (bundled clang/LLVM **22**); also `zig cc`/`zig c++` |
| `$LDC` | **LDC 1.42.0** (DMD 2.112.1, LLVM **22**). D; `-betterC` only on MOS |
| `$SDKBIN` | llvm-mos-sdk **v23.0.1** bin (clang **23**, `mos-*-clang` drivers, `ld.lld`, `mos-sim`) |
| `$MOSCLANG`/`$MOSCXX` | raw `--target=mos` clang/clang++ (LLVM 23) |
| `$RUSTC`/`$CARGO` | rust-mos **1.87.0-dev** (LLVM **23**), target `mos-unknown-none` |
| `$MOS_MATTR` | `+mos6502,+mos-insns-6502,+mos-insns-6502bcd,+static-stack` — pass to LDC's `-mattr` |

## Build / run

```bash
source scripts/env.sh
scripts/run-all.sh                 # all experiments; exit 0 iff all pass
experiments/02-ffi-matrix/run.sh   # one experiment (builds, links, runs on mos-sim)
```

`mos-sim` takes a memory **image** (not ELF — `file` reports "data"). MMIO:
`$FFF8`=exit code, `$FFF9`=stdout char, `$FFF0`(4B)=cycle counter; flags
`--cycles`, `--trace`, `--cmos`. No `--help` (it treats args as the image path).
Disassemble objects with `llvm-objdump -d --mcpu=mos6502` (SDK ships objdump but
**not** `llvm-link`/`opt`/`llc` — the linker's LTO is the only IR-merge engine).

## Non-obvious gotchas (already solved — don't relearn the hard way)

1. **Two LLVM clusters.** SDK-clang + rust-mos are LLVM **23**; Zig + LDC are
   LLVM **22**. ELF objects interlink across both (stable e_machine `0x1966` =
   6502). For *bitcode/LTO*, the LLVM-23 toolchain reads LLVM-22 textual IR
   (upgrades on parse, docs/04); the reverse (Zig's LLVM-22 lld on SDK LLVM-23
   bitcode) fails. Link a mixed build with the **SDK/`mos-sim-clang`** driver.
2. **rust-mos needs `lto = true`** in the cargo profile (and `panic = "abort"`,
   `-Z build-std=core,compiler_builtins`, `RUSTC_BOOTSTRAP=1`). Without LTO, the
   native codegen of `core::panic::Location::cmp` hits a MOS GlobalISel gap
   (`unable to legalize G_UCMP s8 from s32`). LTO defers codegen and dodges it.
3. **`ldc2 -mcpu=mos6502` reports `features ''`** (the ldc#4919 class bug). It's
   *benign* for base mos6502 — the backend derives features from the CPU anyway
   (docs/06, byte-identical asm). Still pass `-mattr=$MOS_MATTR` for parity.
4. **`int` is not portable across languages on MOS.** C `int` = 16-bit; D/Rust/Zig
   `int`/`i32` = 32-bit; Zig `c_int` = 32-bit (≠ C). Cross FFI with `uint16_t`/`u16`
   /`ushort` etc. (docs/05). Rust's `core::ffi::c_int` *does* match C (16-bit).
5. **Zig over-aligns structs.** `@alignOf(u32)` is 4 in Zig but 1 in the MOS
   datalayout, so a Zig `extern struct {u8,u32,…}` puts the u32 at offset 4
   (sizeof 12) while C/D/Rust use offset 1 (sizeof 6). Reading a C struct through
   it returns garbage. Fix: `val: u32 align(1)` per field (exact match) — `packed
   struct` reads right but `@sizeOf` rounds the backing int up (docs/05, exp 08).
6. **D is `-betterC` only** on MOS — no druntime/Phobos, so no GC, classes,
   exceptions, TypeInfo, dynamic/associative arrays. `extern(C)` for FFI; LDC
   predefines `version(MOS6502)`. D `size_t` is fixed to 2 bytes in LDC 1.42
   (the old dlang-mos-hello-world#1 `i32` bug is gone, docs/07).
7. **By-value structs ≤4 bytes are NOT FFI-safe between {C,C++,Zig} and {Rust,D}.**
   clang/Zig decompose them into registers (the MOS C ABI); Rust/D pass them
   indirectly (`byval`/`ptr`), so a small struct passed by value corrupts across
   that boundary. Pass aggregates **by pointer** (all agree; >4-byte sret also
   agrees). docs/11, exp 12. Reverse-engineered from the IR parameter lowering.
8. **Debug builds need care:** Zig `-ODebug` fails on overflow-checked ops
   (`@llvm.returnaddress` not legalizable) — use wrapping ops or a release mode;
   Rust dev profile fails the G_UCMP gap — use `lto=true`+`debug=2`. Inline asm
   works in clang/Zig/LDC but **not Rust** (rust-mos#13). docs/10, docs/12.
9. **Stdlib reach is uneven (docs/13).** Float math: Zig `std.math` and D
   `core.math` compute `sqrt` (soft-float); C `<math.h>` has **no** sqrt/sin/pow
   and `no_std` Rust's `f32::sqrt` is std-only. D `core.stdc.stdio`/`stdlib` are
   **not ported** ("unsupported system" / undefined `c_long`) — hand-declare
   `extern(C) printf`. Rust gets `alloc::Vec` via a `#[global_allocator]` over
   SDK `malloc`. C++ STL is a tiny subset (no `std::sort`).
10. **All LDC calls pass `$LDC_PE`** (`-preview=all --edition=2025`). `-preview=all`
   includes `-preview=safer`, which rejects accessing a module-level `@system`
   var from a default-safe `extern(C)` fn — use a *local* `enum` for CTFE
   constants, or annotate `@system`. (2026 edition is rejected by LDC 1.42.)

## Repo map

```
experiments/01..17   each: sources + run.sh (ends by running on mos-sim); build/ gitignored
scripts/             setup.sh (download toolchains) env.sh run-all.sh
docs/00..13          support matrix / toolchains / ABI / ffi / ir-mixing(+zig-cc-linker) /
                     types+struct / codegen / issues / zero-cost / tmp-parity / dwarf /
                     byval+scalar / features / stdlib+math
Research.md HANDOFF.md  headline write-up / status
```

## House style

- Back every finding with real `mos-sim` / `llvm-objdump` / IR output; keep big
  artifacts in `build/` (gitignored), quote curated excerpts in `docs/`.
- Keep `.md` files human-concise; don't repeat the same table in three places.
