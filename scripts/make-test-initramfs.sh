#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$REPO_ROOT/build/test-initramfs-root"
OUT="${1:-$REPO_ROOT/test-initramfs.cpio.gz}"
BUSYBOX="${BUSYBOX:-/bin/busybox}"

if [[ ! -x "$BUSYBOX" && -x /usr/bin/busybox ]]; then
  BUSYBOX=/usr/bin/busybox
fi
if [[ ! -x "$BUSYBOX" ]]; then
  echo "busybox not found; install busybox-static or set BUSYBOX=/path/to/busybox" >&2
  exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK"/{bin,sbin,proc,sys,dev,run,tmp,mnt/host}
cp "$BUSYBOX" "$WORK/bin/busybox"
chmod +x "$WORK/bin/busybox"

cat > "$WORK/init" <<'INIT'
#!/bin/busybox sh
/bin/busybox --install -s /bin
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || mount -t tmpfs devtmpfs /dev 2>/dev/null || true
mkdir -p /dev/pts /run /tmp /mnt/host
mount -t devpts devpts /dev/pts -o newinstance,ptmxmode=0666,mode=0620 2>/dev/null || true
printf 'DS_KERNEL_BOOT_OK\n'
printf 'uname: '; uname -a
printf 'cmdline: '; cat /proc/cmdline
poweroff -f 2>/dev/null || halt -f 2>/dev/null || reboot -f
INIT
chmod +x "$WORK/init"

(
  cd "$WORK"
  find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9n > "$OUT"
)

echo "==> wrote $OUT"
