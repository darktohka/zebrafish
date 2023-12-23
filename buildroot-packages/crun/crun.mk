################################################################################
#
# crun
#
################################################################################

CRUN_VERSION = origin/main
CRUN_SITE = https://github.com/containers/crun
CRUN_SITE_METHOD = git
CRUN_GIT_SUBMODULES = YES

CRUN_LICENSE = GPL-2.0+ (crun binary), LGPL-2.1+ (libcrun)
CRUN_LICENSE_FILES = COPYING COPYING.libcrun

CRUN_AUTORECONF = YES
CRUN_CONF_OPTS = --disable-embedded-yajl

ifeq ($(BR2_PACKAGE_ARGP_STANDALONE),y)
CRUN_DEPENDENCIES += argp-standalone
endif

ifeq ($(BR2_PACKAGE_LIBCAP),y)
CRUN_DEPENDENCIES += libcap
CRUN_CONF_OPTS += --enable-caps
else
CRUN_CONF_OPTS += --disable-caps
endif

ifeq ($(BR2_PACKAGE_LIBGCRYPT),y)
CRUN_DEPENDENCIES += libgcrypt
endif

ifeq ($(BR2_PACKAGE_LIBSECCOMP),y)
CRUN_DEPENDENCIES += libseccomp
CRUN_CONF_OPTS += --enable-seccomp
else
CRUN_CONF_OPTS += --disable-seccomp
endif

ifeq ($(BR2_PACKAGE_SYSTEMD),y)
CRUN_CONF_OPTS += --enable-systemd
CRUN_DEPENDENCIES += systemd host-pkgconf
else
CRUN_CONF_OPTS += --disable-systemd
endif

ifeq ($(BR2_PACKAGE_RUNC),)
define CRUN_CREATE_SYMLINK
	ln -sf crun $(TARGET_DIR)/usr/bin/runc
endef
CRUN_POST_INSTALL_TARGET_HOOKS += CRUN_CREATE_SYMLINK
endif

define CRUN_ADD_VERSION
	echo "main" > $(@D)/.tarball-version
	echo -e "#ifndef GIT_VERSION\n#define GIT_VERSION \"unknown\"\n#endif" > $(@D)/.tarball-git-version.h
endef
CRUN_PRE_CONFIGURE_HOOKS += CRUN_ADD_VERSION

$(eval $(autotools-package))
