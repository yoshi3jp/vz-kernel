ARCH ?= arm64
KERNEL_REF ?= linux-6.12.y

.PHONY: build package test-initramfs qemu-smoke clean

build:
	KERNEL_REF=$(KERNEL_REF) ./scripts/build-kernel.sh $(ARCH)

test-initramfs:
	./scripts/make-test-initramfs.sh

qemu-smoke: test-initramfs
	./scripts/qemu-smoke.sh $(ARCH)

clean:
	rm -rf build dist .kernel-src test-initramfs.cpio.gz
