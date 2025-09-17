#!/usr/bin/env bash
set -euo pipefail

# Create a 2GB image
dd if=/dev/zero of=rootfs.img bs=1M count=2048

# Make ext4 filesystem
mkfs.ext4 rootfs.img

# Mount and copy rootfs
sudo mkdir -p /mnt/rootfs
sudo mount -o loop rootfs.img /mnt/rootfs
sudo cp -a ../rootfs/. /mnt/rootfs/
sudo umount /mnt/rootfs

# Boot with QEMU
qemu-system-x86_64 \
  -kernel ../../kernel/arch/x86_64/boot/bzImage \
  -append "root=/dev/sda rw console=ttyS0 init=/init" \
  -hda rootfs.img \
  -nographic