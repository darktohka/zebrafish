################################################################################
#
# mainlinecrun
#
################################################################################

MAINLINECRUN_VERSION = origin/main
MAINLINECRUN_SITE = https://github.com/containers/crun
MAINLINECRUN_SITE_METHOD = git
MAINLINECRUN_GIT_SUBMODULES = YES

MAINLINECRUN_LICENSE = GPL-2.0+ (crun binary), LGPL-2.1+ (libcrun)
MAINLINECRUN_LICENSE_FILES = COPYING COPYING.libcrun

MAINLINECRUN_AUTORECONF = YES
MAINLINECRUN_CONF_OPTS = --disable-embedded-yajl

ifeq ($(BR2_PACKAGE_ARGP_STANDALONE),y)
MAINLINECRUN_DEPENDENCIES += argp-standalone
endif

ifeq ($(BR2_PACKAGE_LIBCAP),y)
MAINLINECRUN_DEPENDENCIES += libcap
MAINLINECRUN_CONF_OPTS += --enable-caps
else
MAINLINECRUN_CONF_OPTS += --disable-caps
endif

ifeq ($(BR2_PACKAGE_LIBGCRYPT),y)
MAINLINECRUN_DEPENDENCIES += libgcrypt
endif

ifeq ($(BR2_PACKAGE_LIBSECCOMP),y)
MAINLINECRUN_DEPENDENCIES += libseccomp
MAINLINECRUN_CONF_OPTS += --enable-seccomp
else
MAINLINECRUN_CONF_OPTS += --disable-seccomp
endif

ifeq ($(BR2_PACKAGE_SYSTEMD),y)
MAINLINECRUN_CONF_OPTS += --enable-systemd
MAINLINECRUN_DEPENDENCIES += systemd host-pkgconf
else
MAINLINECRUN_CONF_OPTS += --disable-systemd
endif

ifeq ($(BR2_PACKAGE_RUNC),)
define MAINLINECRUN_CREATE_SYMLINK
	ln -sf crun $(TARGET_DIR)/usr/bin/runc
endef
MAINLINECRUN_POST_INSTALL_TARGET_HOOKS += MAINLINECRUN_CREATE_SYMLINK
endif

define MAINLINECRUN_ADD_VERSION
	echo "main" > $(@D)/.tarball-version
	echo -e "#ifndef GIT_VERSION\n#define GIT_VERSION \"unknown\"\n#endif" > $(@D)/.tarball-git-version.h
endef
MAINLINECRUN_PRE_CONFIGURE_HOOKS += MAINLINECRUN_ADD_VERSION

$(eval $(autotools-package))
