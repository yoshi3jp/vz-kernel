#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <arm64|x86_64>

Environment:
  LINUX_GIT    Linux git remote, default: https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
  KERNEL_REF   Branch/tag/commit to build, default: linux-6.12.y
  WORK_DIR     Working directory, default: ./build
  DIST_DIR     Artifact directory, default: ./dist
  LLVM         LLVM selector for kbuild, default: 1
  JOBS         Parallel jobs, default: nproc
USAGE
}

if [[ $# -ne 1 ]]; then usage >&2; exit 2; fi

INPUT_ARCH="$1"
case "$INPUT_ARCH" in
  arm64) KARCH="arm64"; IMAGE_REL="arch/arm64/boot/Image" ;;
  x86_64) KARCH="x86"; IMAGE_REL="arch/x86/boot/bzImage" ;;
  *) echo "unsupported arch: $INPUT_ARCH" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINUX_GIT="${LINUX_GIT:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}"
KERNEL_REF="${KERNEL_REF:-linux-6.12.y}"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/build}"
DIST_DIR="${DIST_DIR:-$REPO_ROOT/dist}"
LLVM_ARG="${LLVM:-1}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)}"

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

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

export KBUILD_BUILD_USER="droidspaces"
export KBUILD_BUILD_HOST="github-actions"
export KBUILD_BUILD_TIMESTAMP="1970-01-01 00:00:00 UTC"
export SOURCE_DATE_EPOCH="0"
export KCFLAGS="-fdebug-prefix-map=$SRC_DIR=/usr/src/linux -fdebug-prefix-map=$OUT_DIR=/usr/src/linux-build"
export KAFLAGS="$KCFLAGS"

make -C "$SRC_DIR" O="$OUT_DIR" ARCH="$KARCH" LLVM="$LLVM_ARG" defconfig

bash "$SRC_DIR/scripts/kconfig/merge_config.sh" \
  -m \
  -O "$OUT_DIR" \
  "$OUT_DIR/.config" \
  "$REPO_ROOT/configs/apple-vz.config" \
  "$REPO_ROOT/configs/droidspaces.config" \
  "$REPO_ROOT/configs/$INPUT_ARCH.config"

make -C "$SRC_DIR" O="$OUT_DIR" ARCH="$KARCH" LLVM="$LLVM_ARG" olddefconfig

"$REPO_ROOT/scripts/verify-config.sh" "$OUT_DIR/.config" "$REPO_ROOT/tools/required-symbols.common"

make -C "$SRC_DIR" O="$OUT_DIR" ARCH="$KARCH" LLVM="$LLVM_ARG" -j"$JOBS"

cp "$OUT_DIR/$IMAGE_REL" "$ART_DIR/"
cp "$OUT_DIR/.config" "$ART_DIR/config"
cp "$OUT_DIR/System.map" "$ART_DIR/System.map"
make -s -C "$SRC_DIR" O="$OUT_DIR" ARCH="$KARCH" LLVM="$LLVM_ARG" kernelrelease > "$ART_DIR/kernel-release.txt"

git -C "$SRC_DIR" rev-parse HEAD > "$ART_DIR/linux-commit.txt"
printf '%s\n' "$KERNEL_REF" > "$ART_DIR/linux-ref.txt"

(
  cd "$ART_DIR"
  sha256sum * > SHA256SUMS
)

echo "==> Artifacts written to $ART_DIR"
