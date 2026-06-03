# 04 — Mixing LLVM IR & the two LLVM clusters (exp 04)

Beyond linking objects, can the *LLVM IR* from different frontends be merged?
Two LLVM versions are in play:

| cluster | toolchains | LLVM |
|---|---|---|
| **23** | SDK clang/clang++, rust-mos, `ld.lld` | 23.0.0git |
| **22** | Zig 0.17-mos, LDC 1.42 | 22.0.0 |

## The merge engine is the linker

The SDK ships **no `llvm-link`/`opt`/`llc`** — only `ld.lld` + binutils tools.
That's fine: whole-program LTO *is* the llvm-mos merge path (it's how zero-page
allocation and dead-stripping happen). So "mixing IR" = feeding bitcode/`.ll` to
the linker.

## Cross-version textual IR works (23 reads 22)

A 4-language pipeline `zig_step(d_step(rs_step(c_step(x))))`, one transform per
language, each emitted as textual `.ll`:

- All four `.ll` carry the **same datalayout** (`unique = 1`).
- `mos-sim-clang -x ir` (LLVM 23) **parses the LLVM-22 D and Zig IR** — only a
  `-Woverride-module` triple warning — and emits objects.
- Both a separate-objects link (`-fno-lto`) and a cross-language **`-flto`** link
  produce a binary that runs: `pipeline(7) = 255`, exit 0.

Textual IR is version-tolerant: LLVM auto-upgrades older `.ll` on parse. So the
newer (23) toolchain consumes the older (22) frontends' IR.

## The wall

The reverse direction is the cluster boundary: Zig's bundled **LLVM-22 `ld.lld`
cannot read LLVM-23 bitcode** (e.g. the SDK's own LTO `.a` → `undefined symbol:
__rc2`). Practical rule: **link with the newest toolchain in the mix** (the SDK /
`mos-sim-clang`, LLVM 23) so it can ingest every cluster's bitcode, and rely on
ELF objects (version-independent) when crossing clusters without LTO.

## Cycles footnote

In this pipeline the non-LTO and LTO builds tie at 9061 cycles — the step
functions are tiny and `printf` dominates; the point is that the merge *runs*,
not that LTO wins here. For codegen/perf differences see docs/06.
