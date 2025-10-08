#!/bin/bash
set -e
set -x
set -u

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

# Using ':' as separator character when replacing in branch because '/' may be used in e.g. "dev/1.2.3".
cat << EOF > "$BINARIES_DIR"/zebrafish-release
ZEBRAFISH_NAME="$ZEBRAFISH_NAME"
ZEBRAFISH_VERSION="$ZEBRAFISH_VERSION"
ZEBRAFISH_BUILD_DATE="$build_date"
EOF
ls -l "$BINARIES_DIR"/zebrafish-release

#cat "$BINARIES_DIR"/zebrafish-release >> "$BINARIES_DIR"/syslinux-help-version.txt
#actual_lines=$(cat "$BINARIES_DIR"/syslinux-help-version.txt | wc -l)
#expected_lines=26 # 25+1 to push the top horizontal line out of the screen.
#missing_lines=$((expected_lines - actual_lines - 1))
#for n in $(seq $missing_lines); do
#    echo >> "$BINARIES_DIR"/syslinux-help-version.txt
#done

cp "$BASE_DIR"/host/*-buildroot-*/lib64/* "$TARGET_DIR"/lib64/

api="application/vnd.docker.distribution.manifest.v2+json"
apil="application/vnd.docker.distribution.manifest.list.v2+json"
oci="application/vnd.oci.image.manifest.v1+json"

get_token() {
    local repo="$1"
    curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${repo}:pull" | jq -r '.token'
}

get_manifest_digests() {
    local token="$1"
    local repo="$2"
    local tag="$3"

    curl -H "Accept: ${api}" -H "Accept: ${apil}" \
     -H "Authorization: Bearer $token" \
     -s "https://registry-1.docker.io/v2/${repo}/manifests/${tag}"
}

extract_blobs() {
    local token="$1"
    local repo="$2"
    local manifest_digests="$3"
    local platform="$4"
    local target_folder="$5"
    set -x

    manifest_digest=$(echo "$manifest_digests" | jq --arg architecture "$platform" -r '.manifests[] | select(.platform.architecture == $architecture and .platform.variant != "v5") | .digest')
    blobs=$(curl -H "Accept: ${oci}" -H "Accept: ${api}" -H "Accept: ${apil}" \
     -H "Authorization: Bearer $token" \
     -s "https://registry-1.docker.io/v2/${repo}/manifests/${manifest_digest}" | jq -r '.layers[] | select(.mediaType != "application/vnd.docker.container.image.v1+json") | .digest')

    mkdir -p "$target_folder"

    for blob in $blobs; do
        curl -H "Authorization: Bearer $token" \
            -sL "https://registry-1.docker.io/v2/${repo}/blobs/${blob}" | tar -xz -C "$target_folder"
    done
}


if ! [[ -f "$TARGET_DIR"/usr/bin/qemu-x86_64 ]] && ! [[ -f "$TARGET_DIR"/usr/bin/qemu-aarch64 ]]; then
    echo "Downloading QEMU binaries..."

    if [[ "$STAGING_DIR" = *aarch64* ]]; then
        platform="arm64"
        binaries="qemu-x86_64"
    else
        platform="amd64"
        binaries="qemu-aarch64"
    fi

    qemu_image="tonistiigi/binfmt"
    qemu_directory="$(mktemp -d)"

    qemu_token=$(get_token "$qemu_image")
    qemu_digests=$(get_manifest_digests "$qemu_token" "$qemu_image" "latest")

    extract_blobs "$qemu_token" "$qemu_image" "$qemu_digests" "$platform" "$qemu_directory"

    for binary in $binaries; do
        SOURCE_FILE="$qemu_directory"/usr/bin/"$binary"
        TARGET_FILE="$TARGET_DIR"/usr/bin/"$binary"
        cp "$SOURCE_FILE" "$TARGET_FILE"
        llvm-strip "$TARGET_FILE" || strip "$TARGET_FILE" || echo "Failed to strip $TARGET_FILE"
        chmod +x "$TARGET_FILE"
    done

    rm -rf "$qemu_directory"
fi

$(dirname $0)/post-fakeroot-cleanup.sh

SCRATCH_DIR="$BASE_DIR"/scratch
mkdir -p "$SCRATCH_DIR"
mkdir -p "$SCRATCH_DIR"/folders

# Move the Docker specific files to the scratch directory.
mv "$TARGET_DIR"/usr/bin/docker "$SCRATCH_DIR"/
mv "$TARGET_DIR"/usr/bin/dockerd "$SCRATCH_DIR"/
mv "$TARGET_DIR"/etc/init.d/S62dockerd "$SCRATCH_DIR"/
mv "$TARGET_DIR"/usr/lib/docker "$SCRATCH_DIR"/folders/

# Create the Docker redirection.
cat << EOF > "$TARGET_DIR"/usr/bin/docker
#!/bin/sh
if [ "\$(id -u)" -ne 0 ]; then
    exec sudo /usr/bin/nerdctl "\$@"
else
    exec /usr/bin/nerdctl "\$@"
fi
EOF
chmod +x "$TARGET_DIR"/usr/bin/docker

# Create a new os-release.
cat << EOF > "$TARGET_DIR"/usr/lib/os-release
NAME=$ZEBRAFISH_NAME
VERSION=$ZEBRAFISH_VERSION
PRETTY_NAME="$ZEBRAFISH_NAME $ZEBRAFISH_VERSION"
ZEBRAFISH_VARIANT=containerd
ID=zebrafish
ID_LIKE=buildroot
EOF
cp -v "$BINARIES_DIR"/zebrafish-release "$TARGET_DIR"/etc/zebrafish-release

cd "$TARGET_DIR"

# change to -n on prod
if [[ -n "${CI:-}" ]]; then
    echo "Running in CI environment, compressing binaries..."
    find . \
        | LC_ALL=C sort \
        | cpio --reproducible --quiet -o -H newc \
        | zstd -T0 -19 \
        > "$BINARIES_DIR"/initrd-containerd
else
    echo "Not running in CI environment, skipping compression..."
    find . \
        | LC_ALL=C sort \
        | cpio --reproducible --quiet -o -H newc \
        > "$BINARIES_DIR"/initrd-containerd
fi

rm "$TARGET_DIR"/usr/bin/docker
mv "$SCRATCH_DIR"/docker "$TARGET_DIR"/usr/bin/
mv "$SCRATCH_DIR"/dockerd "$TARGET_DIR"/usr/bin/
mv "$SCRATCH_DIR"/S62dockerd "$TARGET_DIR"/etc/init.d/
mv "$SCRATCH_DIR"/folders/docker "$TARGET_DIR"/usr/lib/

mv "$TARGET_DIR"/usr/bin/buildkitd "$SCRATCH_DIR"/
mv "$TARGET_DIR"/usr/bin/nerdctl "$SCRATCH_DIR"/
mv "$TARGET_DIR"/etc/init.d/S60containerd "$SCRATCH_DIR"/
mv "$TARGET_DIR"/etc/init.d/S61buildkitd "$SCRATCH_DIR"/
mv "$TARGET_DIR"/usr/lib/cni "$SCRATCH_DIR"/folders/

# Create a new os-release.
cat << EOF > "$TARGET_DIR"/usr/lib/os-release
NAME=$ZEBRAFISH_NAME
VERSION=$ZEBRAFISH_VERSION
PRETTY_NAME="$ZEBRAFISH_NAME $ZEBRAFISH_VERSION"
ZEBRAFISH_VARIANT=docker
ID=zebrafish
ID_LIKE=buildroot
EOF
cp -v "$BINARIES_DIR"/zebrafish-release "$TARGET_DIR"/etc/zebrafish-release

cd "$TARGET_DIR"

# change to -n on prod
if [[ -n "${CI:-}" ]]; then
    echo "Running in CI environment, compressing binaries..."
    find . \
        | LC_ALL=C sort \
        | cpio --reproducible --quiet -o -H newc \
        | zstd -T0 -19 \
        > "$BINARIES_DIR"/initrd-docker
else
    echo "Not running in CI environment, skipping compression..."
    find . \
        | LC_ALL=C sort \
        | cpio --reproducible --quiet -o -H newc \
        > "$BINARIES_DIR"/initrd-docker
fi

mv "$SCRATCH_DIR"/buildkitd "$TARGET_DIR"/usr/bin/
mv "$SCRATCH_DIR"/nerdctl "$TARGET_DIR"/usr/bin/
mv "$SCRATCH_DIR"/S60containerd "$TARGET_DIR"/etc/init.d/
mv "$SCRATCH_DIR"/S61buildkitd "$TARGET_DIR"/etc/init.d/
mv "$SCRATCH_DIR"/folders/cni "$TARGET_DIR"/usr/lib/
rmdir "$SCRATCH_DIR"/folders
rmdir "$SCRATCH_DIR"