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
