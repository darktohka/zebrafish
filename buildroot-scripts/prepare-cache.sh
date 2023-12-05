#!/bin/bash

BR="$1"

if ! [[ -d "$BR" ]]; then
  echo "Buildroot folder does not exist."
  exit 1
fi

OUTPUT="$BR"/output
BUILD="$OUTPUT"/build

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
fi
