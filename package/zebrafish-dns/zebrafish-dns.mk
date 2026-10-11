################################################################################
#
# zebrafish-dns
#
################################################################################

ZEBRAFISH_DNS_VERSION = master
ZEBRAFISH_DNS_SITE = $(BR2_EXTERNAL_ZEBRAFISH_PATH)/package/zebrafish-dns
ZEBRAFISH_DNS_SITE_METHOD = local
ZEBRAFISH_DNS_LICENSE = MIT

# aws-lc-sys compiles jitterentropy with -O0 and fails if later flags re-enable
# optimization. Remove -Ofast from Buildroot CFLAGS for this package only.
ZEBRAFISH_DNS_CARGO_ENV = \
	CFLAGS="$(filter-out -Ofast,$(TARGET_CFLAGS))" \
	CFLAGS_$(subst -,_,$(RUSTC_TARGET_NAME))="$(filter-out -Ofast,$(TARGET_CFLAGS))"

define ZEBRAFISH_DNS_STRIP_BINARY
	$(TARGET_STRIP) $(TARGET_DIR)/usr/bin/zebrafish-dns
endef

define ZEBRAFISH_DNS_INSTALL_NSS
	$(INSTALL) -D -m 0755 $(@D)/target/$(RUSTC_TARGET_NAME)/release/libzebrafish_dns.so \
		$(TARGET_DIR)/lib/libnss_zebrafish.so.2
endef

define ZEBRAFISH_DNS_INSTALL_CONFIG
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_ZEBRAFISH_PATH)/package/zebrafish-dns/config/zebrafish-dns.toml \
		$(TARGET_DIR)/etc/zebrafish-dns/zebrafish-dns.toml
endef

ZEBRAFISH_DNS_POST_INSTALL_TARGET_HOOKS += ZEBRAFISH_DNS_STRIP_BINARY
ZEBRAFISH_DNS_POST_INSTALL_TARGET_HOOKS += ZEBRAFISH_DNS_INSTALL_NSS
ZEBRAFISH_DNS_POST_INSTALL_TARGET_HOOKS += ZEBRAFISH_DNS_INSTALL_CONFIG

$(eval $(cargo-package))
