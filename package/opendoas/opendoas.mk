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

define OPENDOAS_ADD_DOAS_CONF
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_ZEBRAFISH_PATH)/package/opendoas/doas.conf $(TARGET_DIR)/etc/doas.conf \
	&& rm -f $(TARGET_DIR)/usr/bin/sudo || true \
	&& ln -s /usr/bin/doas $(TARGET_DIR)/usr/bin/sudo
endef

OPENDOAS_POST_INSTALL_TARGET_HOOKS += OPENDOAS_ADD_DOAS_CONF

$(eval $(autotools-package))
