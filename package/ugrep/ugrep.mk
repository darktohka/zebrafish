################################################################################
#
# ugrep
#
################################################################################

UGREP_VERSION = origin/master
UGREP_SITE = https://github.com/Genivia/ugrep
UGREP_SITE_METHOD = git
UGREP_LICENSE = BSD-3-Clause
UGREP_LICENSE_FILES = LICENSE.txt

UGREP_MAKE_OPTS = \
	CC=$(TARGET_CC) \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"

# Create symlinks for fgrep, grep and egrep
define UGREP_ADD_SYMLINKS
	ln -s /usr/bin/ugrep $(TARGET_DIR)/usr/bin/grep \
	&& ln -s /usr/bin/ugrep $(TARGET_DIR)/usr/bin/egrep \
	&& ln -s /usr/bin/ugrep $(TARGET_DIR)/usr/bin/fgrep
endef

UGREP_POST_INSTALL_TARGET_HOOKS += UGREP_ADD_SYMLINKS

$(eval $(autotools-package))
