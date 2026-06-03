#!/usr/bin/env bash
# Source this: `source scripts/env.sh`
# Toolchains live OUTSIDE the repo (never committed) under /home/user/tools.
export TOOLS=/home/user/tools

# Zig 0.17.0-mos-dev (bundled LLVM 22) — also `zig cc` / `zig c++`
export ZIG="$TOOLS/zig/zig-mos-x86_64-linux-musl-baseline/zig"
# LDC 1.42.0 (LLVM 22.0.0) — D; use -betterC for bare-metal MOS
export LDC="$TOOLS/ldc/bin/ldc2"
# llvm-mos-sdk v23.0.1 (LLVM 23) — mos-*-clang drivers, clang, ld.lld, llvm-*
export SDK="$TOOLS/sdk/llvm-mos"
export SDKBIN="$SDK/bin"
export MOSCLANG="$SDKBIN/clang"          # raw `--target=mos` clang (LLVM 23)
export MOSCXX="$SDKBIN/clang++"
export LLD="$SDKBIN/ld.lld"
export LLVMLINK="$SDKBIN/llvm-link"
export LLVMAS="$SDKBIN/llvm-as"
export LLVMDIS="$SDKBIN/llvm-dis"
export OPT="$SDKBIN/opt"
export LLC="$SDKBIN/llc"
export OBJDUMP="$SDKBIN/llvm-objdump"
export NM="$SDKBIN/llvm-nm"
export READOBJ="$SDKBIN/llvm-readobj"
export SIZE="$SDKBIN/llvm-size"
# rust-mos 1.98.0-dev (LLVM 23, glibc build)
export RUSTBIN="$TOOLS/rust/rust-mos-x86_64-linux-glibc/bin"
export RUSTC="$RUSTBIN/rustc"
export CARGO="$RUSTBIN/cargo"
export RUST_SYSROOT="$($RUSTC --print sysroot 2>/dev/null)"

# Canonical CPU/triple knobs
export MOS_TRIPLE=mos
export MOS_CPU=mos6502
# LLVM subtarget features that clang/rust/zig auto-enable for -mcpu=mos6502.
# LDC's -mcpu=mos6502 leaves features EMPTY (ldc#4919 class bug), so LDC
# invocations pass -mattr=$MOS_MATTR explicitly. Spelling lifted verbatim from
# Zig's emitted IR target-features (experiments/06-cpu-features).
export MOS_MATTR='+mos6502,+mos-insns-6502,+mos-insns-6502bcd,+static-stack'
