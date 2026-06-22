# Architecture

Project 1 produces the kernel side of the Droidspaces macOS appliance.

```text
macOS
 └── Apple Virtualization.framework
      └── Linux kernel from this repository
           └── Droidspaces initramfs / userspace, supplied by another project
```

This repository is concerned only with the kernel.

## Upstream-series policy

`main` targets `linux-7.1.y`. The proven `linux-6.12.y` configuration remains
on the `6.12` archive branch for recovery and regression comparison.
`linux-6.18.y` is the supported long-term fallback selected explicitly with
`KERNEL_REF`; it is not the default for `main`.

Both architecture builds set `CONFIG_NR_CPUS=64`. This is a kernel ceiling,
not a request to create a 64-vCPU VM; the macOS launcher remains responsible
for selecting an appropriate vCPU count for each VM.

## Kernel contract

The kernel must support:

- direct Linux boot with initramfs
- ACPI, PCI, PCI MSI, and relocatable kernel placement for VZ boot loaders
- serial console suitable for `console=hvc0`
- VirtIO block device for optional persistent data disks
- VirtIO network device for VM uplink
- VirtIO-FS for host directory sharing
- VirtIO-vsock for host/guest control channels
- loop-backed sparse raw images
- ext4 and optional f2fs backing stores
- OverlayFS for volatile/container layering modes
- namespaces, cgroups, devpts, seccomp, and capabilities
- veth/bridge/TUN/netfilter for Droidspaces NAT and gateway-container topologies

## Non-goals

- general desktop distro support
- GPU/audio/USB device passthrough
- Wi-Fi/Bluetooth/device-driver coverage
- maintaining a permanent Linux fork

## Kernel artifact contract

The build output deliberately presents the same app-facing artifact layout for
both supported architectures:

```text
dist/<arch>/kernel
dist/<arch>/kernel-info.plist
dist/<arch>/config
dist/<arch>/System.map
```

The native Linux build target is architecture-specific (`Image` on arm64,
`bzImage` on x86_64), but the macOS application should treat `kernel` as the
only file that is passed to `VZLinuxBootLoader`. The native file is also copied
next to it for debugging and human inspection, but it is not the app contract.

`kernel` must not be wrapped in an external compression format such as gzip.
For arm64 this means using the uncompressed `Image` target. For x86_64 this
means using the Linux boot-protocol `bzImage` target as produced by kbuild; it
is self-extracting according to the x86 Linux boot protocol and should not be
renamed to `.gz` or manually unpacked into `vmlinux` for the VZ boot path.
