#!/usr/bin/env python3
"""Verify VZLinuxBootLoader-facing invariants of a generated Linux image."""

from __future__ import annotations

import struct
import sys
from pathlib import Path

ARM64_MAGIC = 0x644D5241  # "ARM\\x64" in little-endian form.
X86_SETUP_HEADER_MAGIC = b"HdrS"


def fail(message: str) -> None:
    print(f"boot-image verification failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def read_prefix(path: Path, size: int) -> bytes:
    data = path.read_bytes()[:size]
    if len(data) < size:
        fail(f"{path} is too short: need at least {size} bytes, got {len(data)}")
    return data


def verify_arm64(path: Path) -> None:
    # The raw arm64 Image header is 64 bytes. image_size=0 is valid for legacy
    # images, but modern kbuild output should provide it; require it so the VZ
    # artifact remains a fully described current arm64 Image.
    data = read_prefix(path, 64)
    image_size = struct.unpack_from("<Q", data, 16)[0]
    magic = struct.unpack_from("<I", data, 56)[0]

    if magic != ARM64_MAGIC:
        fail(f"arm64 Image magic is 0x{magic:08x}, expected 0x{ARM64_MAGIC:08x}")
    if image_size == 0:
        fail("arm64 Image header has image_size=0")

    print(
        "verified arm64 Image: "
        f"magic=0x{magic:08x} image_size=0x{image_size:x}"
    )


def verify_x86_64(path: Path) -> None:
    # setup_header offsets are defined by Documentation/arch/x86/boot.rst.
    data = read_prefix(path, 0x264)
    magic = data[0x202:0x206]
    protocol = struct.unpack_from("<H", data, 0x206)[0]
    kernel_alignment = struct.unpack_from("<I", data, 0x230)[0]
    relocatable_kernel = data[0x234]
    xloadflags = struct.unpack_from("<H", data, 0x236)[0]
    init_size = struct.unpack_from("<I", data, 0x260)[0]

    if magic != X86_SETUP_HEADER_MAGIC:
        fail(f"x86 setup header magic is {magic!r}, expected {X86_SETUP_HEADER_MAGIC!r}")
    if protocol < 0x020A:
        fail(f"x86 boot protocol is 0x{protocol:04x}, need at least 0x020a")
    if kernel_alignment == 0:
        fail("x86 bzImage kernel_alignment is zero")
    if relocatable_kernel != 1:
        fail(
            "x86 bzImage advertises relocatable_kernel="
            f"{relocatable_kernel}; VZ kernel requires relocatable_kernel=1"
        )
    if init_size == 0:
        fail("x86 bzImage init_size is zero")

    print(
        "verified x86 bzImage: "
        f"protocol=0x{protocol:04x} alignment=0x{kernel_alignment:x} "
        f"relocatable_kernel={relocatable_kernel} xloadflags=0x{xloadflags:02x} "
        f"init_size=0x{init_size:x}"
    )


def main() -> None:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <arm64|x86_64> <kernel-image>", file=sys.stderr)
        raise SystemExit(2)

    arch = sys.argv[1]
    image = Path(sys.argv[2])
    if not image.is_file():
        fail(f"not a regular file: {image}")

    if arch == "arm64":
        verify_arm64(image)
    elif arch == "x86_64":
        verify_x86_64(image)
    else:
        fail(f"unsupported architecture: {arch}")


if __name__ == "__main__":
    main()
