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
GIT_DEPENDENCIES = zlib $(TARGET_NLS_DEPENDENCIES)
GIT_AUTORECONF = YES

ifeq ($(BR2_PACKAGE_OPENSSL),y)
GIT_DEPENDENCIES += host-pkgconf openssl
GIT_CONF_OPTS += --with-openssl
GIT_MAKE_OPTS += LIB_4_CRYPTO="`$(PKG_CONFIG_HOST_BINARY) --libs libssl libcrypto`"
else
GIT_CONF_OPTS += --without-openssl
endif

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
	ac_cv_prog_CURL_CONFIG=$(STAGING_DIR)/usr/bin/$(LIBCURL_CONFIG_SCRIPTS)
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

define GIT_INSTALL_SYMLINKS
	for folder in usr/bin usr/libexec/git-core; do \
		for file in $$(find $(TARGET_DIR)/$${folder} -type f -name 'git-*'); do \
			if file "$${file}" | grep -q 'executable'; then \
				ln -sf /usr/bin/git "$${file}"; \
			fi; \
		done; \
	done; \
	$(RM) -f $(TARGET_DIR)/usr/bin/scalar
endef
GIT_POST_INSTALL_TARGET_HOOKS += GIT_INSTALL_SYMLINKS

$(eval $(autotools-package))
