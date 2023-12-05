################################################################################
#
# containerdnet
#
################################################################################

CONTAINERDNET_VERSION = origin/main
CONTAINERDNET_SITE = https://github.com/containernetworking/plugins
CONTAINERDNET_SITE_METHOD = git
CONTAINERDNET_LICENSE = Apache-2.0
CONTAINERDNET_LICENSE_FILES = LICENSE

CONTAINERDNET_BUILD_TARGETS = \
	plugins/main/bridge \
	plugins/meta/firewall \
	plugins/ipam/host-local \
	plugins/meta/portmap \
	plugins/meta/tuning

# CONTAINERDNET_BUILD_TARGETS = \
# 	plugins/ipam/dhcp \
# 	plugins/ipam/host-local \
# 	plugins/ipam/static \
# 	plugins/main/bridge \
# 	plugins/main/dummy \
# 	plugins/main/host-device \
# 	plugins/main/ipvlan \
# 	plugins/main/loopback \
# 	plugins/main/macvlan \
# 	plugins/main/ptp \
# 	plugins/main/tap \
# 	plugins/main/vlan \
# 	plugins/meta/bandwidth \
# 	plugins/meta/firewall \
# 	plugins/meta/portmap \
# 	plugins/meta/tuning \
# 	plugins/meta/vrf
CONTAINERDNET_INSTALL_BINS = $(CONTAINERDNET_BUILD_TARGETS)

ifeq ($(BR2_PACKAGE_LIBAPPARMOR),y)
CONTAINERDNET_DEPENDENCIES += libapparmor
CONTAINERDNET_TAGS += apparmor
endif

ifeq ($(BR2_PACKAGE_LIBSECCOMP),y)
CONTAINERDNET_TAGS += seccomp
CONTAINERDNET_DEPENDENCIES += libseccomp host-pkgconf
endif

ifeq ($(BR2_PACKAGE_LIBSELINUX),y)
CONTAINERDNET_TAGS += selinux
CONTAINERDNET_DEPENDENCIES += libselinux
endif

define CONTAINERDNET_INSTALL_TARGET_CMDS
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/usr/lib/cni
	$(foreach d,$(CONTAINERDNET_INSTALL_BINS),\
		$(INSTALL) -D -m 0755 $(@D)/bin/$$(basename $(d)) \
			$(TARGET_DIR)/usr/lib/cni
	)
endef

$(eval $(golang-package))
