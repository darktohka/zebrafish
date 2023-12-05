#!/bin/bash

BR="$1"
ZF="$2"
TYPE="$3"

if ! [[ -d "$BR" ]]; then
  echo "Buildroot folder does not exist."
  exit 1
fi

if ! [[ -d "$ZF" ]]; then
  echo "Zebrafish folder does not exist."
  exit 1
fi

OUTPUT="$BR"/output
LX="$OUTPUT"/build/linux-custom

if [[ "$TYPE" = "x64" ]]; then
  defconfig="zebrafish_x64_defconfig"
  linuxconfig="linux_x64.config"
elif [[ "$TYPE" = "aarch64" ]]; then
  defconfig="zebrafish_aarch64_defconfig"
  linuxconfig="linux_aarch64.config"
else
  echo "Unknown type."
  exit 1
fi

# Create output folder
if ! [[ -d "$OUTPUT" ]]; then
    mkdir -p "$OUTPUT"
fi

# Copy new configuration
cp "$ZF"/configs/"$defconfig" "$BR"/.config
cp "$ZF"/configs/"$defconfig" "$BR"/output/.config

if [[ -d "$LX" ]]; then
  rm -f "$LX"/.config
  cp "$ZF"/board/pc/"$linuxconfig" "$OUTPUT"/build/linux-custom/.config
fi

cd "$BR"
make BR2_EXTERNAL="$ZF" olddefconfig