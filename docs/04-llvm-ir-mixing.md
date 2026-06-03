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

## `zig cc` as the Rust linker hits exactly this wall (exp 17)

A natural idea — use `zig cc -fno-sanitize=all -lunwind` as Rust's linker (it
works on hosted targets) — does **not** work for Rust-on-MOS, and the failure is
precisely the cluster boundary:

- `zig cc -target mos-freestanding -c` **compiles** MOS objects fine (clang 22),
  and zig's **LLVM-22 `ld.lld` links LLVM-23 *native ELF*** (the rust `.a` + a
  native `crt0.o`) — getting as far as `undefined symbol: main`. Native ELF is
  version-independent, so cross-cluster *object* linking is fine.
- But the SDK's `libc.a` is **LLVM-23 bitcode**, so zig's LLVM-22 lld rejects it:
  `ld.lld: error: libc.a(cxa-abi.cc.obj): Not an int attribute (Producer:
  'LLVM23.0.0git' Reader: 'LLVM 22.0.0git')`.
- zig also has **no MOS libc of its own**: `-lunwind` → `unable to provide libc
  for target 'mos-freestanding-none'`, and a plain link tries to synthesize
  libc/ubsan for MOS and fails (a Zig std `float.zig` 16-bit-`usize` bug);
  `-fno-sanitize=all` is necessary to silence ubsan but not sufficient.
- The SDK driver (`mos-sim-clang`, LLVM 23) links the *same* rust `.a` + `main`
  into a runnable image (`rs_sub16(50,8)=42`).

Verdict: link Rust-on-MOS with the **SDK's `mos-*-clang`** (LLVM 23, matches
rust-mos and ships the platform runtime). `zig cc` can only be a linker here if
the whole SDK is rebuilt as LLVM-22 native (the zig-mos-examples route).

## Cycles footnote

In this pipeline the non-LTO and LTO builds tie at 9061 cycles — the step
functions are tiny and `printf` dominates; the point is that the merge *runs*,
not that LTO wins here. For codegen/perf differences see docs/06.
