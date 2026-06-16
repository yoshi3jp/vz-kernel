#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <arm64|x86_64> [output.cpio.gz]

Environment:
  BUSYBOX        Target-architecture static BusyBox path. If unset, the script
                 tries to use/copy an appropriate busybox-static binary.
USAGE
}

if [[ $# -lt 1 || $# -gt 2 ]]; then usage >&2; exit 2; fi

ARCH="$1"
case "$ARCH" in
  arm64) DEB_ARCH="arm64"; FILE_RE='ARM aarch64|ARM64|aarch64' ;;
  x86_64) DEB_ARCH="amd64"; FILE_RE='x86-64|x86_64' ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$REPO_ROOT/build/test-initramfs-root-$ARCH"
OUT="${2:-$REPO_ROOT/dist/$ARCH/test-initramfs.cpio.gz}"
CACHE="$REPO_ROOT/build/busybox-$ARCH"
BUSYBOX="${BUSYBOX:-}"

mkdir -p "$(dirname "$OUT")" "$CACHE"

is_target_busybox() {
  local bin="$1"
  [[ -x "$bin" ]] || return 1
  file "$bin" | grep -Eq "$FILE_RE" || return 1
}

fetch_busybox_deb() {
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    apt-get download "busybox-static:$DEB_ARCH" >/dev/null
    dpkg-deb -x busybox-static_*_${DEB_ARCH}.deb "$CACHE"
  )
  rm -rf "$tmp"
}

if [[ -n "$BUSYBOX" ]]; then
  if ! is_target_busybox "$BUSYBOX"; then
    echo "BUSYBOX=$BUSYBOX is not a static BusyBox for $ARCH" >&2
    file "$BUSYBOX" >&2 || true
    exit 1
  fi
else
  if is_target_busybox "$CACHE/bin/busybox"; then
    BUSYBOX="$CACHE/bin/busybox"
  elif is_target_busybox /bin/busybox; then
    BUSYBOX=/bin/busybox
  elif is_target_busybox /usr/bin/busybox; then
    BUSYBOX=/usr/bin/busybox
  elif command -v apt-get >/dev/null 2>&1 && command -v dpkg-deb >/dev/null 2>&1; then
    fetch_busybox_deb || {
      echo "failed to fetch busybox-static:$DEB_ARCH" >&2
      echo "For foreign architectures, run: sudo dpkg --add-architecture $DEB_ARCH && sudo apt-get update" >&2
      exit 1
    }
    BUSYBOX="$CACHE/bin/busybox"
  else
    echo "busybox for $ARCH not found; set BUSYBOX=/path/to/static/target/busybox" >&2
    exit 1
  fi
fi

if ! is_target_busybox "$BUSYBOX"; then
  echo "selected BusyBox is not executable for target $ARCH: $BUSYBOX" >&2
  file "$BUSYBOX" >&2 || true
  exit 1
fi

echo "==> using BusyBox for $ARCH: $BUSYBOX"
file "$BUSYBOX"

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
