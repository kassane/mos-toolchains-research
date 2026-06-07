#!/usr/bin/env bash
# Download + unpack the four MOS toolchains into $TOOLS (default /home/user/tools,
# OUTSIDE the repo). Idempotent: skips anything already present. ~360 MB total.
# sha256 pins live in ../toolchains.lock (the content-addressed SOURCE OF TRUTH).
# A mismatch aborts loudly: an upstream re-upload under the same tag breaks the
# build BY DESIGN — see HANDOFF.md "Toolchain re-pin procedure" to bump deliberately.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="$HERE/../toolchains.lock"
TOOLS="${TOOLS:-/home/user/tools}"
[ -f "$LOCK" ] || { echo "!! toolchains.lock missing at $LOCK" >&2; exit 1; }
mkdir -p "$TOOLS/dl"
dl(){ # url outdir marker   (sha256 looked up from toolchains.lock by outdir name)
  local url="$1" out="$2" marker="$3" f="$TOOLS/dl/$(basename "$2").tar.xz"
  [ -e "$TOOLS/$marker" ] && { echo "have $2"; return; }
  local sha; sha="$(awk -v n="$out" '$1==n{print $2}' "$LOCK")"
  [ -n "$sha" ] || { echo "!! no sha256 for '$out' in toolchains.lock" >&2; exit 1; }
  echo ">> $2"; curl -L --fail --retry 5 --retry-all-errors -o "$f" "$url"
  echo "$sha  $f" | sha256sum -c - \
    || { echo "!! SHA256 mismatch for $2 — upstream tag moved or download corrupt; re-pin toolchains.lock deliberately (do NOT loosen the check)" >&2; exit 1; }
  mkdir -p "$TOOLS/$2"; tar -xf "$f" -C "$TOOLS/$2"
}
# Tag URLs (human-edited). The zig URL is a rolling 0.17.0-dev tag; the SDK is a
# stable release. The sha256 in toolchains.lock is what actually gates the build,
# so ALL FOUR — including the SDK — are now content-verified (docs/07).
BASE_ZB=https://github.com/kassane/zig-mos-bootstrap/releases/download
dl "$BASE_ZB/0.17.0-dev/zig-mos-x86_64-linux-musl-baseline.tar.xz" zig  zig/zig-mos-x86_64-linux-musl-baseline/zig
dl "$BASE_ZB/0.1.0/ldc2-mos-x86_64-linux-musl.tar.xz"             ldc  ldc/bin/ldc2
dl "https://github.com/llvm-mos/llvm-mos-sdk/releases/download/v23.0.1/llvm-mos-linux.tar.xz" sdk sdk/llvm-mos/bin/mos-sim
dl "$BASE_ZB/0.1.0/rust-mos-x86_64-linux-glibc-ubuntu.tar.xz"     rust rust/rust-mos-x86_64-linux-glibc/bin/rustc
echo "done. now: source scripts/env.sh && scripts/run-all.sh"
