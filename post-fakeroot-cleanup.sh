#!/bin/sh

echo "Hi, I'm $(basename $0)!"

# Create missing folders
mkdir -p "$TARGET_DIR"/srv
mkdir -p "$TARGET_DIR"/vol

# Create symlinks for oci tools
for tool in containerd docker; do
    rm -f "$TARGET_DIR"/var/lib/"$tool"
    ln -s /oci/"$tool" "$TARGET_DIR"/var/lib/"$tool"
done

# Create symlinks for libarchive
for cattype in bzcat xzcat; do
  rm -f "$TARGET_DIR"/bin/"$cattype"
  ln -s /usr/bin/bsdcat "$TARGET_DIR"/bin/"$cattype"
done

rm -f "$TARGET_DIR"/bin/tar
ln -s /usr/bin/bsdtar "$TARGET_DIR"/bin/tar

rm -f "$TARGET_DIR"/bin/cpio
ln -s /usr/bin/bsdcpio "$TARGET_DIR"/bin/cpio

rm -f "$TARGET_DIR"/usr/bin/unzip
ln -s /usr/bin/bsdunzip "$TARGET_DIR"/usr/bin/unzip

# Use nftables backend for iptables
rm -f "$TARGET_DIR"/usr/sbin/iptables
ln -s xtables-nft-multi "$TARGET_DIR"/usr/sbin/iptables

# Set doas permissions
if [ "$EUID" -ne 0 ]; then
    chmod 4755 "$TARGET_DIR"/usr/bin/doas
    chown 0:0 "$TARGET_DIR"/usr/bin/doas
else
    sudo chmod 4755 "$TARGET_DIR"/usr/bin/doas
    sudo chown 0:0 "$TARGET_DIR"/usr/bin/doas
fi

# Create symlink for Docker config
ln -s /etc/docker "$TARGET_DIR"/root/.docker

# Cleanup unused files that are installed by Buildroot.
rm -frv "$TARGET_DIR"/media
rm -frv "$TARGET_DIR"/boot
rm -frv "$TARGET_DIR"/opt
rm -frv "$TARGET_DIR"/usr/libexec/lzo
rm -frv "$TARGET_DIR"/etc/init.d/fuse3

rm -fr "$TARGET_DIR"/usr/share/pixmaps
rm -fr "$TARGET_DIR"/usr/share/icons
rm -fr "$TARGET_DIR"/usr/share/applications
rm -fr "$TARGET_DIR"/usr/share/et
rm -fr "$TARGET_DIR"/usr/share/gvfs
rm -fr "$TARGET_DIR"/usr/share/bash-completion

rm -fr "$TARGET_DIR"/usr/lib/gio
rm -fr "$TARGET_DIR"/usr/lib/gvfs
rm -fr "$TARGET_DIR"/usr/lib/xfsprogs
rm -fr "$TARGET_DIR"/usr/lib/gconv
rm -fr "$TARGET_DIR"/usr/lib/dracut

rm -f "$TARGET_DIR"/usr/bin/sftp

rm -frv "$TARGET_DIR"/sbin/ldconfig

rm -frv "$TARGET_DIR"/usr/sbin/unbound-*

for git in git-cvsserver git-receive-pack git-shell git-upload-archive git-upload-pack scalar; do
    rm -frv "$TARGET_DIR"/usr/bin/$git
done
rm -fr "$TARGET_DIR"/usr/share/gitweb
rm -fr "$TARGET_DIR"/usr/share/zfs
rm -fr "$TARGET_DIR"/etc/zfs
rm -fr "$TARGET_DIR"/usr/share/initramfs-tools
rm -fr "$TARGET_DIR"/usr/share/glib-2.0
rm -fr "$TARGET_DIR"/usr/src

for sudo in bin/cvtsudoers bin/sudoreplay bin/sudoedit sbin/sudo_logsrvd sbin/sudo_sendlog; do
    rm -frv "$TARGET_DIR"/usr/$sudo
done

for kbd in loadunimap dumpkeys; do
    rm -frv "$TARGET_DIR"/usr/bin/$kbd
done

for gapp in gapplication gsettings gresource gio gio-querymodules; do
    rm -frv "$TARGET_DIR"/usr/bin/$gapp
done
rm -frv "$TARGET_DIR"/usr/share/GConf

for keymap in amiga atari mac sun ppc pine \
    i386/oldpc i386/neo i386/fgGIod i386/colemap i386/carpalx i386/dvorak "i386/qwerty/ru*"
do
    rm -frv "$TARGET_DIR"/usr/share/keymaps/$keymap
done
