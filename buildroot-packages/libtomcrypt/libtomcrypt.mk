################################################################################
#
# libtomcrypt
#
################################################################################

LIBTOMCRYPT_VERSION = master
LIBTOMCRYPT_SITE = $(call github,libtom,libtomcrypt,develop)
LIBTOMCRYPT_LICENSE = WTFPL
LIBTOMCRYPT_LICENSE_FILES = LICENSE
LIBTOMCRYPT_INSTALL_STAGING = YES
LIBTOMCRYPT_INSTALL_TARGET = NO # only static library
LIBTOMCRYPT_DEPENDENCIES = libtommath

LIBTOMCRYPT_CFLAGS = -I./src/headers $(TARGET_CFLAGS) -DLTC_SOURCE -DLTM_DESC

ifeq ($(BR2_STATIC_LIBS),)
LIBTOMCRYPT_CFLAGS += -fPIC
endif

define LIBTOMCRYPT_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f makefile.unix $(TARGET_CONFIGURE_OPTS) CFLAGS="$(LIBTOMCRYPT_CFLAGS)"
endef

define LIBTOMCRYPT_INSTALL_STAGING_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f makefile.unix \
		DESTDIR="$(STAGING_DIR)" PREFIX=/usr install
endef

$(eval $(generic-package))
