#!/bin/bash

#
#  Post-fakeroot scripts are shell scripts that are called
#  at the end of the fakeroot phase, right before the
#  filesystem image generator is called.
#  As such, they are called in the fakeroot context.
#
#  Post-fakeroot scripts can be useful in case you need
#  to tweak the filesystem to do modifications that are
#  usually only available to the root user.
#
#  https://buildroot.org/downloads/manual/manual.html#rootfs-custom
#

echo "###############  Hello, I'm post-fakeroot.sh; $0"

. "$BR2_EXTERNAL"/zebrafish-version.env

# Source and determine raw data.
build_date=$(date -u +"%FT%TZ")

headless=""
[ -z "$ZEBRAFISH_HEADLESS" ] || headless="(hidden)"

# Using ':' as separator character when replacing in branch because '/' may be used in e.g. "dev/1.2.3".
cat << EOF > "$BINARIES_DIR"/zebrafish-release
ZEBRAFISH_NAME="$ZEBRAFISH_NAME"
ZEBRAFISH_VERSION="$ZEBRAFISH_VERSION"
ZEBRAFISH_VERSION_TAG="$ZEBRAFISH_VERSION_TAG"
ZEBRAFISH_HEADLESS="$headless"
ZEBRAFISH_BUILD_DATE="$build_date"
EOF
ls -l "$BINARIES_DIR"/zebrafish-release



# Add Zebrafish version to SYSLINUX splash screen.
[ -z "$ZEBRAFISH_VERSION_TAG" ] || _ZEBRAFISH_VERSION_TAG="-$ZEBRAFISH_VERSION_TAG"

#cat "$BINARIES_DIR"/zebrafish-release >> "$BINARIES_DIR"/syslinux-help-version.txt
#actual_lines=$(cat "$BINARIES_DIR"/syslinux-help-version.txt | wc -l)
#expected_lines=26 # 25+1 to push the top horizontal line out of the screen.
#missing_lines=$((expected_lines - actual_lines - 1))
#for n in $(seq $missing_lines); do
#    echo >> "$BINARIES_DIR"/syslinux-help-version.txt
#done



# Create a new os-release.
cat << EOF > "$TARGET_DIR"/usr/lib/os-release
NAME=$ZEBRAFISH_NAME
VERSION=$ZEBRAFISH_VERSION
PRETTY_NAME="$ZEBRAFISH_NAME $ZEBRAFISH_VERSION$_ZEBRAFISH_VERSION_TAG"
ID=zebrafish
ID_LIKE=buildroot

EOF
cp -v "$BINARIES_DIR"/zebrafish-release "$TARGET_DIR"/etc/zebrafish-release

cp "$BASE_DIR"/host/*-buildroot-*/lib64/* "$TARGET_DIR"/lib64/

if ! [[ -f "$TARGET_DIR"/qemu-arm ]]; then
    echo "Downloading QEMU binaries..."

    if [[ "$STAGING_DIR" = *aarch64* ]]; then
        platform="arm64"
        binaries="qemu-x86_64 qemu-arm"
    else
        platform="amd64"
        binaries="qemu-arm64 qemu-arm"
    fi

    image="tonistiigi/binfmt:master"
    directory="$(mktemp -d)"

    sudo skopeo copy --override-arch "$platform" docker://tonistiigi/binfmt:master dir:"$directory" --dest-decompress

    tar_archives=$(file -F ' ' "$directory"/* | grep "tar archive" | cut -d ' ' -f 1)

    for tar_archive in $tar_archives; do
        tar -C "$directory" -xf "$tar_archive"
    done

    for binary in $binaries; do
        SOURCE_FILE="$directory"/usr/bin/"$binary"
        TARGET_FILE="$TARGET_DIR"/usr/bin/"$binary"
        cp "$SOURCE_FILE" "$TARGET_FILE"
        llvm-strip "$TARGET_FILE" || strip "$TARGET_FILE"
        chmod +x "$TARGET_FILE"
    done

    rm -rf "$directory"
fi

$(dirname $0)/post-fakeroot-cleanup.sh
$(dirname $0)/post-fakeroot-headless.sh
