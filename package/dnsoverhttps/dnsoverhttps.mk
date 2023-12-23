################################################################################
#
# dnsoverhttps
#
################################################################################

DNSOVERHTTPS_VERSION = master
DNSOVERHTTPS_SITE = $(call github,darktohka,https_dns_proxy,clang-tidy)
DNSOVERHTTPS_DEPENDENCIES = libcurl c-ares libev
DNSOVERHTTPS_CONF_OPTS = -DCMAKE_BUILD_TYPE="Release" -DUSE_CLANG_TIDY=OFF

$(eval $(cmake-package))