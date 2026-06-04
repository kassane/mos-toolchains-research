# 06 — Codegen comparison & cpu-features (exp 05, 06, 24)

## Same source, same backend, different code (exp 05)

One LCG loop `s = s*31 + i` over `n` iterations, implemented identically in five
languages, compiled to native objects and timed via the sim's `$FFF0` cycle
counter:

| | C | C++ | Rust | D | Zig |
|--|--:|--:|--:|--:|--:|
| result | 14836 | 14836 | 14836 | 14836 | 14836 |
| instructions | 105 | 105 | 87 | 54 | 47 |
| cycles | 191272 | 191272 | 147225 | 119446 | 111055 |

All five compute the **identical** value, so the semantics are shared. But the
**code is not**: C/C++ (same clang frontend) are byte-identical to each other and
heaviest here; D and Zig are leanest. A shared backend guarantees *interop*, not
*parity* — the frontend's IR shape and default opt level (`-Os`/`-Oz`/
`ReleaseSmall`/`opt-level=s`) drive the difference. Per-function 6502 disassembly
is saved in `experiments/05-codegen-cycles/build/disasm-*.txt`.

(Numbers are an apples-to-oranges snapshot across each toolchain's default
"small" optimization mode, not a tuned benchmark.)

## ldc2 cpu-features: the ldc#4919 question on MOS (exp 06)

`ldc2 -mcpu=mos6502 -vv` reports an **empty** feature string:

```
ldc :  features ''
ldc+:  features '+mos6502,+mos-insns-6502,+mos-insns-6502bcd,+static-stack'   (with -mattr)
```

clang and rustc don't spell features in IR either — they pass `target-cpu=mos6502`
and let the backend imply them; only Zig writes them out explicitly. So does the
empty string matter? **No, for the base CPU:** D's generated 6502 asm is
**byte-identical** with and without `-mattr`, because the LLVM-MOS backend
derives the CPU's implied features from `-mcpu` regardless. Toggling
`-static-stack` off or `+mos-long-register-names` on also doesn't change this
function's code.

This is the MOS instance of **ldc#4919** ("Missing default LLVM cpu-features in
some targets" — which is itself about wasm32, not MOS; docs/07). Conclusion: the
empty `-vv` display is cosmetic for base mos6502, but we still pass
`-mattr=$MOS_MATTR` in every LDC build for parity with the other frontends and
in case a non-base CPU (e.g. `mosw65816`) ever needs an explicit, non-implied
feature.

## Cross-language benchmark suite (exp 24)

Three canonical integer kernels from the 6502 benchmark canon — BYTE/Gilbreath
**sieve** (8190 flags → 1899 primes), recursive **fib(24)** (= 46368, 150049
calls), and **CRC-16/XMODEM** (→ 0x7E55) — written identically (same algorithm,
`u16` throughout) in all five languages. Per-kernel **size** (`llvm-nm`
per-function bytes) and **cycles** (mos-sim `$FFF0`, bracketing only the call):

| bytes | C | C++ | Rust | D | Zig | | cycles | C | C++ | Rust | D | Zig |
|--|--:|--:|--:|--:|--:|--|--|--:|--:|--:|--:|--:|
| sieve | 264 | 264 | 267 | 238 | **229** | | sieve | **2.15M** | 2.15M | 2.36M | 2.44M | 2.47M |
| fib | 146 | 146 | 146 | 117 | **113** | | fib | **13.69M** | 13.69M | 13.72M | 14.03M | 14.10M |
| crc16 | 111 | 111 | 136 | 218 | **96** | | crc16 | 78K | 76K | 100K | **61K** | 109K |

Same backend, same result — but the spread is real and the **size/speed ranking
inverts**: Zig emits the smallest code on every kernel yet is slowest on
sieve/fib; D's crc16 is the *largest* (218 B) but *fastest* (61 K, ~1.8× Zig). C
and C++ are byte-identical (same clang). The **frontend's IR shape** (loop idiom,
index arithmetic) drives this, not the backend — the same "trade size for speed"
llvm-mos is known for, here visible *across frontends*.

**Per-function size, not whole-image — on purpose.** The community suite
**C-Bench-64** (cc65/llvm-mos/Oscar64/vbcc/SDCC/Calypsi on a real C64) reports
whole-`.prg` bytes, where llvm-mos sits at a ~6.3 KB floor regardless of kernel
— that's its fixed runtime, not codegen. The kernel *function* bytes are the
honest metric. For context, C-Bench-64's runtimes put llvm-mos ahead of cc65 on
every kernel and 2nd to Oscar64 (sieve 18.8 s vs cc65 20.5 / Oscar64 8.7; crc32
3.6 s vs **cc65 40 s**). This repo's angle is orthogonal: five *languages* on
**one** backend, not six *compilers*.

**6502 vs 65C02** (C kernels, rarely measured): `-mcpu=mos65c02` + `--cmos` is
smaller and ~5 % faster on sieve/fib (STZ/BRA/PHX help loop/call code) but
*larger and ~22 % slower* on crc16 — not a uniform win.

Built `-fno-lto` so each kernel stays a discrete, measurable function (LTO is
llvm-mos's whole-program default and would inline them away); `-Os` on llvm-mos
means "speed without trading size" (its balanced default). Widths are normalised
to `u16` so we compare codegen, not 16- vs 32-bit math (C `int` is already
16-bit; the others' `int`/`i32` are 32-bit, docs/05).

**Stdlib dimension** (only Zig can, on bare-metal MOS): the same CRC plus a real
**SHA-256** and an integer **sqrt** pulled straight from `std.hash.crc` /
`std.crypto` / `std.math`. Table-based `std.hash.crc` runs crc16 in **29.5 K
cycles vs the hand-rolled 109 K** (3.7×), and `std.crypto` computes a byte-exact
SHA-256 on the 6502 — see docs/13.
