## Installation Steps

These instructions will guide you through installing Zebrafish on a bare-metal machine from a live Linux environment (like Alpine Linux).

**Warning:** This process is destructive and will erase all data on the selected disk. Please back up any important data before proceeding.

### Step 1: Boot into a Live Environment

Boot your target machine using a live Linux USB stick. An Alpine Linux standard image is recommended as it includes the necessary tools.

### Step 2: Install Required Tools

Open a terminal and install the tools needed for the installation.

```bash
apk add curl jq parted lsblk dosfstools
```

### Step 3: Identify and Prepare the Target Disk

1.  Identify the target disk for installation. Use `lsblk` to list available block devices. Be very careful to choose the correct one.

    ```bash
    lsblk -p
    ```

    Look for your target disk in the output (e.g., `/dev/sda`, `/dev/nvme0n1`). We will refer to it as `/dev/YOUR_DISK` in the following steps.

2.  Set a shell variable for your target disk to avoid mistakes. **Replace `/dev/sda` with your actual disk.**

    ```bash
    # !! IMPORTANT !!
    # !! Set this to your target disk. All data on this disk will be erased.
    export DISK="/dev/sda"
    ```

3.  Partition the disk. We will create two partitions:

    - A 256MB boot partition (FAT32).
    - A data partition using the remaining space, which Zebrafish will format on first boot.

    ```bash
    parted -a optimal -s "$DISK" \
      mklabel gpt \
      mkpart primary 1MiB 256MiB \
      set 1 boot on \
      mkpart primary 256MiB 100% \
      print
    ```

### Step 4: Format and Mount the Boot Partition

1.  Define variables for your new partitions.

    ```bash
    # For NVMe drives, partitions look like /dev/nvme0n1p1, for SATA/SCSI, /dev/sda1
    if [[ "$DISK" == *"nvme"* ]]; then
      export BOOT_PART="${DISK}p1"
      export DATA_PART="${DISK}p2"
    else
      export BOOT_PART="${DISK}1"
      export DATA_PART="${DISK}2"
    fi
    ```

2.  Format the boot partition as FAT32.

    ```bash
    mkfs.fat "$BOOT_PART"
    ```

3.  Mount the boot partition.

    ```bash
    mount "$BOOT_PART" /mnt
    ```

### Step 5: Download and Extract Zebrafish

1.  Navigate to the mounted directory.

    ```bash
    cd /mnt
    ```

2.  Download and extract the appropriate Zebrafish release for your architecture.

    ```bash
    # For aarch64 (64-bit ARM)
    if [ "$(uname -m)" = "aarch64" ]; then
      ZEBRAFISH_LINK="https://cdn.zebrafish.tohka.us/zebrafish-aarch64.tar"
    # For x86_64 (64-bit Intel/AMD)
    else
      ZEBRAFISH_LINK="https://cdn.zebrafish.tohka.us/zebrafish-x64.tar"
    fi

    curl -sL "$ZEBRAFISH_LINK" | tar -x
    ```

### Step 6: Prepare the Data Partition

Write a placeholder string to the data partition. Zebrafish will detect this on its first boot and automatically format the partition with the ZFS file system.

```bash
echo "zebrafish-please-format-me" | dd conv=notrunc of="$DATA_PART"
```

### Step 7: Write the Zebrafish configuration

Zebrafish reads its configuration from two TOML files, both named `zebrafish.toml`:

- **`<EFI>/zebrafish.toml`** — placed next to the `zebrafish-kernel` image on the EFI system partition. Holds the `[machine]` section only, because that section is the only one needed before `/etc` is writable (it is the ZFS vault passphrase).
- **`/etc/zebrafish.toml`** — the system-wide configuration file. Available after `setup-persistence` finishes.

The kernel command line is no longer used for configuration. It only carries Linux kernel parameters (such as `initrd=` and `console=`), which you can ignore for the purposes of Zebrafish configuration.

Write a minimal `<EFI>/zebrafish.toml` with a fresh machine ID:

```bash
MACHINE_ID=$(uuidgen | tr -d -)
cat <<EOS > /mnt/zebrafish.toml
[machine]
id = "$MACHINE_ID"
EOS
```

(Replace `uuidgen` with `cat /proc/sys/kernel/random/uuid` if the live image does not provide `uuidgen`.)

Then write `/etc/zebrafish.toml` with whatever system-wide configuration you want. A common starting point is:

```toml
# /mnt/etc/zebrafish.toml

[hostname]
name = "my-server"

[ipv4]
address = "10.0.0.140"
broadcast = "10.0.0.255"
subnet = "255.255.255.0"
gateway = "10.0.0.1"
dns = ["1.1.1.1", "8.8.8.8"]

[ssh]
port = 22
keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@laptop",
]
```

The full schema is documented in `package/zebrafish-config/README.md` and includes sections for `console`, `headless`, `rescue`, `wg` (WireGuard interfaces), `nbd-client`, `nbd-server`, `zfs-key`, `zfs-mount`, and `docker-registry`. Each array-style section (`wg`, `nbd-client`, etc.) can be repeated to declare multiple instances.

### Step 8: Install the Bootloader

This step depends on whether your system uses UEFI or legacy BIOS firmware. The kernel command line below contains only Linux kernel parameters — Zebrafish does not read it for configuration.

#### For UEFI Systems

1.  Install the `efibootmgr` utility.

    ```bash
    apk add efibootmgr
    ```

2.  Create a boot entry in your firmware. This tells the system how to boot Zebrafish. The command line here is purely Linux kernel parameters (where to find the initrd and which console to use); Zebrafish ignores it for configuration.

    ```bash
    command_line="initrd=/zebrafish-initrd console=tty0"

    efibootmgr -c -d "$DISK" --part 1 --loader /zebrafish-kernel --label "Zebrafish" -u "$command_line"
    ```

#### For BIOS Systems

1.  Install the `syslinux` bootloader.

    ```bash
    apk add syslinux
    ```

2.  Create the syslinux configuration directory.

    ```bash
    mkdir /mnt/syslinux
    ```

3.  Install the syslinux bootloader files to the boot partition.

    ```bash
    extlinux --install /mnt/syslinux
    ```

4.  Write the Master Boot Record (MBR) to the disk. This makes the disk bootable.

    ```bash
    dd if=/usr/share/syslinux/gptmbr.bin of="$DISK" bs=440 count=1
    ```

5.  Create the syslinux configuration file.

    ```bash
    cat <<EOS > /mnt/syslinux/syslinux.cfg
    PROMPT 0
    TIMEOUT 10 # Timeout in tenths of a second
    DEFAULT zebrafish

    LABEL zebrafish
      LINUX /zebrafish-kernel
      APPEND initrd=/zebrafish-initrd console=tty0
    EOS
    ```

### Step 9: Finalize Installation

1.  Navigate out of the mount point.

    ```bash
    cd /
    ```

2.  Synchronize cached writes to the disk.

    ```bash
    sync
    ```

3.  Unmount the boot partition.

    ```bash
    umount /mnt
    ```

4.  The installation is complete. You can now reboot the machine.

    ```bash
    reboot
    ```

    Remove the live USB stick when the machine restarts.

Congratulations! You have successfully installed Zebrafish on your machine. On the first boot, Zebrafish will format the data partition with ZFS and set up the system. After that, you can log in and start using your new operating system using the `signalizer` user.
