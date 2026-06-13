################################################################################
#
# zebrafish-config
#
################################################################################

ZEBRAFISH_CONFIG_VERSION = master
ZEBRAFISH_CONFIG_SITE = $(BR2_EXTERNAL_ZEBRAFISH_PATH)/package/zebrafish-config
ZEBRAFISH_CONFIG_SITE_METHOD = local
ZEBRAFISH_CONFIG_LICENSE = MIT

define ZEBRAFISH_CONFIG_STRIP_BINARY
	$(TARGET_STRIP) $(TARGET_DIR)/usr/bin/zebrafish-config
endef

ZEBRAFISH_CONFIG_POST_INSTALL_TARGET_HOOKS += ZEBRAFISH_CONFIG_STRIP_BINARY

$(eval $(cargo-package))
