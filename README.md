# droidspaces-kernel-vz

Linux kernel configuration and CI for a Droidspaces appliance VM running under Apple Virtualization.framework.

This repository intentionally does **not** vendor the Linux kernel source and does **not** vendor Droidspaces. It keeps the kernel work as a small, auditable set of Kconfig fragments plus reproducible build scripts.

## Targets

- `arm64`: Apple Silicon Macs, kernel artifact `Image`
- `x86_64`: Intel Macs, kernel artifact `bzImage`

## Design

The kernel is optimized for:

- Apple Virtualization.framework direct Linux boot
- ACPI, PCI, PCI MSI, and relocatable-kernel placement support
- VirtIO block, network, console, filesystem, entropy, and vsock devices
- Droidspaces container primitives: namespaces, cgroups, devpts, loop images, OverlayFS, veth/bridge, NAT/netfilter
- sparse raw ext4/f2fs images used as container backing stores

The repository starts from upstream `allnoconfig`, then merges:

```text
configs/apple-vz.config
configs/droidspaces.config
configs/<arch>.config
```

## Quick build

```sh
./scripts/build-kernel.sh arm64
./scripts/build-kernel.sh x86_64
```

By default `main` fetches the `linux-7.1.y` branch from kernel.org stable Linux.

The validated `linux-6.12.y` line is retained on the repository's `6.12`
archive branch. `linux-6.18.y` is the manual long-term fallback; it is not the
default on `main`.

Override with:

```sh
KERNEL_REF=linux-6.18.y ./scripts/build-kernel.sh arm64
KERNEL_REF=linux-6.18.y ./scripts/build-kernel.sh x86_64
```

## GitHub Actions

The default workflow builds both supported architectures on Ubuntu using LLVM and uploads:

- kernel image
- `.config`
- `System.map`
- `kernel-release.txt`
- SHA256 manifest
- QEMU boot-smoke log

True Apple Virtualization.framework boot tests should run on self-hosted physical Macs, because hosted macOS CI is itself virtualized and is not a dependable place for nested virtualization tests.

## Policy

1. `main` tracks `linux-7.1.y`; use `linux-6.18.y` only as an explicit
   long-term fallback.
2. Preserve the Apple VZ-validated `linux-6.12.y` line on the `6.12` archive
   branch for recovery and regression comparison.
3. Prefer configuration fragments over kernel patches.
4. Keep `patches/` empty until there is a proven Apple VZ or Droidspaces blocker.
5. Keep boot/runtime-critical drivers built in, not modular.
6. Build both architectures with `CONFIG_NR_CPUS=64`; Project 3 chooses the
   actual vCPU allocation for an individual VM.

## App-facing kernel artifact

Each architecture package exposes the same kernel path:

```text
dist/arm64/kernel
dist/x86_64/kernel
```

The file has no extension and is not externally gzip-compressed. The native
build output is still preserved beside it as `Image` on arm64 and `bzImage` on
x86_64 for diagnostics, but future macOS app code should only need to pass the
canonical `kernel` file to `VZLinuxBootLoader`.
