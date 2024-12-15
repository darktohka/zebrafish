################################################################################
#
# libnl
#
################################################################################

LIBNL_VERSION = main
LIBNL_SITE = $(call github,thom311,libnl,main)
LIBNL_AUTORECONF = YES

LIBNL_INSTALL_STAGING = YES
LIBNL_DEPENDENCIES = host-bison host-flex host-pkgconf

ifeq ($(BR2_PACKAGE_LIBNL_TOOLS),y)
LIBNL_CONF_OPTS += --enable-cli
else
LIBNL_CONF_OPTS += --disable-cli
endif

LIBNL_CONF_OPTS += --disable-unit-tests

$(eval $(autotools-package))
$(eval $(host-autotools-package))
