#!/bin/bash
set -e

BR="$1"

if ! [[ -d "$BR" ]]; then
  echo "Buildroot folder does not exist."
  exit 1
fi

OUTPUT="$BR"/output
DL="$BR"/dl
BUILD="$OUTPUT"/build

# Remove download folder
if [[ -d "$DL" ]]; then
  rm -rf "$DL"
  mkdir -p "$DL"
fi

# Remove folders that should be redownloaded from latest branch
if [[ -d "$BUILD" ]]; then
  cd "$BUILD"
  rm -rf *main* *master* *linux*
fi

# Remove folders that should be regenerated
if [[ -d "$OUTPUT" ]]; then
  cd "$OUTPUT"
  rm -rf target images
  mkdir -p target images

  # Remove staging dir
  STAGING_DIR=$(readlink -f staging)
  rm -rf "$STAGING_DIR"
  mkdir -p "$STAGING_DIR"
fi

# Remove all stamps for installing images, initramfs, target and staging
rm -f $(find . -name ".stamp_images_installed" -or -name ".stamp_initramfs_rebuilt" -or -name ".stamp_target_installed" -or -name ".stamp_staging_installed")
