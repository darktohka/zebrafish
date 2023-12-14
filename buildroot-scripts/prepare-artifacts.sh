#!/bin/bash
set -e

BR="$1"
ARTIFACTS="$2"
UPLOAD="$ARTIFACTS/upload"
ARCH="$3"

if ! [[ -d "$BR" ]]; then
  echo "Buildroot folder does not exist."
  exit 1
fi

if ! [[ -d "$UPLOAD" ]]; then
  mkdir -p "$UPLOAD"
fi

OUTPUT="$BR"/output
IMAGES="$OUTPUT"/images

if ! [[ -d "$IMAGES" ]]; then
  echo "Images folder does not exist."
  exit 1
fi

if [[ -f "$IMAGES"/Image ]]; then
  IMAGE="$IMAGES"/Image
elif [[ -f "$IMAGES"/bzImage ]]; then
  IMAGE="$IMAGES"/bzImage
else
  echo "No image found."
  exit 1
fi

if [[ -f "$IMAGES"/rootfs.cpio.zst ]]; then
  ROOTFS="$IMAGES"/rootfs.cpio.zst
elif [[ -f "$IMAGES"/rootfs.cpio ]]; then
  ROOTFS="$IMAGES"/rootfs.cpio
else
  echo "No rootfs found."
  exit 1
fi

cp "$IMAGE" "$ARTIFACTS"/zebrafish-kernel
cp "$ROOTFS" "$ARTIFACTS"/zebrafish-initrd

KERNEL_SHA3=$(sha3sum "$ARTIFACTS"/zebrafish-kernel | cut -d ' ' -f1)
INITRD_SHA3=$(sha3sum "$ARTIFACTS"/zebrafish-initrd | cut -d ' ' -f1)

jq --arg kernel "$KERNEL_SHA3" --arg initrd "$INITRD_SHA3" -n '{"hashes": {"sha3": {"zebrafish-kernel": $kernel, "zebrafish-initrd": $initrd}}}' > "$UPLOAD"/zebrafish-"$ARCH".json
tar -cf "$UPLOAD"/zebrafish-"$ARCH".tar -C "$ARTIFACTS" zebrafish-kernel zebrafish-initrd
