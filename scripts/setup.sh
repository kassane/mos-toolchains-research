#!/usr/bin/env bash
# Download + unpack the four MOS toolchains into $TOOLS (default /home/user/tools,
# OUTSIDE the repo). Idempotent: skips anything already present. ~360 MB total.
set -euo pipefail
TOOLS="${TOOLS:-/home/user/tools}"
mkdir -p "$TOOLS/dl"
dl(){ # url outdir marker
  local url="$1" out="$2" marker="$3" f="$TOOLS/dl/$(basename "$2").tar.xz"
  [ -e "$TOOLS/$marker" ] && { echo "have $2"; return; }
  echo ">> $2"; curl -L --fail --retry 5 --retry-all-errors -o "$f" "$url"
  mkdir -p "$TOOLS/$2"; tar -xf "$f" -C "$TOOLS/$2"
}
BASE_ZB=https://github.com/kassane/zig-mos-bootstrap/releases/download
dl "$BASE_ZB/0.17.0-dev/zig-mos-x86_64-linux-musl-baseline.tar.xz" zig  zig/zig-mos-x86_64-linux-musl-baseline/zig
dl "$BASE_ZB/0.1.0/ldc2-mos-x86_64-linux-musl.tar.xz"             ldc  ldc/bin/ldc2
dl "https://github.com/llvm-mos/llvm-mos-sdk/releases/download/v23.0.1/llvm-mos-linux.tar.xz" sdk sdk/llvm-mos/bin/mos-sim
dl "$BASE_ZB/0.1.0/rust-mos-x86_64-linux-glibc-ubuntu.tar.xz"     rust rust/rust-mos-x86_64-linux-glibc/bin/rustc
echo "done. now: source scripts/env.sh && scripts/run-all.sh"
