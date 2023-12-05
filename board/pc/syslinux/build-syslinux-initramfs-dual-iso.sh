#!/usr/bin/env bash

echo "###############  Hello, I'm your $0"
set -ex

BR2_EXTERNAL=${BR2_EXTERNAL:-$ZEBRAFISH_HOME/custom}

SRC=$(dirname $0)
CONFIG_SRC=$SRC/genimage-syslinux-initramfs-esp.cfg
#SYSLINUX_SRC=$BUILD_DIR/syslinux-6.03
SYSLINUX_SRC=$SRC/prebuilt


BASE=$BINARIES_DIR/zebrafish-syslinux-initramfs-dual-iso
ROOT=$BASE/root
TEMP=$BASE/tmp
IN=$BASE/in
OUT=$BASE/out
CONFIG=$IN/genimage.cfg
[ ! -d $BASE ] || rm -frv $BASE

mkdir -pv $ROOT $TEMP $IN $OUT


#
# Build ESP.
#
mkdir -pv $IN/esp/efi/boot $IN/esp/syslinux

cp -av $SYSLINUX_SRC/efi64/efi/syslinux.efi						$IN/esp/efi/boot/bootx64.efi

cp -av $SYSLINUX_SRC/efi64/com32/elflink/ldlinux/ldlinux.e64	$IN/esp/syslinux/
cp -av $SRC/syslinux-initramfs.cfg                              $IN/esp/syslinux/syslinux.cfg

cp -av $BINARIES_DIR/bzImage									$IN/esp/

SIZE_MB=$(( $(du -c -Sm $IN/esp | grep total | cut -f 1) + 2 ))
sed -e s,__SIZE__,${SIZE_MB}M, $CONFIG_SRC > $CONFIG

tree $BASE
cat $CONFIG

$HOST_DIR/bin/genimage \
	--rootpath $ROOT \
	--inputpath $IN \
	--outputpath $OUT \
	--tmppath $TEMP \
	--config $CONFIG

ls -lh $OUT/syslinux-initramfs-efi-esp.vfat


#
# Build ISO, embed ESP.
#

mkdir -pv $IN/iso/isolinux $IN/iso/efi

cp -av $SYSLINUX_SRC/efi64/mbr/isohd*.bin $IN/

cp -av $SYSLINUX_SRC/bios/core/isolinux.bin                     $IN/iso/isolinux/
cp -av $SYSLINUX_SRC/bios/com32/elflink/ldlinux/ldlinux.c32     $IN/iso/isolinux/
cp -av $SRC/syslinux-initramfs.cfg                              $IN/iso/isolinux/isolinux.cfg

cp -av $BINARIES_DIR/bzImage                                    $IN/esp/

cp -av $OUT/syslinux-initramfs-efi-esp.vfat $IN/iso/efi/esp.img
cp -av $BINARIES_DIR/bzImage $IN/iso/

tree $BASE

# Build image that can be booted as both CDROM and DISK image.
xorriso \
    -as mkisofs \
    -o $OUT/syslinux-initramfs-dual.iso \
    -l -J -R -V "$ZEBRAFISH_NAME $ZEBRAFISH_VERSION" -publisher "$ZEBRAFISH_PUBLISHER" \
    -isohybrid-mbr $IN/isohdpfx.bin \
    -c isolinux/boot.cat \
    -b isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e efi/esp.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -partition_cyl_align all \
    $IN/iso

cp -v $OUT/syslinux-initramfs-dual.iso $BINARIES_DIR/zebrafish-syslinux-initramfs-dual.iso
