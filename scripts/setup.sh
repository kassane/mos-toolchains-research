#!/usr/bin/env bash
# Download + unpack the four MOS toolchains into $TOOLS (default /home/user/tools,
# OUTSIDE the repo). Idempotent: skips anything already present. ~360 MB total.
set -euo pipefail
TOOLS="${TOOLS:-/home/user/tools}"
mkdir -p "$TOOLS/dl"
dl(){ # url outdir marker sha256
  local url="$1" out="$2" marker="$3" sha="${4:-}" f="$TOOLS/dl/$(basename "$2").tar.xz"
  [ -e "$TOOLS/$marker" ] && { echo "have $2"; return; }
  echo ">> $2"; curl -L --fail --retry 5 --retry-all-errors -o "$f" "$url"
  if [ -n "$sha" ]; then
    echo "$sha  $f" | sha256sum -c - \
      || { echo "!! SHA256 mismatch for $2 — upstream tag moved or download corrupt; update the pin" >&2; exit 1; }
  fi
  mkdir -p "$TOOLS/$2"; tar -xf "$f" -C "$TOOLS/$2"
}
# SHA256 pins (verified 2026-06): zig/ldc/rust rebuilt — see docs/07. The zig URL is a
# rolling 0.17.0-dev tag, so its pin will trip when upstream rolls (intended: update it).
BASE_ZB=https://github.com/kassane/zig-mos-bootstrap/releases/download
dl "$BASE_ZB/0.17.0-dev/zig-mos-x86_64-linux-musl-baseline.tar.xz" zig  zig/zig-mos-x86_64-linux-musl-baseline/zig 8f45d8969fec2f624e43bf8022046e1d83c41ad19f75421367b39c0be89345ff
dl "$BASE_ZB/0.1.0/ldc2-mos-x86_64-linux-musl.tar.xz"             ldc  ldc/bin/ldc2                              40c2f8c8a5e7e24750a11ab4a3ccb7d601f860409e711d3f8539f883d0822c21
dl "https://github.com/llvm-mos/llvm-mos-sdk/releases/download/v23.0.1/llvm-mos-linux.tar.xz" sdk sdk/llvm-mos/bin/mos-sim   # SDK v23.0.1 (stable release tag; pin omitted)
dl "$BASE_ZB/0.1.0/rust-mos-x86_64-linux-glibc-ubuntu.tar.xz"     rust rust/rust-mos-x86_64-linux-glibc/bin/rustc 26f8e36245d73dbc4affdb258a572642aec885ff5d3049a7c35ff4d990cc93de
echo "done. now: source scripts/env.sh && scripts/run-all.sh"
