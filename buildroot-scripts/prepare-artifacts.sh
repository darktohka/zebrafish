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

if [[ -f "$IMAGES"/initrd-docker ]]; then
  ROOTFS_DOCKER="$IMAGES"/initrd-docker
else
  echo "No rootfs found."
  exit 1
fi

if [[ -f "$IMAGES"/initrd-containerd ]]; then
  ROOTFS_CONTAINERD="$IMAGES"/initrd-containerd
else
  echo "No rootfs for containerd found."
  exit 1
fi

cp "$IMAGE" "$ARTIFACTS"/zebrafish-kernel
KERNEL_SHA3=$(sha3sum "$ARTIFACTS"/zebrafish-kernel | cut -d ' ' -f1)

cp "$ROOTFS_DOCKER" "$ARTIFACTS"/zebrafish-initrd
INITRD_DOCKER_SHA3=$(sha3sum "$ARTIFACTS"/zebrafish-initrd | cut -d ' ' -f1)
tar -cf "$UPLOAD"/zebrafish-"$ARCH"-docker.tar -C "$ARTIFACTS" zebrafish-kernel zebrafish-initrd
jq --arg kernel "$KERNEL_SHA3" --arg initrd "$INITRD_DOCKER_SHA3" -n '{"hashes": {"sha3": {"zebrafish-kernel": $kernel, "zebrafish-initrd": $initrd}}}' > "$UPLOAD"/zebrafish-"$ARCH"-docker.json

cp "$ROOTFS_CONTAINERD" "$ARTIFACTS"/zebrafish-initrd
INITRD_CONTAINERD_SHA3=$(sha3sum "$ARTIFACTS"/zebrafish-initrd | cut -d ' ' -f1)
tar -cf "$UPLOAD"/zebrafish-"$ARCH"-containerd.tar -C "$ARTIFACTS" zebrafish-kernel zebrafish-initrd
jq --arg kernel "$KERNEL_SHA3" --arg initrd "$INITRD_CONTAINERD_SHA3" -n '{"hashes": {"sha3": {"zebrafish-kernel": $kernel, "zebrafish-initrd": $initrd}}}' > "$UPLOAD"/zebrafish-"$ARCH"-containerd.json
