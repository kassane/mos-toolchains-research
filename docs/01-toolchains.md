# 01 — Toolchains

Four LLVM frontends, two LLVM versions. Downloaded by `scripts/setup.sh` into
`$TOOLS` (outside the repo). Versions are from `--version` on the actual binaries.

## C / C++ — llvm-mos-sdk v23.0.1

```
clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos c798c31416f7…)
Target: mos
```

The SDK is the reference toolchain: `clang`/`clang++` plus **42 platform driver
wrappers** `mos-<platform>-clang` (c64, nes-*, atari*, cx16, mega65, **sim**, …)
that bake in the memory map, crt0, linker script and libc. `mos-common-clang`
is the bare freestanding parent; `mos-sim-clang` targets the bundled `mos-sim`
simulator. Ships `ld.lld` and binutils-style tools (`llvm-objdump`, `llvm-nm`,
`llvm-ar`, `llvm-mc`) but **not** `llvm-link`/`opt`/`llc`. Platform builds
default to whole-program **LTO** (`-mlto-zp=224`, for zero-page allocation).

```bash
$MOSCLANG --target=mos -mcpu=mos6502 -Oz -S -emit-llvm file.c   # raw IR
mos-sim-clang -Os file.c -o out.elf                              # platform build+link
```

## Rust — rust-mos 1.98.0-dev (LLVM 23)

`rustc --print cfg --target mos-unknown-none -C target-cpu=mos6502` →
`target_arch="mos"`, `target_pointer_width="16"`, `target_endian="little"`,
`panic="abort"`, `relocation_model="pic"`, `target_os="none"`, atomics 8-bit only.
No prebuilt `core`; needs `-Z build-std` + `rust-src` (shipped). Use a cargo
crate with:

```toml
# .cargo/config.toml
[unstable]
build-std = ["core", "compiler_builtins"]
build-std-features = ["compiler-builtins-mem"]
[build]
target = "mos-unknown-none"
rustflags = ["-Ctarget-cpu=mos6502"]
# Cargo.toml [profile.release]: panic="abort", opt-level="s", lto=true
```

`lto = true` is effectively required: without it the native codegen of
`core`'s `Ord::cmp` hits `unable to legalize G_UCMP s8 from s32` (MOS GlobalISel
gap). Build with `RUSTC_BOOTSTRAP=1`. `mos-unknown-none` is **not** upstream.

## Zig — 0.17.0-mos-dev (bundled clang/LLVM 22)

Arch is `mos`, CPU goes in `-mcpu`; the triple is `mos-freestanding` on the CLI
(`mos-unknown-unknown-unknown` in IR). `zig targets` prints **ZON**, not JSON.

```bash
$ZIG build-obj -target mos-freestanding -mcpu mos6502 -OReleaseSmall -femit-bin=o.o file.zig
$ZIG build-obj --show-builtin -target mos-freestanding -mcpu mos6502   # resolved features
```

`--show-builtin` reports the auto-enabled feature set
`{mos6502, mos_insns_6502, mos_insns_6502bcd, static_stack}`. FFI via
`export fn … callconv(.c)`, `extern fn`, `translate-c`, and `@addrspace(.zp)`.
`zig cc` defaults to UBSan in Debug — use `-fno-sanitize=undefined`/`-nostdlib`
for freestanding C (not used here; 6502 C goes through the SDK clang 23).

## D — LDC 1.42.0 (DMD 2.112.1, LLVM 22)

```
LDC - the LLVM D compiler (1.42.0): based on DMD v2.112.1 and LLVM 22.0.0
```

`-betterC` only on MOS (no druntime/Phobos). LDC predefines `version(MOS6502)`.
`-mcpu=mos6502` leaves the LLVM feature string empty (ldc#4919 class), so we add
`-mattr=$MOS_MATTR`; it's benign for the base CPU (docs/06). `--help-hidden`
lists the MOS-relevant knobs: `--output-{ll,bc,s,o}`, `--mattr=help`,
`--relocation-model`, `--code-model`, `--mos-force-pcrel-reloc`.

```bash
$LDC -betterC -Oz --mtriple=mos -mcpu=mos6502 -mattr=$MOS_MATTR -c file.d -of=o.o
$LDC -betterC -Oz --mtriple=mos -mcpu=mos6502 -output-ll -of=out.ll -c file.d   # IR
```

## The mos-sim simulator

x86-64 host binary; takes a memory **image** (not ELF). MMIO (canonical map):
`$FFF0` 4-byte cycle counter, `$FFF5` stdin, `$FFF6` EOF (1 if last `$FFF5` was
EOF), `$FFF7` abort, `$FFF8` exit code, `$FFF9` stdout. Flags: `--cycles`,
`--trace`, `--profile`, `--cmos` (65C02). Run: `mos-sim img`.
