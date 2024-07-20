################################################################################
#
# wolfssl
#
################################################################################

WOLFSSL_VERSION = master
WOLFSSL_SITE = $(call github,wolfSSL,wolfssl,master)
WOLFSSL_INSTALL_STAGING = YES

WOLFSSL_LICENSE = GPL-2.0+
WOLFSSL_LICENSE_FILES = COPYING LICENSING
WOLFSSL_DEPENDENCIES = host-pkgconf

WOLFSSL_CONF_OPTS = -DWOLFSSL_ASM=yes -DWOLFSSL_EXAMPLES=no -DWOLFSSL_CRYPT_TESTS=no -DWOLFSSL_OLD_TLS=no -DWOLFSSL_QUIC=yes -DWOLFSSL_CURL=yes -DCMAKE_C_FLAGS="-Wno-stringop-overflow"

WOLFSSL_SUPPORTS_IN_SOURCE_BUILD = NO

$(eval $(cmake-package))
