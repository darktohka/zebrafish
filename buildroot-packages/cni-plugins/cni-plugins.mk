################################################################################
#
# cni-plugins
#
################################################################################

CNI_PLUGINS_VERSION = main
CNI_PLUGINS_SITE = $(call github,containernetworking,plugins,main)
CNI_PLUGINS_LICENSE = Apache-2.0
CNI_PLUGINS_LICENSE_FILES = LICENSE

CNI_PLUGINS_BUILD_TARGETS = \
	plugins/main/bridge \
	plugins/meta/firewall \
	plugins/ipam/host-local \
	plugins/meta/portmap \
	plugins/meta/tuning

# CNI_PLUGINS_BUILD_TARGETS = \
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
CNI_PLUGINS_INSTALL_BINS = $(CNI_PLUGINS_BUILD_TARGETS)

ifeq ($(BR2_PACKAGE_LIBAPPARMOR),y)
CNI_PLUGINS_DEPENDENCIES += libapparmor
CNI_PLUGINS_TAGS += apparmor
endif

ifeq ($(BR2_PACKAGE_LIBSECCOMP),y)
CNI_PLUGINS_TAGS += seccomp
CNI_PLUGINS_DEPENDENCIES += libseccomp host-pkgconf
endif

ifeq ($(BR2_PACKAGE_LIBSELINUX),y)
CNI_PLUGINS_TAGS += selinux
CNI_PLUGINS_DEPENDENCIES += libselinux
endif

define CNI_PLUGINS_INSTALL_TARGET_CMDS
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/usr/lib/cni
	$(foreach d,$(CNI_PLUGINS_INSTALL_BINS),\
		$(INSTALL) -D -m 0755 $(@D)/bin/$$(basename $(d)) \
			$(TARGET_DIR)/usr/lib/cni
	)
endef

$(eval $(golang-package))
