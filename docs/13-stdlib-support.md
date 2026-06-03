# 13 — Standard-library reach, math & real-world I/O (exp 15, 16)

docs/00–12 covered the ABI. This is about how much of each language's *standard
library* actually works on bare MOS, the float-math story, and a real
interactive program on `mos-sim`.

## Stdlib reach per frontend (exp 15, all run on mos-sim)

| lang | what works on MOS | notes |
|------|-------------------|-------|
| **C** | full freestanding **libc**: `printf`, `malloc`/`free`, `getchar`/`putchar`, `string.h`, `ctype.h`, `setjmp` | the SDK's `mos-platform/common` |
| **C++** | **minimal STL subset**: `<array>`, `<type_traits>`, `<utility>`, `<iterator>`, `<new>`, `min_element`/`max_element` | **no `std::sort`**; `std::array` needs `{{…}}` and isn't a full aggregate |
| **Zig** | **rich `std` subset**: `std.mem` (`sort`,`min`,`max`), `std.sort`, `std.fmt.bufPrint` (`{d}`/`{x}`), `std.meta.fields`, `std.math` | comptime-instantiated; the most capable on MOS |
| **Rust** | `core` + **`alloc`** (`Vec`/`Box`) once you supply a `#[global_allocator]` | no `std`; here the allocator wraps the SDK `malloc`/`free` |
| **D** | `-betterC`: `core.stdc.string`, `core.bitop`, **all `ldc.*`** (`intrinsics`/`attributes`/`llvmasm`), `core.math` | **`core.stdc.stdio`/`stdlib` are NOT ported** (`static assert "unsupported system"` / undefined `c_long`); no Phobos (`std.*`), so hand-declare `extern(C) printf` |

D library-import specifics (probed): `core.stdc.string` ✓, `core.bitop` ✓,
`ldc.intrinsics`/`ldc.attributes`/`ldc.llvmasm` ✓, `std.experimental.allocator`
building-blocks compile but **`Mallocator` fails** (it needs the unported
`core.stdc.stdlib`). `import std.math` fails (`undefined c_long`).

## Math: who can do float on a CPU with no FPU? (exp 15)

Soft-float, and the answer is surprising — **D and Zig beat C**:

| | float math (e.g. `sqrt(2)`) | integer math |
|--|--|--|
| C / C++ | ❌ the SDK `<math.h>` declares **no `sqrt`/`sin`/`pow`** | `abs`/`labs` only |
| **Zig** | ✅ `std.math.sqrt(f32)` → `1.414` (own soft-float) | ✅ `std.math.gcd`, … |
| **D** | ✅ `core.math.sqrt` → `1.414` (LDC soft-float libcall) | ✅ |
| Rust | ❌ `f32::sqrt` is **std-only** (not in `core`; needs a `libm` crate) | ✅ `u16::pow`, … in `core` |

So on bare MOS, Zig (`std.math`) and D (`core.math`) compute `√2 = 1.41421`
correctly via software float, while C (`math.h` is essentially empty) and
`no_std` Rust cannot without an external libm. Integer math is universal.

## Real-world mos-sim use (exp 16)

`mos-sim` is a genuine I/O target, not just a return-code checker. The MMIO map:
`$FFF5` stdin / `$FFF6` EOF / `$FFF9` stdout / `$FFF8` exit / `$FFF0` (4B) cycle
counter (`--cycles`/`--trace`/`--cmos` flags).

Demonstrated:
- **Heap** — the SDK `malloc` succeeds (500 B at `0x1aa6`) and correctly returns
  `NULL` for 40000 B (exceeds the 64 KB space).
- **Interactive stdin filter** (exp 16) — a C `getchar`/`putchar` loop pipes each
  byte through a **Zig** `up()` FFI worker (uppercase) until EOF; piping
  `"hello from the 6502"` yields `HELLO FROM THE 6502`, and the program reads the
  `$FFF0` counter to report `36 chars in 1825 cycles`. Real stdin→stdout I/O plus
  cross-language FFI plus cycle measurement in one runnable 6502 image.
