################################################################################
#
# ripgrep
#
################################################################################

RIPGREP_VERSION = master
RIPGREP_SITE = $(call github,burntsushi,ripgrep,master)
RIPGREP_LICENSE = MIT
RIPGREP_LICENSE_FILES = LICENSE-MIT
RIPGREP_CPE_ID_VALID = YES
RIPGREP_CARGO_BUILD_OPTS = --release

ifeq ($(BR2_PACKAGE_RIPGREP_PCRE2),y)
RIPGREP_DEPENDENCIES += pcre2
RIPGREP_CARGO_BUILD_OPTS += --features pcre2
endif

define RIPGREP_STRIP_BINARY
	$(TARGET_STRIP) $(TARGET_DIR)/usr/bin/rg
endef

RIPGREP_POST_INSTALL_TARGET_HOOKS += RIPGREP_STRIP_BINARY

$(eval $(cargo-package))