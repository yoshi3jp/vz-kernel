#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <arm64|x86_64>

Environment:
  LINUX_GIT    Linux git remote, default: https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
  KERNEL_REF   Branch/tag/commit to build, default: linux-6.12.y
  KERNEL_BASE_CONFIG  Base kconfig target, default: allnoconfig
  WORK_DIR     Working directory, default: ./build
  DIST_DIR     Artifact directory, default: ./dist
  LLVM         LLVM selector for kbuild, default: 1
  JOBS         Parallel jobs, default: nproc
USAGE
}

if [[ $# -ne 1 ]]; then usage >&2; exit 2; fi

INPUT_ARCH="$1"
case "$INPUT_ARCH" in
  arm64)
    KARCH="arm64"
    IMAGE_BUILD_TARGET="Image"
    IMAGE_REL="arch/arm64/boot/Image"
    NATIVE_IMAGE_NAME="Image"
    VZ_KERNEL_FORMAT="linux-arm64-Image"
    IMAGE_DESCRIPTION="AArch64 uncompressed Linux Image"
    ;;
  x86_64)
    KARCH="x86"
    IMAGE_BUILD_TARGET="bzImage"
    IMAGE_REL="arch/x86/boot/bzImage"
    NATIVE_IMAGE_NAME="bzImage"
    VZ_KERNEL_FORMAT="linux-x86-bzImage"
    IMAGE_DESCRIPTION="x86 Linux boot protocol bzImage"
    ;;
  *) echo "unsupported arch: $INPUT_ARCH" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINUX_GIT="${LINUX_GIT:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}"
KERNEL_REF="${KERNEL_REF:-linux-6.12.y}"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/build}"
DIST_DIR="${DIST_DIR:-$REPO_ROOT/dist}"
LLVM_ARG="${LLVM:-1}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)}"
KERNEL_BASE_CONFIG="${KERNEL_BASE_CONFIG:-allnoconfig}"

SRC_DIR="$WORK_DIR/linux-$KERNEL_REF"
OUT_DIR="$WORK_DIR/out-$INPUT_ARCH"
ART_DIR="$DIST_DIR/$INPUT_ARCH"

mkdir -p "$WORK_DIR" "$DIST_DIR" "$ART_DIR"

if [[ ! -d "$SRC_DIR/.git" ]]; then
  echo "==> Fetching Linux $KERNEL_REF"
  git clone --depth=1 --branch "$KERNEL_REF" "$LINUX_GIT" "$SRC_DIR"
else
  echo "==> Updating Linux source in $SRC_DIR"
  git -C "$SRC_DIR" fetch --depth=1 origin "$KERNEL_REF"
  git -C "$SRC_DIR" checkout -q FETCH_HEAD
fi

rm -rf "$OUT_DIR" "$ART_DIR"
mkdir -p "$OUT_DIR" "$ART_DIR"

export KBUILD_BUILD_USER="droidspaces"
export KBUILD_BUILD_HOST="github-actions"
export KBUILD_BUILD_TIMESTAMP="1970-01-01 00:00:00 UTC"
export SOURCE_DATE_EPOCH="0"
export KCFLAGS="-fdebug-prefix-map=$SRC_DIR=/usr/src/linux -fdebug-prefix-map=$OUT_DIR=/usr/src/linux-build"
export KAFLAGS="$KCFLAGS"

make -C "$SRC_DIR" O="$OUT_DIR" ARCH="$KARCH" LLVM="$LLVM_ARG" "$KERNEL_BASE_CONFIG"

bash "$SRC_DIR/scripts/kconfig/merge_config.sh" \
  -m \
  -O "$OUT_DIR" \
  "$OUT_DIR/.config" \
  "$REPO_ROOT/configs/apple-vz.config" \
  "$REPO_ROOT/configs/droidspaces.config" \
  "$REPO_ROOT/configs/$INPUT_ARCH.config"

make -C "$SRC_DIR" O="$OUT_DIR" ARCH="$KARCH" LLVM="$LLVM_ARG" olddefconfig

"$REPO_ROOT/scripts/verify-config.sh" "$OUT_DIR/.config" "$REPO_ROOT/tools/required-symbols.common"

# Build only the architecture's canonical boot image target.
#
# Do not pass the final path (for example arch/arm64/boot/Image) as the make
# target here. With O= out-of-tree builds, kbuild expects the short arch target
# names such as `Image` and `bzImage`; passing the output path can fail with
# "No rule to make target ..." before compilation starts.
make -C "$SRC_DIR" O="$OUT_DIR" ARCH="$KARCH" LLVM="$LLVM_ARG" -j"$JOBS" "$IMAGE_BUILD_TARGET"

if [[ ! -f "$OUT_DIR/$IMAGE_REL" ]]; then
  echo "built image not found: $OUT_DIR/$IMAGE_REL" >&2
  exit 1
fi

# App-facing artifact contract:
#   dist/<arch>/kernel
# The native build target differs by architecture, but the macOS app should not
# need to special-case Image vs bzImage. It always passes this extensionless
# kernel file to VZLinuxBootLoader.
cp "$OUT_DIR/$IMAGE_REL" "$ART_DIR/kernel"
cp "$OUT_DIR/$IMAGE_REL" "$ART_DIR/$NATIVE_IMAGE_NAME"
cp "$OUT_DIR/.config" "$ART_DIR/config"
cp "$OUT_DIR/System.map" "$ART_DIR/System.map"
make -s -C "$SRC_DIR" O="$OUT_DIR" ARCH="$KARCH" LLVM="$LLVM_ARG" kernelrelease > "$ART_DIR/kernel-release.txt"

git -C "$SRC_DIR" rev-parse HEAD > "$ART_DIR/linux-commit.txt"
printf '%s\n' "$KERNEL_REF" > "$ART_DIR/linux-ref.txt"

cat > "$ART_DIR/kernel-info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>ArtifactVersion</key>
  <integer>1</integer>
  <key>Architecture</key>
  <string>$INPUT_ARCH</string>
  <key>LinuxArchitecture</key>
  <string>$KARCH</string>
  <key>KernelPath</key>
  <string>kernel</string>
  <key>NativeImageName</key>
  <string>$NATIVE_IMAGE_NAME</string>
  <key>NativeImageBuildTarget</key>
  <string>$IMAGE_BUILD_TARGET</string>
  <key>NativeImagePath</key>
  <string>$IMAGE_REL</string>
  <key>VirtualizationFrameworkBootLoader</key>
  <string>VZLinuxBootLoader</string>
  <key>KernelFormat</key>
  <string>$VZ_KERNEL_FORMAT</string>
  <key>ImageDescription</key>
  <string>$IMAGE_DESCRIPTION</string>
  <key>ExternallyCompressed</key>
  <false/>
</dict>
</plist>
PLIST

(
  cd "$ART_DIR"
  sha256sum * > SHA256SUMS
)

echo "==> Artifacts written to $ART_DIR"
echo "==> App-facing kernel path: $ART_DIR/kernel"
