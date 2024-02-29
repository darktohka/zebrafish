################################################################################
#
# libtommath
#
################################################################################

LIBTOMMATH_VERSION = master
LIBTOMMATH_SITE = $(call github,libtom,libtommath,develop)
LIBTOMMATH_LICENSE = Unlicense
LIBTOMMATH_LICENSE_FILES = LICENSE
LIBTOMMATH_CPE_ID_VENDOR = libtom
LIBTOMMATH_INSTALL_STAGING = YES
LIBTOMMATH_INSTALL_TARGET = NO  # only static library

define LIBTOMMATH_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS) CFLAGS="-I./ -fPIC $(TARGET_CFLAGS)"
endef

define LIBTOMMATH_INSTALL_STAGING_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) DESTDIR="$(STAGING_DIR)" PREFIX=/usr install
endef

$(eval $(generic-package))
