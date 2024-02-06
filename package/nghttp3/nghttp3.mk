################################################################################
#
# nghttp3
#
################################################################################

NGHTTP3_VERSION = origin/main
NGHTTP3_SITE = https://github.com/ngtcp2/nghttp3
NGHTTP3_SITE_METHOD = git
NGHTTP3_GIT_SUBMODULES = YES
NGHTTP3_INSTALL_STAGING = YES
NGHTTP3_CONF_OPTS = -DENABLE_LIB_ONLY=ON -DENABLE_STATIC_LIB=OFF -DENABLE_SHARED_LIB=ON -DCMAKE_CXX_EXTENSIONS=OFF

define NGHTTP3_REMOVE_EXAMPLES
	rm -rf $(@D)/fuzz
	rm -rf $(@D)/examples
	mkdir -p $(@D)/examples
	touch $(@D)/examples/CMakeLists.txt
	rm -rf $(@D)/tests
	mkdir -p $(@D)/tests
	touch $(@D)/tests/CMakeLists.txt
	sed -Ei 's/project\(([^ ]+)/project(\1 LANGUAGES C/' $(@D)/CMakeLists.txt
endef

NGHTTP3_PRE_CONFIGURE_HOOKS += NGHTTP3_REMOVE_EXAMPLES

$(eval $(cmake-package))