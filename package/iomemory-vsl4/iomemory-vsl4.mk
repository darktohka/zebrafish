################################################################################
#
# iomemory-vsl4
#
# SanDisk/Fusion-io iomemory-vsl4 driver for ioMemory PCIe flash storage
#
################################################################################

IOMEMORY_VSL4_VERSION = main
IOMEMORY_VSL4_SITE = https://github.com/RemixVSL/iomemory-vsl4
IOMEMORY_VSL4_SITE_METHOD = git
IOMEMORY_VSL4_LICENSE = GPL-2.0
IOMEMORY_VSL4_LICENSE_FILES = LICENSE
IOMEMORY_VSL4_DEPENDENCIES = linux host-kmod

# Firmware and utils download from vsl_downloads repo
IOMEMORY_VSL4_EXTRA_DOWNLOADS = \
	https://github.com/RemixVSL/vsl_downloads/raw/main/vsl4/fio-util_4.3.7.1205-1.0_amd64.deb \
	https://github.com/RemixVSL/vsl_downloads/raw/main/vsl4/fusion_4.3.7-20200113.fff.tgz.partaa \
	https://github.com/RemixVSL/vsl_downloads/raw/main/vsl4/fusion_4.3.7-20200113.fff.tgz.partab \
	https://github.com/RemixVSL/vsl_downloads/raw/main/vsl4/fusion_4.3.7-20200113.fff.tgz.partac \
	https://github.com/RemixVSL/vsl_downloads/raw/main/vsl4/fusion_4.3.7-20200113.fff.tgz.partad \
	https://github.com/RemixVSL/vsl_downloads/raw/main/vsl4/fusion_4.3.7-20200113.fff.tgz.partae

# Driver source location within the repo
IOMEMORY_VSL4_SRC_SUBDIR = root/usr/src/iomemory-vsl4-4.3.7

# Kernel module build variables
IOMEMORY_VSL4_MOD_ENV = \
	ARCH=$(KERNEL_ARCH) \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	KERNEL_BUILD=$(LINUX_DIR) \
	KERNELVER=$(LINUX_VERSION_PROBED) \
	KERNEL_SRC=$(LINUX_DIR) \
	INSTALL_MOD_PATH=$(TARGET_DIR) \
	FIO_DRIVER_NAME=iomemory-vsl4 \
	FIOARCH=x86_64 \
	DEPMOD=$(HOST_DIR)/sbin/depmod

# Build flags
IOMEMORY_VSL4_CFLAGS = \
	-I$(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR)/include \
	-DBUILDING_MODULE \
	-DLINUX_IO_SCHED \
	-Wall

# Ensure the proper libkfio object is used
IOMEMORY_VSL4_KFIO_LIB = kfio/x86_64_latest_libkfio.o_shipped

# Generate kfio_config.h required for kernel module build
define IOMEMORY_VSL4_GENERATE_KFIO_CONFIG
	cd $(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR) && \
	./kfio_config.sh \
		-a x86_64 \
		-o include/fio/port/linux/kfio_config.h \
		-k $(LINUX_DIR) \
		-p \
		-d $(IOMEMORY_VSL4_SRC_SUBDIR)/kfio_config \
		-l 0 \
		-s $(LINUX_DIR)
endef

# Copy the correct libkfio object
define IOMEMORY_VSL4_SETUP_KFIO_LIB
	cd $(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR) && \
	cp kfio/x86_64_latest_libkfio.o_shipped kfio/x86_64_latest_libkfio.o;
endef

# Patch license to GPL for module loading
define IOMEMORY_VSL4_PATCH_LICENSE
	cd $(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR) && \
	sed -i 's/Proprietary/GPL/g' Kbuild
endef

# Create license.c file
define IOMEMORY_VSL4_CREATE_LICENSE_FILE
	printf '#include "linux/module.h"\nMODULE_LICENSE("GPL");\n' > $(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR)/license.c
endef

# Make objtool_wrapper executable
define IOMEMORY_VSL4_SETUP_OBJTOOL_WRAPPER
	chmod +x $(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR)/objtool_wrapper
endef

IOMEMORY_VSL4_PRE_BUILD_HOOKS += IOMEMORY_VSL4_PATCH_LICENSE
IOMEMORY_VSL4_PRE_BUILD_HOOKS += IOMEMORY_VSL4_CREATE_LICENSE_FILE
IOMEMORY_VSL4_PRE_BUILD_HOOKS += IOMEMORY_VSL4_SETUP_KFIO_LIB
#IOMEMORY_VSL4_PRE_BUILD_HOOKS += IOMEMORY_VSL4_SETUP_OBJTOOL_WRAPPER

# Build the kernel module
define IOMEMORY_VSL4_BUILD_CMDS
	# Generate kfio_config.h
	cd $(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR) && \
	./kfio_config.sh \
		-a x86_64 \
		-o include/fio/port/linux/kfio_config.h \
		-k $(LINUX_DIR) \
		-p \
		-d $(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR)/kfio_config \
		-l 0 \
		-s $(LINUX_DIR)
	rm -f $(LINUX_DIR)/tools/objtool/objtool-actual
	mv $(LINUX_DIR)/tools/objtool/objtool $(LINUX_DIR)/tools/objtool/objtool-actual
	cp $(IOMEMORY_VSL4_PKGDIR)/objtool_wrapper $(LINUX_DIR)/tools/objtool/objtool
	chmod +x $(LINUX_DIR)/tools/objtool/objtool
	$(MAKE) -C $(LINUX_DIR) \
		$(IOMEMORY_VSL4_MOD_ENV) \
		FIO_DRIVER_NAME=iomemory-vsl4 \
		FUSION_DRIVER_DIR=$(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR) \
		M=$(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR) \
		INCLUDE_DIR=$(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR)/include \
		KFIO_LIB=$(IOMEMORY_VSL4_KFIO_LIB) \
		KCFLAGS="-I$(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR)/include" \
		modules
	rm -f $(LINUX_DIR)/tools/objtool/objtool
	mv $(LINUX_DIR)/tools/objtool/objtool-actual $(LINUX_DIR)/tools/objtool/objtool
endef

# Install the kernel module
define IOMEMORY_VSL4_INSTALL_MODULE
	$(MAKE) -C $(LINUX_DIR) \
		$(IOMEMORY_VSL4_MOD_ENV) \
		FIO_DRIVER_NAME=iomemory-vsl4 \
		FUSION_DRIVER_DIR=$(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR) \
		M=$(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR) \
		INCLUDE_DIR=$(@D)/$(IOMEMORY_VSL4_SRC_SUBDIR)/include \
		INSTALL_MOD_DIR=extra/fio \
		INSTALL_MOD_PATH=$(TARGET_DIR) \
		KFIO_LIB=$(IOMEMORY_VSL4_KFIO_LIB) \
		modules_install
	# Run depmod
	$(HOST_DIR)/sbin/depmod -a -b $(TARGET_DIR) $(LINUX_VERSION_PROBED)
	# Install modules-load.d config to auto-load module at boot
	$(INSTALL) -D -m 0644 /dev/null $(TARGET_DIR)/etc/modules-load.d/iomemory-vsl4.conf
	echo "iomemory-vsl4" > $(TARGET_DIR)/etc/modules-load.d/iomemory-vsl4.conf
	cp $(IOMEMORY_VSL4_SRCDIR)/root/usr/lib/fio/libvsl_4.so \
		$(TARGET_DIR)/usr/lib/libvsl_4.so
	ln -s /usr/lib/libvsl_4.so $(TARGET_DIR)/usr/lib/libvsl.so
	ln -s /usr/lib/libvsl_4.so $(TARGET_DIR)/usr/lib/libvsl-prev.so
	ln -s /usr/lib $(TARGET_DIR)/usr/lib/fio
endef

# Install modprobe.d config from driver repo
define IOMEMORY_VSL4_INSTALL_MODPROBE_CONF
	$(INSTALL) -D -m 0644 $(@D)/root/etc/ld.so.conf.d/*.conf \
		$(TARGET_DIR)/etc/ld.so.conf.d/ || true
endef

# Install firmware files if enabled
ifeq ($(BR2_PACKAGE_IOMEMORY_VSL4_FIRMWARE),y)
define IOMEMORY_VSL4_INSTALL_FIRMWARE
	# Reassemble and extract firmware archive
	mkdir -p $(TARGET_DIR)/lib/firmware/fio
	cat $(DL_DIR)/fusion_4.3.7-20200113.fff.tgz.part* | \
		tar -xzf - -C $(BUILD_DIR) fusion_4.3.7-20200113.fff
	# The .fff file is a zip archive, extract it using unzip from the host system
	cd $(TARGET_DIR)/lib/firmware/fio && \
		unzip -o $(BUILD_DIR)/fusion_4.3.7-20200113.fff || true
	rm -f $(BUILD_DIR)/fusion_4.3.7-20200113.fff
endef
endif

# Install fio-util utilities if enabled
ifeq ($(BR2_PACKAGE_IOMEMORY_VSL4_UTILS),y)
define IOMEMORY_VSL4_INSTALL_UTILS
	# Extract the .deb file (it's an ar archive)
	mkdir -p $(BUILD_DIR)/iomemory-vsl4-deb
	cd $(BUILD_DIR)/iomemory-vsl4-deb && \
		ar x $(DL_DIR)/iomemory-vsl4/fio-util_4.3.7.1205-1.0_amd64.deb
	# Extract data.tar (could be .tar.xz, .tar.gz, or .tar.zst)
	cd $(BUILD_DIR)/iomemory-vsl4-deb && \
	if [ -f data.tar.xz ]; then \
		tar -xJf data.tar.xz -C $(TARGET_DIR); \
	elif [ -f data.tar.gz ]; then \
		tar -xzf data.tar.gz -C $(TARGET_DIR); \
	elif [ -f data.tar.zst ]; then \
		tar --zstd -xf data.tar.zst -C $(TARGET_DIR); \
	elif [ -f data.tar ]; then \
		tar -xf data.tar -C $(TARGET_DIR); \
	fi
	rm -rf $(BUILD_DIR)/iomemory-vsl4-deb
	# Install udev rules
	$(INSTALL) -D -m 0644 $(TARGET_DIR)/lib/udev/rules.d/95-fio.rules \
		$(TARGET_DIR)/usr/lib/udev/rules.d/95-fio.rules 2>/dev/null || true
	# Install modprobe.d config
	$(INSTALL) -D -m 0644 $(TARGET_DIR)/etc/modprobe.d/iomemory-vsl4.conf \
		$(TARGET_DIR)/etc/modprobe.d/iomemory-vsl4.conf 2>/dev/null || true
endef
endif

define IOMEMORY_VSL4_INSTALL_TARGET_CMDS
	$(call IOMEMORY_VSL4_INSTALL_MODULE)
	$(call IOMEMORY_VSL4_INSTALL_MODPROBE_CONF)
	$(call IOMEMORY_VSL4_INSTALL_FIRMWARE)
	$(call IOMEMORY_VSL4_INSTALL_UTILS)
endef

# Clean up source files from target
define IOMEMORY_VSL4_CLEANUP
	$(RM) -rf $(TARGET_DIR)/usr/src/iomemory-vsl4*
endef

IOMEMORY_VSL4_POST_INSTALL_TARGET_HOOKS += IOMEMORY_VSL4_CLEANUP

# Kernel configuration requirements for iomemory-vsl4
define IOMEMORY_VSL4_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_ENABLE_OPT,CONFIG_BLOCK)
	$(call KCONFIG_ENABLE_OPT,CONFIG_PCI)
	$(call KCONFIG_ENABLE_OPT,CONFIG_MODULES)
	$(call KCONFIG_ENABLE_OPT,CONFIG_MODULE_UNLOAD)
endef

$(eval $(generic-package))
