# 12 — Feature / capability support (exp 14)

Compile-only probes: does feature X build for the 6502 in language Y? (A clean
compile = supported.)

| capability | clang | Zig | LDC (D) | Rust |
|---|:--:|:--:|:--:|:--:|
| inline assembly | ✅ | ✅ | ✅ (`ldc.llvmasm`) | ✅ (#13 fixed) |
| interrupt handler | ✅ `__attribute__((interrupt))` | ✅ `callconv(.{.mos_interrupt=…})` | (via asm) | n/a |
| 8-bit atomic load/store | ✅ | — | — | — (target: atomics=8) |
| 32-bit atomic RMW/CAS | ❌ | — | — | ❌ (`atomic_cas=false`) |
| SIMD / vector types | ❌ rejected | — | — | — |
| `-mcpu=mos65c02` | ✅ | ✅ | ✅ | ✅ (rustc accepts) |
| `-mcpu=mosw65816` | ✅ | ✅ | ✅ | ✅ (rustc accepts) |

Highlights:

- **Inline asm: all four now do it.** `core::arch::asm!` (plus `global_asm!`/
  `naked_asm!`) works on MOS behind `#![feature(asm_experimental_arch)]` — register
  operands *and* clobbers, including the imaginary zero-page regs (e.g. `out("rc2")`)
  — since **rust-mos#13 was fixed** (rebuilt toolchain 2026-06-04; verified `clc; adc
  #3` → 8 on mos-sim, exp 14). clang and Zig (`asm volatile`) accept it directly; LDC
  needs the LLVM-style `ldc.llvmasm`/`@trusted` form under `-preview=safer` (the
  DMD-style `asm{}` block exp 14 probes is rejected as un-`@trusted` — a safety gate,
  not a capability gap).
- **asm clobbers — one backend, four validators** (all verified, exp 14). Every
  frontend lowers inline asm into the *same* LLVM-MOS register file: GPRs `a`/`x`/`y`,
  the hardware stack `s`, flags `c`/`v`/`p` (the backend also models `n`/`z`/`nz` but
  barely exposes them), and the imaginary zero-page file `rc0`..`rc255` /
  `rs0`..`rs127` (`rc0:rc1`=`rs0`=soft-stack-ptr, `rc30:rc31`=`rs15`=frame-ptr, both
  reserved). What you may *name* as a clobber is pure frontend policy, and the four
  diverge sharply — a representative accept/REJECT slice (exp 14 prints the table):

  | token | clang | Zig | Rust | LDC |
  |--|:--:|:--:|:--:|:--:|
  | `a` (GPR) | accept | accept | accept | accept |
  | `c` (flag) | accept | accept | **REJECT** | accept |
  | `rc2` (imaginary) | accept | **REJECT** | accept | accept |
  | `s` (HW stack) | **REJECT** | REJECT¹ | **REJECT** | accept |
  | `foo` (bogus) | **REJECT** | **REJECT** | **REJECT** | **accept**² |

  Each frontend has a distinct signature: **clang** = curated lowercase allow-list —
  the *widest imaginary range* (all `rc`/`rs`) plus real flags (`c`/`v`/`p`, and the
  generic `cc`), but it rejects `s`/`n`/`z`/`nz` *and* silently accepts the reserved
  `rc0/1/30/31` (clobbering the soft-stack/frame pointer is unguarded — Rust refuses
  these). **Zig** = packed-struct field names with **no imaginary-register token at
  all** (`.rc2` is a field error); ¹the maintainer's pending `assembly.zig` patch adds
  `s`/`n`/`z`, but they reach LLVM IR with **no machine effect** (byte-identical
  `.text`). **Rust** = register classes `reg_gpr` (a/x/y) + `reg` (`rc2`..`rc29` only;
  `rc≥32`, `rs1..14` unexposed) with the *safest ergonomics* — custom diagnostics
  spell out why `rc0/1`, `rc30/31`, `s` are off-limits — and flags clobbered by
  default (`options(preserves_flags)` to keep them; there is no per-flag token).
  **LDC** = `ldc.llvmasm` hands the constraint string straight to LLVM with **zero
  validation**; ²a typo'd `~{foo}` (or `~{rc999}`) compiles and is *silently ignored*
  (verified identical `.text`) — maximum freedom, zero safety. (DMD-style `asm{}` has
  no clobber slot at all.) So: clang fine-grains the *imaginary* file, Rust fine-grains
  it *safely*, Zig only fine-grains *flags* (and inertly), LDC checks nothing.
- **Interrupts** work in both clang (`interrupt` attribute → RTI epilogue) and Zig
  (`callconv(.{ .mos_interrupt = .{} })`). The correct Zig spelling is the
  *parameterized* union tag, not a bare enum (`callconv(.mos_interrupt)` is a
  type error).
- **Atomics** match the target spec: 8-bit load/store compiles; anything needing
  compare-and-swap (32-bit RMW) does not — there is no atomic CAS on the 6502.
- **No SIMD**: `__attribute__((vector_size(8)))` is rejected; MOS is scalar 8-bit.
- **CPU models**: all four frontends accept `mos65c02` and `mosw65816` (and rustc
  accepts them via `-Ctarget-cpu`, though rust-mos hard-codes `mos6502` in its
  built-in target spec — pass the CPU explicitly or use a per-machine JSON).

These are compile-time capabilities; for the *runtime* ABI behavior of the
features that do compile, see docs/02, docs/11.

## Memory safety (exp 21)

The same unsafe-op rejection battery as the espressif repo, on MOS. D `@safe`
(compiled `--mtriple=mos`) and Rust safe (target-independent rule) reject the
same dangerous ops; C accepts everything:

| op | D `@safe` | Rust | C |
|---|:--:|:--:|:--:|
| pointer index / arithmetic | ❌ | ❌ | ✅ |
| int→ptr cast + deref | ❌ | ❌ | ✅ |
| same-size ptr reinterpret | ✅ accept | (unsafe) | ✅ |
| call `@system`/`unsafe` fn | ❌ | ❌ | ✅ |
| inline asm · union pun | ❌ | ❌ | ✅ |

D `@safe` rejects **6/7** (gap = same-size reinterpret, Rust needs `unsafe` too).
Escape analysis: D `@safe -preview=dip1000` and Rust's borrow checker both reject
`return &local`. **C/C++ have no compile-time memory safety.**

**Runtime** safety (run on `mos-sim`):
- **Rust** bounds check (`a[5]`, len 3): fires → panic → `abort` → exit 77. ✅
- **C**: reads OOB (UB), no trap.
- **Zig `ReleaseSafe`**: both *overflow* (`a+b` → exit 88) **and** *array-bounds*
  (`a[5]` → exit 77) checks **work and trap** — provided you use a bare-metal
  panic handler. The handler is the catch: the **default / `FullPanic`** handler
  crashes the LLVM-22 backend on the bounds-check code (gdb: **SIGSEGV in
  `MachineCopyPropagation` / `CopyTracker::invalidateRegister`**; `-fno-compiler-rt`
  does *not* help — an upstream LLVM `MachineCopyPropagation` bug, llvm#167336,
  gone by LLVM 23). The fix is the
  namespace-style **`mos_panic`** handler from `kassane/zig-mos-examples`
  (`sdk/panic.zig`: trivial `outOfBounds`/`integerOverflow`/… → `while(true){}`,
  no formatting/`@returnAddress`). `pub const panic = @import("mos_panic")` →
  ReleaseSafe bounds *and* overflow build and trap. (`-ODebug` still fails on
  `@llvm.returnaddress`; the SDK examples also note a Debug **SSP** lowering
  failure — use a release mode.)
  - **The default-handler crash is Zig-codegen-specific, not all-LLVM-22:** LDC
    is *also* LLVM 22 but never hits it — its `-boundscheck=on` index lowers to
    `cmp`/`bcs`/`jsr __assert` and builds clean at `-O0`…`-O3`/`-Oz`.

So **all three of Rust, Zig (with `mos_panic`), and D `@safe` give real safety on
the 6502**: Rust = compile-time + runtime (bounds+overflow); Zig = runtime
(bounds+overflow, needs the `mos_panic` handler); D = compile-time `@safe`
(betterC has no runtime array-bounds handler).
