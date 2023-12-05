#!/bin/sh

echo "###############  Hello, I'm post-image.sh; $0"

set -e

BOARD_DIR=$(dirname "$0")



# Build SYSLINUX SQUASHFS BIOS ISO.
#echo "Building bootable SYSLINUX SQUASHFS EFI IMAGE ..."
#"$BOARD_DIR/syslinux/build-syslinux-squashfs-efi-image.sh"


# Build SYSLINUX INITRAMFS EFI ISO.
#echo "Building bootable SYSLINUX INITRAMFS EFI IMAGE ..."
#"$BOARD_DIR/syslinux/build-syslinux-initramfs-efi-image.sh"


# Build SYSLINUX INITRAMFS DUAL BIOS/EFI ISO.
#echo "Building bootable SYSLINUX INITRAMFS DUAL BIOS/EFI ISO ..."
#"$BOARD_DIR/syslinux/build-syslinux-initramfs-dual-iso.sh"

#ls -lh $BINARIES_DIR/zebrafish-*.iso $BINARIES_DIR/zebrafish-*.img || true

echo "Ok; $0"
