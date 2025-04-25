################################################################################
#
# zfs
#
################################################################################

USERLANDZFS_VERSION = origin/master
USERLANDZFS_SITE = https://github.com/openzfs/zfs
USERLANDZFS_SITE_METHOD = git
USERLANDZFS_LICENSE = CDDL
USERLANDZFS_LICENSE_FILES = LICENSE COPYRIGHT
USERLANDZFS_CPE_ID_VENDOR = openzfs
USERLANDZFS_CPE_ID_PRODUCT = openzfs

# 0001-removal-of-LegacyVersion-broke-ax_python_dev.m4.patch
USERLANDZFS_AUTORECONF = YES

USERLANDZFS_DEPENDENCIES = libaio openssl udev util-linux zlib libcurl linux

# sysvinit installs only a commented-out modules-load.d/ config file
USERLANDZFS_CONF_OPTS = \
	--with-linux=$(LINUX_DIR) \
	--with-linux-obj=$(LINUX_DIR) \
	--disable-rpath \
	--disable-sysvinit \
	--enable-linux-builtin=yes

# remove tests
define USERLANDZFS_REMOVE_TESTS_SAVE
        rm -rf $(@D)/tests && mkdir -p $(@D)/tests/zfs-tests/tests && \
        find $(@D)/tests -type f -name 'Makefile.am' -exec truncate -s0 {} \;
truncate -s0 $(@D)/tests/Makefile.am && truncate -s0 $(@D)/tests/zfs-tests/Makefile.am && \
        truncate -s0 $(@D)/tests/zfs-tests/Makefile.am && truncate -s0 $(@D)/tests/zfs-tests/tests/Makefile.am
endef

USERLANDZFS_CONF_ENV += \
	HOSTCC="$(HOSTCC) $(subst -I/,-isystem /,$(subst -I /,-isystem /,$(HOST_CFLAGS))) $(HOST_LDFLAGS)" \
	ARCH=$(KERNEL_ARCH) \
	INSTALL_MOD_PATH=$(TARGET_DIR) \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	WERROR=0 \
	REGENERATE_PARSERS=1 \
	DEPMOD=$(HOST_DIR)/sbin/depmod

USERLANDZFS_PRE_CONFIGURE_HOOKS += USERLANDZFS_REMOVE_TESTS_SAVE

define USERLANDZFS_REMOVE_SRC_SAVE
	$(RM) -rf $(TARGET_DIR)/usr/src/zfs*
endef

USERLANDZFS_POST_INSTALL_HOOKS += USERLANDZFS_REMOVE_SRC_SAVE

ifeq ($(BR2_PACKAGE_LIBTIRPC),y)
USERLANDZFS_DEPENDENCIES += libtirpc
USERLANDZFS_CONF_OPTS += --with-tirpc
else
USERLANDZFS_CONF_OPTS += --without-tirpc
endif

ifeq ($(BR2_INIT_SYSTEMD),y)
# Installs the optional systemd generators, units, and presets files.
USERLANDZFS_CONF_OPTS += --enable-systemd
else
USERLANDZFS_CONF_OPTS += --disable-systemd
endif

ifeq ($(BR2_PACKAGE_PYTHON3),y)
USERLANDZFS_DEPENDENCIES += python3 python-setuptools host-python-cffi host-python-packaging
USERLANDZFS_CONF_ENV += \
	PYTHON=$(HOST_DIR)/bin/python3 \
	PYTHON_CPPFLAGS="`$(STAGING_DIR)/usr/bin/python3-config --includes`" \
	PYTHON_LIBS="`$(STAGING_DIR)/usr/bin/python3-config --ldflags`" \
	PYTHON_EXTRA_LIBS="`$(STAGING_DIR)/usr/bin/python3-config --libs --embed`" \
	PYTHON_SITE_PKG="/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages"
USERLANDZFS_CONF_OPTS += --enable-pyzfs
else
USERLANDZFS_CONF_OPTS += --disable-pyzfs --without-python
endif

ifeq ($(BR2_PACKAGE_LINUX_PAM),y)
USERLANDZFS_DEPENDENCIES += linux-pam
USERLANDZFS_CONF_OPTS += --enable-pam
else
USERLANDZFS_CONF_OPTS += --disable-pam
endif

# ZFS userland tools are unfunctional without the Linux kernel modules.
USERLANDZFS_MODULE_SUBDIRS = \
	module/avl \
	module/icp \
	module/lua \
	module/nvpair \
	module/spl \
	module/unicode \
	module/zcommon \
	module/zstd \
	module/zfs

# These requirements will be validated by zfs/config/kernel-config-defined.m4
define USERLANDZFS_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_DISABLE_OPT,CONFIG_DEBUG_LOCK_ALLOC)
	$(call KCONFIG_DISABLE_OPT,CONFIG_TRIM_UNUSED_KSYMS)
	$(call KCONFIG_ENABLE_OPT,CONFIG_CRYPTO_DEFLATE)
	$(call KCONFIG_ENABLE_OPT,CONFIG_ZLIB_DEFLATE)
	$(call KCONFIG_ENABLE_OPT,CONFIG_ZLIB_INFLATE)
endef

# Even though zfs builds a kernel module, it gets built directly by
# the autotools logic, so we don't use the kernel-module
# infrastructure.
$(eval $(autotools-package))
