################################################################################
#
# containerd
#
################################################################################

MAINLINECONTAINERD_VERSION = 1.7
MAINLINECONTAINERD_SITE = $(call github,containerd,containerd,release/1.7)
MAINLINECONTAINERD_LICENSE = Apache-2.0
MAINLINECONTAINERD_LICENSE_FILES = LICENSE

MAINLINECONTAINERD_GOMOD = github.com/containerd/containerd

MAINLINECONTAINERD_BUILD_TARGETS = \
	cmd/containerd \
	cmd/containerd-shim-runc-v2

MAINLINECONTAINERD_INSTALL_BINS = containerd containerd-shim-runc-v2
MAINLINECONTAINERD_TAGS = no_aufs

ifeq ($(BR2_PACKAGE_LIBAPPARMOR),y)
MAINLINECONTAINERD_DEPENDENCIES += libapparmor
MAINLINECONTAINERD_TAGS += apparmor
endif

ifeq ($(BR2_PACKAGE_LIBSECCOMP),y)
MAINLINECONTAINERD_DEPENDENCIES += libseccomp host-pkgconf
MAINLINECONTAINERD_TAGS += seccomp
endif

ifeq ($(BR2_PACKAGE_MAINLINECONTAINERD_DRIVER_BTRFS),y)
MAINLINECONTAINERD_DEPENDENCIES += btrfs-progs
else
MAINLINECONTAINERD_TAGS += no_btrfs
endif

ifneq ($(BR2_PACKAGE_MAINLINECONTAINERD_DRIVER_DEVMAPPER),y)
MAINLINECONTAINERD_TAGS += no_devmapper
endif

ifneq ($(BR2_PACKAGE_MAINLINECONTAINERD_CRI),y)
MAINLINECONTAINERD_TAGS += no_cri
endif

define MAINLINECONTAINERD_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/containerd.service \
		$(TARGET_DIR)/usr/lib/systemd/system/containerd.service
	$(SED) 's,/usr/local/bin,/usr/bin,g' $(TARGET_DIR)/usr/lib/systemd/system/containerd.service
endef

$(eval $(golang-package))
