################################################################################
#
# containerd
#
################################################################################

CONTAINERD_VERSION = 1.7
CONTAINERD_SITE = $(call github,containerd,containerd,release/1.7)
CONTAINERD_LICENSE = Apache-2.0
CONTAINERD_LICENSE_FILES = LICENSE

CONTAINERD_GOMOD = github.com/containerd/containerd

CONTAINERD_BUILD_TARGETS = \
	cmd/containerd \
	cmd/containerd-shim-runc-v2

CONTAINERD_INSTALL_BINS = containerd containerd-shim-runc-v2
CONTAINERD_TAGS = no_aufs

ifeq ($(BR2_PACKAGE_LIBAPPARMOR),y)
CONTAINERD_DEPENDENCIES += libapparmor
CONTAINERD_TAGS += apparmor
endif

ifeq ($(BR2_PACKAGE_LIBSECCOMP),y)
CONTAINERD_DEPENDENCIES += libseccomp host-pkgconf
CONTAINERD_TAGS += seccomp
endif

ifeq ($(BR2_PACKAGE_CONTAINERD_DRIVER_BTRFS),y)
CONTAINERD_DEPENDENCIES += btrfs-progs
else
CONTAINERD_TAGS += no_btrfs
endif

ifneq ($(BR2_PACKAGE_CONTAINERD_DRIVER_DEVMAPPER),y)
CONTAINERD_TAGS += no_devmapper
endif

ifneq ($(BR2_PACKAGE_CONTAINERD_CRI),y)
CONTAINERD_TAGS += no_cri
endif

define CONTAINERD_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/containerd.service \
		$(TARGET_DIR)/usr/lib/systemd/system/containerd.service
	$(SED) 's,/usr/local/bin,/usr/bin,g' $(TARGET_DIR)/usr/lib/systemd/system/containerd.service
endef

$(eval $(golang-package))
