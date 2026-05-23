################################################################################
#
# powertop
#
################################################################################

POWERTOP_VERSION = origin/master
POWERTOP_SITE = $(call github,fenrus75,powertop,master)

POWERTOP_LICENSE = GPL-2.0
POWERTOP_LICENSE_FILES = COPYING

POWERTOP_DEPENDENCIES = \
	host-pkgconf \
	libnl \
	libtracefs \
	ncurses \
	$(if $(BR2_PACKAGE_PCIUTILS),pciutils) \
	$(TARGET_NLS_DEPENDENCIES)

POWERTOP_CONF_OPTS = \
	-Dnls=$(if $(BR2_SYSTEM_ENABLE_NLS),true,false) \
	-Denable-tests=false \
	-Dtest-framework=false

$(eval $(meson-package))
