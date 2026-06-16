#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <arm64|x86_64>" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="$1"
INITRD="${INITRD:-$REPO_ROOT/dist/$ARCH/test-initramfs.cpio.gz}"
LOG_DIR="$REPO_ROOT/dist/$ARCH"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/qemu-smoke.log"

if [[ ! -f "$INITRD" ]]; then
  "$REPO_ROOT/scripts/make-test-initramfs.sh" "$ARCH" "$INITRD"
fi

case "$ARCH" in
  arm64)
    KERNEL="$REPO_ROOT/dist/arm64/kernel"
    QEMU=qemu-system-aarch64
    CMD=(timeout 90s "$QEMU" -machine virt -cpu max -m 512M -kernel "$KERNEL" -initrd "$INITRD" -append "console=ttyAMA0 panic=-1" -nographic -no-reboot)
    ;;
  x86_64)
    KERNEL="$REPO_ROOT/dist/x86_64/kernel"
    QEMU=qemu-system-x86_64
    CMD=(timeout 90s "$QEMU" -machine q35 -cpu max -m 512M -kernel "$KERNEL" -initrd "$INITRD" -append "console=ttyS0 panic=-1" -nographic -no-reboot)
    ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 2 ;;
esac

if [[ ! -f "$KERNEL" ]]; then
  echo "kernel artifact not found: $KERNEL" >&2
  exit 1
fi

set +e
"${CMD[@]}" > "$LOG" 2>&1
STATUS=$?
set -e

if grep -q 'DS_KERNEL_BOOT_OK' "$LOG"; then
  echo "QEMU smoke test passed for $ARCH"
  exit 0
fi

echo "QEMU smoke test failed for $ARCH; status=$STATUS" >&2
tail -200 "$LOG" >&2 || true
exit 1
