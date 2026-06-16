# Architecture

Project 1 produces the kernel side of the Droidspaces macOS appliance.

```text
macOS
 └── Apple Virtualization.framework
      └── Linux kernel from this repository
           └── Droidspaces initramfs / userspace, supplied by another project
```

This repository is concerned only with the kernel.

## Kernel contract

The kernel must support:

- direct Linux boot with initramfs
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
