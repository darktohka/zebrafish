################################################################################
#
# sudo
#
################################################################################

OPENDOAS_VERSION = origin/master
OPENDOAS_SITE = https://github.com/darktohka/opendoas
OPENDOAS_SITE_METHOD = git
OPENDOAS_LICENSE = MIT
OPENDOAS_LICENSE_FILES = LICENSE

OPENDOAS_MAKE_OPTS = \
	CC=$(TARGET_CC) \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \

define OPENDOAS_USERS
	- - sudo -1 - - - -
endef

define OPENDOAS_ADD_SUDO
	rm -f $(TARGET_DIR)/usr/bin/sudo || true \
	&& ln -s /usr/bin/doas $(TARGET_DIR)/usr/bin/sudo
endef

OPENDOAS_POST_INSTALL_TARGET_HOOKS += OPENDOAS_ADD_SUDO

$(eval $(autotools-package))
