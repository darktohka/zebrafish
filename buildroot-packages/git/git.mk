################################################################################
#
# git
#
################################################################################

GIT_VERSION = origin/master
GIT_SITE = https://git.kernel.org/pub/scm/git/git.git
GIT_SITE_METHOD = git
GIT_GIT_SUBMODULES = YES
GIT_LICENSE = GPL-2.0, LGPL-2.1+
GIT_LICENSE_FILES = COPYING LGPL-2.1
GIT_SELINUX_MODULES = apache git xdg
GIT_DEPENDENCIES = host-rustc zlib $(TARGET_NLS_DEPENDENCIES)
GIT_AUTORECONF = YES

GIT_CONF_OPTS += --without-openssl

ifeq ($(BR2_PACKAGE_PCRE2),y)
GIT_DEPENDENCIES += pcre2
GIT_CONF_OPTS += --with-libpcre2
else
GIT_CONF_OPTS += --without-libpcre2
endif

ifeq ($(BR2_PACKAGE_LIBCURL),y)
GIT_DEPENDENCIES += libcurl
GIT_CONF_OPTS += --with-curl
GIT_CONF_ENV += \
	ac_cv_prog_CURLDIR=$(TARGET_DIR)/usr \
	ac_cv_prog_CURL_LDFLAGS=-lcurl \
	ac_cv_prog_CURL_CONFIG=$(TARGET_DIR)/usr/bin/curl-config
GIT_MAKE_OPTS += \
	CURLDIR=$(TARGET_DIR)/usr \
	CURL_LDFLAGS=-lcurl \
	CURL_CONFIG=$(TARGET_DIR)/usr/bin/curl-config
else
GIT_CONF_OPTS += --without-curl
endif

ifeq ($(BR2_PACKAGE_EXPAT),y)
GIT_DEPENDENCIES += expat
GIT_CONF_OPTS += --with-expat
else
GIT_CONF_OPTS += --without-expat
endif

ifeq ($(BR2_PACKAGE_LIBICONV),y)
GIT_DEPENDENCIES += libiconv
GIT_CONF_ENV_LIBS += -liconv
GIT_CONF_OPTS += --with-iconv=$(STAGING_DIR)/usr
GIT_CONF_ENV += ac_cv_iconv_omits_bom=no
else
GIT_CONF_OPTS += --without-iconv
endif

ifeq ($(BR2_PACKAGE_TCL),y)
GIT_DEPENDENCIES += tcl
GIT_CONF_OPTS += --with-tcltk
else
GIT_CONF_OPTS += --without-tcltk
endif

ifeq ($(BR2_SYSTEM_ENABLE_NLS),)
GIT_MAKE_OPTS += NO_GETTEXT=1
endif

# Cargo puts cross-built static libraries under target/<triple>/release.
# PKG_CARGO_ENV already sets CARGO_BUILD_TARGET, and git's Makefile derives
# RUST_LIB (target/$(CARGO_BUILD_TARGET)/release/libgitcore.a) from it.
#
# Do NOT additionally pass RUST_TARGETS: when both RUST_TARGETS and
# CARGO_BUILD_TARGET are set to the same triple, git's Makefile ends up with
# two rules for target/<triple>/release/libgitcore.a. The second rule builds
# RUST_LIB from RUST_MEMBER_LIBS, which is the very same file, so make drops
# the self-dependency ("Circular ... dependency dropped") and runs its recipe
# with an empty $<, producing an invalid libgitcore.a that fails to link.
GIT_MAKE_ENV += $(PKG_CARGO_ENV)

GIT_CFLAGS = $(TARGET_CFLAGS)

GIT_CONF_OPTS += CFLAGS="$(GIT_CFLAGS)"
GIT_MAKE_OPTS += INSTALL_SYMLINKS=1 NO_SVN_TESTS=1

GIT_INSTALL_TARGET_OPTS = $(GIT_MAKE_OPTS) DESTDIR=$(TARGET_DIR) install

# assume yes for these tests, configure will bail out otherwise
# saying error: cannot run test program while cross compiling
GIT_CONF_ENV += \
	ac_cv_install_symlinks=yes \
	ac_cv_fread_reads_directories=yes \
	ac_cv_snprintf_returns_bogus=yes LIBS='$(GIT_CONF_ENV_LIBS)'

$(eval $(autotools-package))
