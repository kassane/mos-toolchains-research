# 12 — Feature / capability support (exp 14)

Compile-only probes: does feature X build for the 6502 in language Y? (A clean
compile = supported.)

| capability | clang | Zig | LDC (D) | Rust |
|---|:--:|:--:|:--:|:--:|
| inline assembly | ✅ | ✅ | ✅ | ❌ |
| interrupt handler | ✅ `__attribute__((interrupt))` | ✅ `callconv(.{.mos_interrupt=…})` | (via asm) | n/a |
| 8-bit atomic load/store | ✅ | — | — | — (target: atomics=8) |
| 32-bit atomic RMW/CAS | ❌ | — | — | ❌ (`atomic_cas=false`) |
| SIMD / vector types | ❌ rejected | — | — | — |
| `-mcpu=mos65c02` | ✅ | ✅ | ✅ | ✅ (rustc accepts) |
| `-mcpu=mosw65816` | ✅ | ✅ | ✅ | ✅ (rustc accepts) |

Highlights:

- **Inline asm: Rust is the lone gap** — `core::arch::asm!` is unsupported on the
  MOS target (rust-mos#13). clang, Zig (`asm volatile`) and LDC accept it (LDC needs
  the LLVM-style `ldc.llvmasm`/`@trusted` form under `-preview=safer`; the DMD-style
  `asm{}` block exp 14 probes is rejected as un-`@trusted` — a safety gate, not a
  capability gap). The idiomatic Rust workaround is fixed-address function pointers.
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
