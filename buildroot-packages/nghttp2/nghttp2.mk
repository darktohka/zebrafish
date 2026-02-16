################################################################################
#
# nghttp2
#
################################################################################

NGHTTP2_VERSION = origin/master
NGHTTP2_SITE = https://github.com/nghttp2/nghttp2
NGHTTP2_SITE_METHOD = git
NGHTTP2_GIT_SUBMODULES = NO
NGHTTP2_INSTALL_STAGING = YES
NGHTTP2_CONF_OPTS = -DBUILD_STATIC_LIBS=OFF -DBUILD_SHARED_LIBS=ON -DENABLE_EXAMPLES=OFF -DENABLE_APP=OFF -DENABLE_HPACK_TOOLS=OFF -DENABLE_DOC=OFF -DBUILD_TESTING=OFF -DWITH_WOLFSSL=ON -DENABLE_HTTP3=ON
NGHTTP2_DEPENDENCIES += \
	ngtcp2 \
	wolfssl \
	nghttp3

define NGHTTP2_REMOVE_EXAMPLES
	rm -rf $(@D)/fuzz
	rm -rf $(@D)/examples
	mkdir -p $(@D)/examples
	touch $(@D)/examples/CMakeLists.txt
	rm -rf $(@D)/tests
	mkdir -p $(@D)/tests
	touch $(@D)/tests/CMakeLists.txt
endef

NGHTTP2_PRE_CONFIGURE_HOOKS += NGHTTP2_REMOVE_EXAMPLES

$(eval $(cmake-package))
