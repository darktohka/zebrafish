################################################################################
#
# ngtcp2
#
################################################################################

NGTCP2_VERSION = main
NGTCP2_SITE = $(call github,ngtcp2,ngtcp2,main)
NGTCP2_INSTALL_STAGING = YES
NGTCP2_CONF_OPTS = -DENABLE_STATIC_LIB=OFF -DENABLE_SHARED_LIB=ON -DBUILD_TESTING=OFF

ifeq ($(BR2_PACKAGE_WOLFSSL),y)
NGTCP2_DEPENDENCIES += wolfssl
NGTCP2_CONF_OPTS += -DENABLE_WOLFSSL=ON -DENABLE_OPENSSL=OFF
else ifeq ($(BR2_PACKAGE_OPENSSL),y)
NGTCP2_DEPENDENCIES += openssl
NGTCP2_CONF_OPTS += -DENABLE_OPENSSL=ON -DENABLE_WOLFSSL=OFF
else
NGTCP2_CONF_OPTS += -DENABLE_WOLFSSL=OFF -DENABLE_OPENSSL=OFF
endif

define NGTCP2_REMOVE_EXAMPLES
	rm -rf $(@D)/fuzz
	rm -rf $(@D)/examples
	mkdir -p $(@D)/examples
	touch $(@D)/examples/CMakeLists.txt
	rm -rf $(@D)/tests
	mkdir -p $(@D)/tests
	touch $(@D)/tests/CMakeLists.txt
endef

NGTCP2_PRE_CONFIGURE_HOOKS += NGTCP2_REMOVE_EXAMPLES


$(eval $(cmake-package))