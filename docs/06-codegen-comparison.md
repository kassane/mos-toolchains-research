# 06 — Codegen comparison & cpu-features (exp 05, 06)

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
