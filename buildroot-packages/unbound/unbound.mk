################################################################################
#
# unbound
#
################################################################################

UNBOUND_VERSION = master
UNBOUND_SITE = $(call github,nlnetlabs,unbound,master)
UNBOUND_INSTALL_STAGING = YES
UNBOUND_DEPENDENCIES = host-pkgconf expat libevent openssl nghttp2
UNBOUND_LICENSE = BSD-3-Clause
UNBOUND_LICENSE_FILES = LICENSE
UNBOUND_CPE_ID_VENDOR = nlnetlabs
UNBOUND_CONF_OPTS = \
	--disable-rpath \
	--disable-debug \
	--with-conf-file=/etc/unbound/unbound.conf \
	--with-pidfile=/var/run/unbound.pid \
	--with-libevent=$(STAGING_DIR)/usr \
	--with-libexpat=$(STAGING_DIR)/usr \
	--with-ssl=$(STAGING_DIR)/usr \
	--disable-dnscrypt

# uClibc-ng does not have MSG_FASTOPEN
# so TCP Fast Open client mode disabled for it
ifeq ($(BR2_TOOLCHAIN_USES_UCLIBC),y)
UNBOUND_CONF_OPTS += --disable-tfo-client
else
UNBOUND_CONF_OPTS += --enable-tfo-client
endif

ifeq ($(BR2_TOOLCHAIN_HAS_THREADS_NPTL),y)
UNBOUND_CONF_OPTS += --with-pthreads
else
UNBOUND_CONF_OPTS += --without-pthreads
endif

ifeq ($(BR2_ENABLE_LTO),y)
UNBOUND_CONF_OPTS += --enable-flto
else
UNBOUND_CONF_OPTS += --disable-flto
endif

$(eval $(autotools-package))
