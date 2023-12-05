#!/bin/bash

BR="$1"
ARTIFACTS="$2"
ARCH="$3"

if ! [[ -d "$BR" ]]; then
  echo "Buildroot folder does not exist."
  exit 1
fi

if [[ -d "$ARTIFACTS" ]]; then
  rm -rf "$ARTIFACTS"
fi

mkdir -p "$ARTIFACTS"

OUTPUT="$BR"/output
IMAGES="$OUTPUT"/images

if ! [[ -d "$IMAGES" ]]; then
  echo "Images folder does not exist."
  exit 1
fi

if [[ -f "$IMAGES"/Image ]]; then
  IMAGE="$IMAGES"/Image
elif [[ -f "$image_dir"/bzImage ]]; then
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

cp "$IMAGE" "$TEMPDIR"/zebrafish-kernel
cp "$ROOTFS" "$ARTIFACTS"/zebrafish-initrd

tar -cf "$ARTIFACTS"/zebrafish-"$ARCH".tar -C "$ARTIFACTS" zebrafish-kernel zebrafish-initrd
