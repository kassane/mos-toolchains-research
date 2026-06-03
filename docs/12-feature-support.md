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
  MOS target (rust-mos#13). clang, Zig (`asm volatile`) and LDC (LLVM-style `asm`)
  all accept it. The idiomatic Rust workaround is fixed-address function pointers.
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
