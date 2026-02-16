################################################################################
#
# bfs
#
################################################################################

BFS_VERSION = main
BFS_SITE = $(call github,tavianator,bfs,main)
BFS_LICENSE = 0BSD
BFS_LICENSE_FILES = LICENSE

BFS_DEPENDENCIES = host-pkgconf
BFS_CONF_OPTS = --prefix=/usr

ifeq ($(BR2_PACKAGE_ACL),y)
BFS_DEPENDENCIES += acl
BFS_CONF_OPTS += --with-libacl
else
BFS_CONF_OPTS += --without-libacl
endif

ifeq ($(BR2_PACKAGE_LIBCAP),y)
BFS_DEPENDENCIES += libcap
BFS_CONF_OPTS += --with-libcap
else
BFS_CONF_OPTS += --without-libcap
endif

ifeq ($(BR2_PACKAGE_LIBSELINUX),y)
BFS_DEPENDENCIES += libselinux
BFS_CONF_OPTS += --with-libselinux
else
BFS_CONF_OPTS += --without-libselinux
endif

ifeq ($(BR2_PACKAGE_LIBURING),y)
BFS_DEPENDENCIES += liburing
BFS_CONF_OPTS += --with-liburing
else
BFS_CONF_OPTS += --without-liburing
endif

ifeq ($(BR2_PACKAGE_ONIGURUMA),y)
BFS_DEPENDENCIES += oniguruma
BFS_CONF_OPTS += --with-oniguruma
else
BFS_CONF_OPTS += --without-oniguruma
endif

define BFS_CONFIGURE_CMDS
	(cd $(@D); $(TARGET_CONFIGURE_OPTS) ./configure $(BFS_CONF_OPTS))
endef

define BFS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)
endef

define BFS_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) DESTDIR=$(TARGET_DIR) install
endef

$(eval $(generic-package))
