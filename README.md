# droidspaces-kernel-vz

Linux kernel configuration and CI for a Droidspaces appliance VM running under Apple Virtualization.framework.

This repository intentionally does **not** vendor the Linux kernel source and does **not** vendor Droidspaces. It keeps the kernel work as a small, auditable set of Kconfig fragments plus reproducible build scripts.

## Targets

- `arm64`: Apple Silicon Macs, kernel artifact `Image`
- `x86_64`: Intel Macs, kernel artifact `bzImage`

## Design

The kernel is optimized for:

- Apple Virtualization.framework direct Linux boot
- VirtIO block, network, console, filesystem, entropy, and vsock devices
- Droidspaces container primitives: namespaces, cgroups, devpts, loop images, OverlayFS, veth/bridge, NAT/netfilter
- sparse raw ext4/f2fs images used as container backing stores

The repository starts from each architecture's upstream `defconfig`, then merges:

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

By default this fetches the `linux-6.12.y` branch from kernel.org stable Linux.

Override with:

```sh
KERNEL_REF=linux-7.0.y ./scripts/build-kernel.sh arm64
KERNEL_REF=linux-6.6.y ./scripts/build-kernel.sh x86_64
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

1. Prefer upstream stable/LTS Linux.
2. Prefer configuration fragments over kernel patches.
3. Keep `patches/` empty until there is a proven Apple VZ or Droidspaces blocker.
4. Keep boot/runtime-critical drivers built in, not modular.
