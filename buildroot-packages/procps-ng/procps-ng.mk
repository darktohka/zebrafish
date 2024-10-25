################################################################################
#
# procps-ng
#
################################################################################

PROCPS_NG_VERSION = origin/master
PROCPS_NG_SITE = https://gitlab.com/darktohka/procps
PROCPS_NG_SITE_METHOD = git
PROCPS_NG_INSTALL_STAGING = YES
PROCPS_NG_DEPENDENCIES = ncurses host-pkgconf $(TARGET_NLS_DEPENDENCIES)
PROCPS_NG_CONF_OPTS = LIBS=$(TARGET_NLS_LIBS)

define PROCPS_NG_RUN_AUTOGEN
	cd $(@D) && PATH=$(BR_PATH) ./autogen.sh
endef
PROCPS_NG_PRE_CONFIGURE_HOOKS += PROCPS_NG_RUN_AUTOGEN

ifeq ($(BR2_PACKAGE_SYSTEMD),y)
PROCPS_NG_DEPENDENCIES += systemd
PROCPS_NG_CONF_OPTS += --with-systemd
else
PROCPS_NG_CONF_OPTS += --without-systemd
endif

# Make sure binaries get installed in /bin, as busybox does, so that we
# don't end up with two versions.
# Make sure libprocps.pc is installed in STAGING_DIR/usr/lib/pkgconfig/
# otherwise it's installed in STAGING_DIR/lib/pkgconfig/ breaking
# pkg-config --libs libprocps.
PROCPS_NG_CONF_OPTS += --exec-prefix=/ \
	--libdir=/usr/lib

# Disable watch because of ncurses issues
PROCPS_NG_CONF_OPTS += --disable-watch

ifeq ($(BR2_USE_WCHAR),)
PROCPS_NG_CONF_OPTS += CPPFLAGS=-DOFF_XTRAWIDE
endif

# numa support requires libdl, so explicitly disable it when
# BR2_STATIC_LIBS=y
ifeq ($(BR2_STATIC_LIBS),y)
PROCPS_NG_CONF_OPTS += --disable-numa
endif

# w requires utmp.h
ifeq ($(BR2_TOOLCHAIN_USES_MUSL),y)
PROCPS_NG_CONF_OPTS += --disable-w
else
PROCPS_NG_CONF_OPTS += --enable-w
endif

# Avoid installing S02sysctl, since openrc provides /etc/init.d/sysctl.
define PROCPS_NG_INSTALL_INIT_OPENRC
	@:
endef

define PROCPS_NG_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 755 package/procps-ng/S02sysctl \
		$(TARGET_DIR)/etc/init.d/S02sysctl
endef

$(eval $(autotools-package))
