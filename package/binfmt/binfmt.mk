################################################################################
#
# qemu
#
################################################################################

# When updating the version, check whether the list of supported targets
# needs to be updated.
BINFMT_VERSION = master
BINFMT_SITE = $(call github,qemu,qemu,master)
BINFMT_SELINUX_MODULES = qemu virt

#-------------------------------------------------------------

# The build system is now partly based on Meson.
# However, building is still done with configure and make as in previous versions of QEMU.

# Target-qemu
BINFMT_DEPENDENCIES = \
	host-meson \
	host-pkgconf \
	host-python3 \
	host-python-distlib \
	libglib2 \
	zlib

# Need the LIBS variable because librt and libm are
# not automatically pulled. :-(
BINFMT_LIBS = -lrt -lm

BINFMT_OPTS = --static --disable-system

BINFMT_VARS = LIBTOOL=$(HOST_DIR)/bin/libtool

define BINFMT_REMOVE_TESTS
	sed -Ei 's/^subdir\([^)]+tests[^)]+\)$//' $(@D)/meson.build
	find $(@D)/tests -type f \( -name "meson.build" -or -name "Makefile.include" \) -exec truncate -s0 {} \;
endef

BINFMT_PRE_CONFIGURE_HOOKS += BINFMT_REMOVE_TESTS

# If we want to build all emulation targets, we just need to either enable -user
# and/or -system emulation appropriately.
# Otherwise, if we want only a subset of targets, we must still enable all of
# them, so that QEMU properly builds a list of default targets from which it
# checks if the specified sub-set is valid.

ifeq ($(BR2_PACKAGE_BINFMT_LINUX_USER),y)
BINFMT_OPTS += --enable-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_AARCH64) += aarch64-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_AARCH64_BE) += aarch64_be-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_ALPHA) += alpha-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_ARM) += arm-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_ARMEB) += armeb-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_CRIS) += cris-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_HEXAGON) += hexagon-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_HPPA) += hppa-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_I386) += i386-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_LOONGARCH64) += loongarch64-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_M68K) += m68k-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_MICROBLAZE) += microblaze-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_MICROBLAZEEL) += microblazeel-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_MIPS) += mips-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_MIPS64) += mips64-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_MIPS64EL) += mips64el-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_MIPSEL) += mipsel-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_MIPSN32) += mipsn32-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_MIPSN32EL) += mipsn32el-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_NIOS2) += nios2-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_OR1K) += or1k-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_PPC) += ppc-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_PPC64) += ppc64-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_PPC64LE) += ppc64le-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_RISCV32) += riscv32-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_RISCV64) += riscv64-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_S390X) += s390x-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_SH4) += sh4-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_SH4EB) += sh4eb-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_SPARC) += sparc-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_SPARC32PLUS) += sparc32plus-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_SPARC64) += sparc64-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_X86_64) += x86_64-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_XTENSA) += xtensa-linux-user
BINFMT_TARGET_LIST_$(BR2_PACKAGE_BINFMT_TARGET_XTENSAEB) += xtensaeb-linux-user
else
BINFMT_OPTS += --disable-linux-user
endif

# Build the list of desired targets, if any.
ifeq ($(BR2_PACKAGE_BINFMT_CHOOSE_TARGETS),y)
BINFMT_TARGET_LIST = $(strip $(BINFMT_TARGET_LIST_y))
ifeq ($(BR_BUILDING).$(BINFMT_TARGET_LIST),y.)
$(error "No emulator target has ben chosen")
endif
BINFMT_OPTS += --target-list="$(BINFMT_TARGET_LIST)"
endif

ifeq ($(BR2_TOOLCHAIN_USES_UCLIBC),y)
BINFMT_OPTS += --disable-vhost-user
else
BINFMT_OPTS += --enable-vhost-user
endif

ifeq ($(BR2_PACKAGE_BINFMT_SLIRP),y)
BINFMT_OPTS += --enable-slirp
BINFMT_DEPENDENCIES += slirp
else
BINFMT_OPTS += --disable-slirp
endif

ifeq ($(BR2_PACKAGE_BINFMT_SDL),y)
BINFMT_OPTS += --enable-sdl
BINFMT_DEPENDENCIES += sdl2
BINFMT_VARS += SDL2_CONFIG=$(STAGING_DIR)/usr/bin/sdl2-config
else
BINFMT_OPTS += --disable-sdl
endif

ifeq ($(BR2_PACKAGE_BINFMT_FDT),y)
BINFMT_OPTS += --enable-fdt
BINFMT_DEPENDENCIES += dtc
else
BINFMT_OPTS += --disable-fdt
endif

ifeq ($(BR2_PACKAGE_BINFMT_TRACING),y)
BINFMT_OPTS += --enable-trace-backends=log
else
BINFMT_OPTS += --enable-trace-backends=nop
endif

ifeq ($(BR2_PACKAGE_BINFMT_TOOLS),y)
BINFMT_OPTS += --enable-tools
else
BINFMT_OPTS += --disable-tools
endif

ifeq ($(BR2_PACKAGE_BINFMT_GUEST_AGENT),y)
BINFMT_OPTS += --enable-guest-agent
else
BINFMT_OPTS += --disable-guest-agent
endif

ifeq ($(BR2_PACKAGE_LIBFUSE3),y)
BINFMT_OPTS += --enable-fuse --enable-fuse-lseek
BINFMT_DEPENDENCIES += libfuse3
else
BINFMT_OPTS += --disable-fuse --disable-fuse-lseek
endif

ifeq ($(BR2_PACKAGE_LIBSECCOMP),y)
BINFMT_OPTS += --enable-seccomp
BINFMT_DEPENDENCIES += libseccomp
else
BINFMT_OPTS += --disable-seccomp
endif

ifeq ($(BR2_PACKAGE_LIBSSH),y)
BINFMT_OPTS += --enable-libssh
BINFMT_DEPENDENCIES += libssh
else
BINFMT_OPTS += --disable-libssh
endif

ifeq ($(BR2_PACKAGE_LIBUSB),y)
BINFMT_OPTS += --enable-libusb
BINFMT_DEPENDENCIES += libusb
else
BINFMT_OPTS += --disable-libusb
endif

ifeq ($(BR2_PACKAGE_LIBVNCSERVER),y)
BINFMT_OPTS += \
	--enable-vnc \
	--disable-vnc-sasl
BINFMT_DEPENDENCIES += libvncserver
ifeq ($(BR2_PACKAGE_LIBPNG),y)
BINFMT_OPTS += --enable-png
BINFMT_DEPENDENCIES += libpng
else
BINFMT_OPTS += --disable-png
endif
ifeq ($(BR2_PACKAGE_JPEG),y)
BINFMT_OPTS += --enable-vnc-jpeg
BINFMT_DEPENDENCIES += jpeg
else
BINFMT_OPTS += --disable-vnc-jpeg
endif
else
BINFMT_OPTS += --disable-vnc
endif

ifeq ($(BR2_PACKAGE_NETTLE),y)
BINFMT_OPTS += --enable-nettle
BINFMT_DEPENDENCIES += nettle
else
BINFMT_OPTS += --disable-nettle
endif

ifeq ($(BR2_PACKAGE_NUMACTL),y)
BINFMT_OPTS += --enable-numa
BINFMT_DEPENDENCIES += numactl
else
BINFMT_OPTS += --disable-numa
endif

ifeq ($(BR2_PACKAGE_PIPEWIRE),y)
BINFMT_OPTS += --enable-pipewire
BINFMT_DEPENDENCIES += pipewire
else
BINFMT_OPTS += --disable-pipewire
endif

ifeq ($(BR2_PACKAGE_SPICE),y)
BINFMT_OPTS += --enable-spice
BINFMT_DEPENDENCIES += spice
else
BINFMT_OPTS += --disable-spice
endif

ifeq ($(BR2_PACKAGE_USBREDIR),y)
BINFMT_OPTS += --enable-usb-redir
BINFMT_DEPENDENCIES += usbredir
else
BINFMT_OPTS += --disable-usb-redir
endif

ifeq ($(BR2_PACKAGE_BINFMT_BLOBS),y)
BINFMT_OPTS += --enable-install-blobs
else
BINFMT_OPTS += --disable-install-blobs
endif

# Override CPP, as it expects to be able to call it like it'd
# call the compiler.
define BINFMT_CONFIGURE_CMDS
	unset TARGET_DIR; \
	cd $(@D); \
		LIBS='$(BINFMT_LIBS)' \
		$(TARGET_CONFIGURE_OPTS) \
		$(TARGET_CONFIGURE_ARGS) \
		CPP="$(TARGET_CC) -E" \
		$(BINFMT_VARS) \
		./configure \
			--prefix=/usr \
			--cross-prefix=$(TARGET_CROSS) \
			--audio-drv-list= \
			--python=$(HOST_DIR)/bin/python3 \
			--ninja=$(HOST_DIR)/bin/ninja \
			--disable-alsa \
			--disable-bpf \
			--disable-brlapi \
			--disable-bsd-user \
			--disable-cap-ng \
			--disable-capstone \
			--disable-containers \
			--disable-coreaudio \
			--disable-curl \
			--disable-curses \
			--disable-dbus-display \
			--disable-docs \
			--disable-dsound \
			--disable-hvf \
			--disable-jack \
			--disable-libiscsi \
			--disable-linux-aio \
			--disable-linux-io-uring \
			--disable-malloc-trim \
			--disable-membarrier \
			--disable-mpath \
			--disable-netmap \
			--disable-opengl \
			--disable-oss \
			--disable-pa \
			--disable-rbd \
			--disable-sanitizers \
			--disable-selinux \
			--disable-sparse \
			--disable-strip \
			--disable-vde \
			--disable-vhost-crypto \
			--disable-vhost-user-blk-server \
			--disable-virtfs \
			--disable-whpx \
			--disable-xen \
			--enable-attr \
			--enable-kvm \
			--enable-vhost-net \
			--disable-hexagon-idef-parser \
			$(BINFMT_OPTS)
endef

define BINFMT_BUILD_CMDS
	unset TARGET_DIR; \
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)
endef

define BINFMT_INSTALL_TARGET_CMDS
	unset TARGET_DIR; \
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(BINFMT_MAKE_ENV) DESTDIR=$(TARGET_DIR) install
endef

$(eval $(generic-package))

# variable used by other packages
BINFMT_USER = $(HOST_DIR)/bin/qemu-$(HOST_BINFMT_ARCH)
