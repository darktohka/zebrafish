#!/bin/bash
set -e

BR="$1"
ZF="$2"

if ! [[ -d "$BR" ]]; then
  echo "Buildroot folder does not exist."
  exit 1
fi

if ! [[ -d "$ZF" ]]; then
  echo "Zebrafish folder does not exist."
  exit 1
fi

cd "$BR"
make BR2_EXTERNAL="$ZF"
