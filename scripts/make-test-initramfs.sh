#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <arm64|x86_64> [output.cpio.gz]

Build a target-architecture smoke-test initramfs without using BusyBox,
foreign-architecture Debian packages, or dpkg multiarch.  The /init payload is
compiled from scripts/tiny-init.c as a static, libc-free ELF for the requested
architecture.

Environment:
  CC    Compiler, default: clang
USAGE
}

if [[ $# -lt 1 || $# -gt 2 ]]; then usage >&2; exit 2; fi

ARCH="$1"
case "$ARCH" in
  arm64)
    TARGET="aarch64-linux-gnu"
    FILE_RE='ARM aarch64|ARM64|aarch64'
    ;;
  x86_64)
    TARGET="x86_64-linux-gnu"
    FILE_RE='x86-64|x86_64'
    ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$REPO_ROOT/build/test-initramfs-root-$ARCH"
OUT="${2:-$REPO_ROOT/dist/$ARCH/test-initramfs.cpio.gz}"
CC="${CC:-clang}"

mkdir -p "$(dirname "$OUT")"
rm -rf "$WORK"
mkdir -p "$WORK"/{dev,proc,sys,run,tmp,mnt/host}

if ! command -v "$CC" >/dev/null 2>&1; then
  echo "compiler not found: $CC" >&2
  exit 1
fi

"$CC" \
  --target="$TARGET" \
  -fuse-ld=lld \
  -Os \
  -ffreestanding \
  -fno-builtin \
  -fno-stack-protector \
  -fno-pic \
  -static \
  -nostdlib \
  -Wl,-e,_start \
  -Wl,--build-id=none \
  -o "$WORK/init" \
  "$REPO_ROOT/scripts/tiny-init.c"

chmod +x "$WORK/init"

if ! file "$WORK/init" | grep -Eq "$FILE_RE"; then
  echo "smoke-test /init was not built for $ARCH" >&2
  file "$WORK/init" >&2 || true
  exit 1
fi

echo "==> smoke-test /init for $ARCH"
file "$WORK/init"

(
  cd "$WORK"
  find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9n > "$OUT"
)

echo "==> wrote $OUT"
