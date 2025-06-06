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

BR_PACKAGES="$ZF/buildroot-packages"

# Reset Buildroot
cd "$BR"
git reset --hard
git checkout

# Patch Linux
#patch -sf --no-backup-if-mismatch "$BR/linux/linux.mk" "$ZF/buildroot-patches/0001-add-zfs-to-linux.patch"
ZFS_SCRIPT='define LINUX_IMPORT_ZFS
  cd $(LINUX_DIR) && make $(LINUX_MAKE_FLAGS) olddefconfig && make $(LINUX_MAKE_FLAGS) prepare && \
  curl -sL https://github.com/openzfs/zfs/archive/refs/heads/master.tar.gz | tar -xz && cd zfs-master && $(AUTORECONF) && rm -rf config.cache && \
  $(TARGET_CONFIGURE_OPTS) \
  $(TARGET_CONFIGURE_ARGS) \
  $(LINUX_MAKE_FLAGS) ./configure \
    --host=$(GNU_TARGET_NAME) \
    --build=$(GNU_HOST_NAME) --enable-linux-builtin=yes --with-linux=$(LINUX_DIR) --with-linux-obj=$(LINUX_DIR) && ./copy-builtin $(LINUX_DIR) && cp $(BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE) .config
endef
LINUX_POST_EXTRACT_HOOKS += LINUX_IMPORT_ZFS'

echo "$ZFS_SCRIPT
$(cat "$BR/linux/linux.mk")" > "$BR/linux/linux.mk"

# Replace buildroot packages
if [[ -d "$BR_PACKAGES" ]]; then
  for package in $(find "$BR_PACKAGES" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'); do
    rm -rf "$BR/package/$package"
    ln -s $(realpath "$BR_PACKAGES/$package") "$BR/package/$package"
  done
fi

# Allow Cargo.lock to be updated
for file in package/pkg-cargo.mk support/download/cargo-post-process; do
  sed -Ei 's/--offline//;s/--locked//' "$BR"/"$file"
done

# Build the latest version of Go
LATEST_GO_VERSION=$(curl -SsL https://raw.githubusercontent.com/actions/go-versions/refs/heads/main/versions-manifest.json | jq -r .[0].version)
echo "Building with Go version $LATEST_GO_VERSION"
sed -Ei "s/^GO_VERSION\s+=.*/GO_VERSION = $LATEST_GO_VERSION/" package/go/go.mk
rm -f package/go/go-bin/go-bin.hash
rm -f package/go/go-src/go-src.hash

# Prevent kernel headers from being checked
echo "exit 0" > support/scripts/check-kernel-headers.sh
