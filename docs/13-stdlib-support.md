# 13 — Standard-library reach, math & real-world I/O (exp 15, 16, 24)

docs/00–12 covered the ABI. This is about how much of each language's *standard
library* actually works on bare MOS, the float-math story, and a real
interactive program on `mos-sim`.

## Stdlib reach per frontend (exp 15, all run on mos-sim)

| lang | what works on MOS | notes |
|------|-------------------|-------|
| **C** | full freestanding **libc**: `printf`, `malloc`/`free`, `getchar`/`putchar`, `string.h`, `ctype.h`, `setjmp` | the SDK's `mos-platform/common` |
| **C++** | **minimal STL subset**: `<array>`, `<type_traits>`, `<utility>`, `<iterator>`, `<new>`, `min_element`/`max_element` | **no `std::sort`**; `std::array` needs `{{…}}` and isn't a full aggregate |
| **Zig** | **rich `std` subset**: `std.mem` (`sort`,`min`,`max`), `std.sort`, `std.fmt.bufPrint` (`{d}`/`{x}`), `std.meta.fieldNames`/`fieldTypes`, `std.math`, **`std.hash`/`std.crypto`** (exp 24) | comptime-instantiated; the most capable on MOS |
| **Rust** | `core` + **`alloc`** (`Vec`/`Box`) once you supply a `#[global_allocator]` | no `std`; here the allocator wraps the SDK `malloc`/`free` |
| **D** | `-betterC`: `core.stdc.string`, `core.bitop`, **all `ldc.*`** (`intrinsics`/`attributes`/`llvmasm`), `core.math` | **`core.stdc.stdio`/`stdlib` are NOT ported** (`static assert "unsupported system"` / undefined `c_long`); no Phobos (`std.*`), so hand-declare `extern(C) printf` |

D library-import specifics (probed): `core.stdc.string` ✓, `core.bitop` ✓,
`ldc.intrinsics`/`ldc.attributes`/`ldc.llvmasm` ✓, `std.experimental.allocator`
building-blocks compile but **`Mallocator` fails** (it needs the unported
`core.stdc.stdlib`). `import std.math` fails (`undefined c_long`).

## Math: float on a CPU with no FPU — compile vs *run*, and a parity fix (exp 26)

Float **arithmetic** (`+ - * /`) works in every frontend — the soft-float libcalls
(`__mulsf3`/`__divsf3`/`__fixsfsi`) ship in the SDK (exp 26 runs Zig `22/7·1000 = 3142`).
Float **`sqrt`** is the catch: `@sqrt` / `std.math.sqrt` / `core.math.sqrt` / C all lower
to a **`sqrtf` libcall the SDK libm doesn't provide**, so they *compile but fail to link*
(`undefined symbol: sqrtf`). The compile-only picture (Zig/D "have" sqrt) **reverses at
runtime** — and one crate fixes it for everyone:

> **The Rust `libm` crate (pure-Rust software math) is the portable soft-`sqrt`
> provider.** Rust uses it directly; exported as the C symbols `sqrtf`/`sqrt` it also
> satisfies C/D/Zig — linking it gives **all four frontends parity** (exp 26):
> `sqrt(2)·100 → C=141 Zig=141 D=141 Rust=141` on mos-sim.

| | float `sqrt` at runtime (mos-sim) | `+-*/` | integer |
|--|--|--|--|
| C / C++ | ❌ alone (`<math.h>` has no `sqrtf`) · ✅ link the `libm` crate | ✅ | `abs`/`labs` |
| **Zig** | ❌ alone (`std.math.sqrt`→`sqrtf` undefined) · ✅ link the `libm` crate | ✅ | ✅ `std.math.gcd` |
| **D** | ❌ alone (`core.math.sqrt`→`sqrtf` undefined) · ✅ link the `libm` crate | ✅ | ✅ |
| **Rust** | ✅ **native** via the `libm` crate (`libm::sqrtf`) | ✅ | ✅ `u16::pow` |

Two caveats (exp 26): a *comptime-constant* `sqrt(2.0)` is **folded** (no libcall) — the
gap is only for *runtime* inputs; and the `f32`→int cast must be **non-saturating**
(`to_int_unchecked()` / `@intFromFloat` → `__fixsfsi`), since the saturating cast
(`as i32`) hits the unlowerable `G_FPTOSI_SAT`/`G_FPTOUI_SAT` backend gap. (Zig's own
`compiler_rt` *has* a musl `sqrtf`, but it isn't auto-linked here and `-fcompiler-rt` is
MOS-broken by `cos.zig`; the Rust `libm` crate is the clean shared provider.)

## Zig `std` does hashing & crypto on a 6502 (exp 24)

The exp 24 benchmark adds a stdlib dimension, and Zig's reach is striking — these
all compile `mos-freestanding` and run on mos-sim, byte-exact:

| Zig std | result | cycles |
|--|--|--|
| `std.hash.crc.Crc16Xmodem` | crc16 = 0x7E55 | **29.5 K** — table-based, vs the hand-rolled bit-serial 109 K (3.7×) |
| `std.crypto.hash.sha2.Sha256` | SHA-256 byte-exact vs host | 639 K / 256 B |
| `std.math.sqrt` | isqrt(64000) = 252 | 1.5 K |

A real cryptographic hash on a 1975 8-bit CPU, pulled from the language stdlib
with zero porting. **Only Zig** can do this on bare-metal MOS: C/C++ (STL subset),
Rust (`core`), and D (`-betterC`, no Phobos `std.digest`) have no hashing/crypto
in their reachable stdlib — every other language in exp 24 must hand-roll the CRC.
The catch: `std.crypto`+`std.hash` pull a **large transitive closure** (~50 KB
here; the three functions are ~1.2 KB) that `build-obj` doesn't dead-code-
eliminate, so the stdlib kernels run in their own image — but they fit and run in
64 KB.

## Real-world mos-sim use (exp 16)

`mos-sim` is a genuine I/O target, not just a return-code checker — it exposes
stdin / EOF / stdout / exit / abort and a 4-byte cycle counter over MMIO (the
full `$FFFx` map is in docs/01).

Demonstrated:
- **Interactive stdin filter** (exp 16) — a C `getchar`/`putchar` loop pipes each
  byte through a **Zig** `up()` FFI worker (uppercase) until EOF; piping a 2-line
  input (`hello from the 6502` / `mixed Case 123!`) yields it uppercased, and the
  program reads the `$FFF0` counter to report `36 chars in 1825 cycles`. Real
  stdin→stdout I/O plus cross-language FFI plus cycle measurement in one 6502 image.

## MMIO hardware-register parity (exp 20)

Real 6502 HALs are just **volatile MMIO register access** — `mlund/mos-hardware`
(the Rust C64/MEGA65 HAL) is `poke! = core::ptr::write_volatile`, register structs
of `RW<u8>` at fixed addresses; `mega65-libc` is the same `POKE`/register pattern
in C. Exp 20 ports that one primitive to all five frontends — a poke to the fixed
MMIO register `$FFF9` (the sim console, standing in for e.g. the C64 VIC-II
`border_color` at `$D020`):

| | idiom |
|--|--|
| C / C++ | `*(volatile uint8_t*)0xFFF9 = c` |
| D | `core.volatile.volatileStore(cast(ubyte*)0xFFF9, c)` — **`@system`** (raw ptr under `-preview=safer`) |
| Zig | `@as(*volatile u8, @ptrFromInt(0xFFF9)).* = c` |
| Rust | `core::ptr::write_volatile(0xFFF9 as *mut u8, c)` (mos-hardware's `poke!`) |

All five lower to the **byte-identical** 6502 store `sta $fff9`, and linked
together they drive the same register to print `C+RDZ`. So a portable 6502 HAL
needs no per-language backend — the volatile-MMIO primitive is identical across
frontends; only the surface syntax (and D's `@system` honesty) differs.
