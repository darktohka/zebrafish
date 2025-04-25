################################################################################
#
# dropbear
#
################################################################################

DROPBEAR_VERSION = master
DROPBEAR_SITE = $(call github,mkj,dropbear,master)
DROPBEAR_LICENSE = MIT, BSD-2-Clause, Public domain
DROPBEAR_LICENSE_FILES = LICENSE
DROPBEAR_DEPENDENCIES = zlib libtomcrypt
DROPBEAR_TARGET_BINS = dropbearkey dropbearconvert dbclient ssh
DROPBEAR_PROGRAMS = dropbear $(DROPBEAR_TARGET_BINS)

# Disable hardening flags added by dropbear configure.ac, and let
# Buildroot add them when the relevant options are enabled. This
# prevents dropbear from using SSP support when not available.
DROPBEAR_CONF_OPTS = --disable-harden --disable-bundled-libtom --disable-syslog --disable-wtmp --disable-lastlog

DROPBEAR_MAKE = \
	$(MAKE) MULTI=1 \
	PROGRAMS="$(DROPBEAR_PROGRAMS)"

# With BR2_SHARED_STATIC_LIBS=y the generic infrastructure adds a
# --enable-static flags causing dropbear to be built as a static
# binary. Adding a --disable-static reverts this
ifeq ($(BR2_SHARED_STATIC_LIBS),y)
DROPBEAR_CONF_OPTS += --disable-static
endif

define DROPBEAR_CONFIG
	echo '#define DROPBEAR_SVR_PASSWORD_AUTH 0'     >> $(@D)/localoptions.h
	echo '#define DROPBEAR_SVR_PAM_AUTH 0'          >> $(@D)/localoptions.h
	echo '#define DROPBEAR_AES128 0'                >> $(@D)/localoptions.h
	echo '#define DROPBEAR_AES256 0'                >> $(@D)/localoptions.h
	echo '#define DROPBEAR_3DES 0'                  >> $(@D)/localoptions.h
	echo '#define DROPBEAR_CHACHA20POLY1305 1'      >> $(@D)/localoptions.h
	echo '#define DROPBEAR_ENABLE_CTR_MODE 0'       >> $(@D)/localoptions.h
	echo '#define DROPBEAR_ENABLE_CBC_MODE 0'       >> $(@D)/localoptions.h
	echo '#define DROPBEAR_SHA1_HMAC 0'             >> $(@D)/localoptions.h
	echo '#define DROPBEAR_SHA2_256_HMAC 0'         >> $(@D)/localoptions.h
	echo '#define DROPBEAR_SHA2_512_HMAC 0'         >> $(@D)/localoptions.h
	echo '#define DROPBEAR_SHA1_96_HMAC 0'          >> $(@D)/localoptions.h
	echo '#define DROPBEAR_RSA 0'                   >> $(@D)/localoptions.h
	echo '#define DROPBEAR_RSA_SHA1 0'              >> $(@D)/localoptions.h
	echo '#define DROPBEAR_DSS 0'                   >> $(@D)/localoptions.h
	echo '#define DROPBEAR_ECDSA 0'                 >> $(@D)/localoptions.h
	echo '#define DROPBEAR_ED25519 1'               >> $(@D)/localoptions.h
	echo '#define DROPBEAR_DH_GROUP14_SHA1 0'       >> $(@D)/localoptions.h
	echo '#define DROPBEAR_DH_GROUP14_SHA256 0'     >> $(@D)/localoptions.h
	echo '#define DROPBEAR_DH_GROUP16 0'            >> $(@D)/localoptions.h
	echo '#define DROPBEAR_CURVE25519 0'            >> $(@D)/localoptions.h
	echo '#define DROPBEAR_SNTRUP761 1'             >> $(@D)/localoptions.h
	echo '#define DROPBEAR_MLKEM768 0'              >> $(@D)/localoptions.h
	echo '#define DROPBEAR_ECDH 0'                  >> $(@D)/localoptions.h
	echo '#define DROPBEAR_DH_GROUP1 0'             >> $(@D)/localoptions.h
	echo '#define DROPBEAR_SFTPSERVER 1'	        >> $(@D)/localoptions.h
	echo '#define DROPBEAR_SMALL_CODE 0'            >> $(@D)/localoptions.h
	echo '#define DO_HOST_LOOKUP 0'	                >> $(@D)/localoptions.h
	echo '#define DEFAULT_RECV_WINDOW 10485760'     >> $(@D)/localoptions.h
	echo '#define RECV_MAX_PAYLOAD_LEN 262144'    >> $(@D)/localoptions.h
	echo '#define TRANS_MAX_PAYLOAD_LEN 262144'   >> $(@D)/localoptions.h
	sed -Ei 's/^.+LOCAL_IDENT.+/#define LOCAL_IDENT "SSH-2.0-Zebrafish"/' $(@D)/src/sysoptions.h
endef
DROPBEAR_POST_EXTRACT_HOOKS += DROPBEAR_CONFIG

define DROPBEAR_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 755 package/dropbear/S50dropbear \
		$(TARGET_DIR)/etc/init.d/S50dropbear
endef

DROPBEAR_LOCALOPTIONS_FILE = $(call qstrip,$(BR2_PACKAGE_DROPBEAR_LOCALOPTIONS_FILE))
ifneq ($(DROPBEAR_LOCALOPTIONS_FILE),)
define DROPBEAR_APPEND_LOCALOPTIONS_FILE
	cat $(DROPBEAR_LOCALOPTIONS_FILE) >> $(@D)/localoptions.h
endef
DROPBEAR_POST_EXTRACT_HOOKS += DROPBEAR_APPEND_LOCALOPTIONS_FILE
endif

define DROPBEAR_INSTALL_TARGET_CMDS
	$(INSTALL) -m 755 $(@D)/dropbearmulti $(TARGET_DIR)/usr/sbin/dropbear
	for f in $(DROPBEAR_TARGET_BINS); do \
		ln -snf ../sbin/dropbear $(TARGET_DIR)/usr/bin/$$f ; \
	done
endef

$(eval $(autotools-package))
