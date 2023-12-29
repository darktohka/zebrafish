################################################################################
#
# meson
#
################################################################################

MESON_VERSION = master
MESON_SITE = $(call github,mesonbuild,meson,master)
MESON_SETUP_TYPE = setuptools

HOST_MESON_DEPENDENCIES = host-ninja

# Avoid interpreter shebang longer than 128 chars
define HOST_MESON_SET_INTERPRETER
	$(SED) '1s:.*:#!/usr/bin/env python3:' $(HOST_DIR)/bin/meson
endef
HOST_MESON_POST_INSTALL_HOOKS += HOST_MESON_SET_INTERPRETER

$(eval $(host-python-package))
