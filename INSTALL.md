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

### Step 7: Setup the Kernel Command Line

The kernel command line is a crucial part of the Zebrafish boot process. It passes a series of arguments to the kernel to configure the system, network, storage, and other services before the main operating system takes over. Below is a detailed breakdown of the available parameters.

An example command line might look like this:

```
initrd=/zebrafish-initrd console=tty0 hostname=my-server machine=a71d0f9a4b491ee1db858bd5ae3f3c6f ipv4=10.0.0.140 ipv4gateway=10.0.0.1 sshkey="ssh-ed25519 AAA..."
```

### Kernel Command Line Parameters

| Parameter       | Description                                                                           | Example                                         | Required/Optional |
| :-------------- | :------------------------------------------------------------------------------------ | :---------------------------------------------- | :---------------- |
| `initrd`        | Specifies the path to the initial RAM disk image.                                     | `/zebrafish-initrd`                             | **Required**      |
| `console`       | Sets the system console for kernel messages.                                          | `tty0`                                          | **Required**      |
| `hostname`      | Defines the hostname of the machine.                                                  | `triton-srv`                                    | **Required**      |
| `machine`       | A unique machine identifier, typically a UUID or a hash.                              | `a71d0f9a4b491ee1db858bd5ae3f3c6f...`           | **Required**      |
| `ipv4`          | Assigns a static IPv4 address to the primary network interface.                       | `10.0.0.140`                                    | Optional          |
| `ipv4dns`       | Specifies one or more DNS servers for IPv4 networking, separated by commas.           | `8.8.8.8,8.8.4.4`                               | Optional          |
| `ipv4broadcast` | Sets the broadcast address for the IPv4 network interface.                            | `10.0.0.255`                                    | Optional          |
| `ipv4subnet`    | Defines the subnet mask for the IPv4 network interface.                               | `255.255.255.0`                                 | Optional          |
| `ipv4gateway`   | Sets the default gateway for the IPv4 network.                                        | `10.0.0.1`                                      | Optional          |
| `ipv6`          | Assigns a static IPv6 address.                                                        | `2603:c020:800d::14`                            | Optional          |
| `ipv6dns`       | Specifies one or more DNS servers for IPv6 networking, separated by commas.           | `2001:4860:4860::8888,2001:4860:4860::8844`     | Optional          |
| `ipv6netmask`   | Defines the subnet mask or prefix length for the IPv6 network interface.              | `64`                                            | Optional          |
| `ipv6gateway`   | Sets the default gateway for the IPv6 network.                                        | `2603:c020:800d::1`                             | Optional          |
| `sshport`       | Specifies the port for the SSH server to listen on.                                   | `12488`                                         | Optional          |
| `sshkey`        | Provides a public SSH key for remote authentication.                                  | `"ssh-ed25519 AAA..."`                          | Optional          |
| `wg0`           | Configures a WireGuard interface. Format: `private_key,address/cidr,listen_port`.     | `"WEPJ...s1E=,10.0.3.2/24,49427"`               | Optional          |
| `wg0peer`       | Configures a WireGuard peer. Format: `public_key,endpoint_ip:port,allowed_ips/cidr`.  | `"dJG2...5Bw=,88.99.163.115:49427,10.0.3.1/32"` | Optional          |
| `nbdclient`     | Configures a Network Block Device (NBD) client. Format: `server_ip,port,/dev/nbd0`.   | `"10.0.3.1,4284,/dev/nbd0"`                     | Optional          |
| `zfskeys`       | Provides keys to unlock encrypted ZFS datasets. Format: `dataset,key`.                | `"archangel/vault,1d42...ff58"`                 | Optional          |
| `zfsmount`      | Specifies the ZFS dataset to mount as the root filesystem.                            | `archangel`                                     | Optional          |
| `dockerlogin`   | Provides credentials for a Docker registry. Format: `registry.example.com,user,pass`. | `"registry.tohka.us,triton,a94d...7cb"`         | Optional          |

#### Encryption

The **machine** parameter is particularly important as it encrypts the ZFS root dataset and is used to identify the machine in the network. It should be unique for each installation.

#### Network Configuration

The **ipv4** and **ipv6** parameters are required for network configuration. If not specified, Zebrafish will disable the relevant network interface.

#### SSH

The **sshport** and **sshkey** parameters are used to configure the SSH server. The `sshport` parameter specifies the port on which the SSH server will listen, while the `sshkey` parameter provides public SSH keys for secure access.

#### WireGuard

The **wg0** and **wg0peer** parameters are used to configure a WireGuard interface and its peer. This is useful for secure point-to-point connections.

If you do not need WireGuard, you can omit these parameters.

If you have more than one WireGuard interface, you can add additional parameters like `wg1`, `wg1peer`, etc. It's possible to configure multiple WireGuard peers using the `;` delimiter.

#### NBD Client

The **nbdclient** parameter allows Zebrafish to connect to a remote disk using the Network Block Device (NBD) protocol. This is useful for accessing remote storage from another server, akin to NFS.

#### ZFS Keys

The **zfskeys** parameter is used to provide keys for unlocking encrypted ZFS datasets. This is particularly useful if you have multiple encrypted datasets that need to be unlocked at boot time, perhaps mounted from a remote server.

#### Docker Login

The **dockerlogin** parameter allows Zebrafish to authenticate with a Docker registry. This is useful for pulling container images from a private registry.

1. Write the command line to the `/mnt/cmdline.txt` file.

   ````bash
   cat <<EOS > /mnt/cmdline.txt
   initrd=/zebrafish-initrd console=tty0 hostname=my-server machine=a71d0f9a4b491ee1db858bd5ae3f3c6f ipv4=...
   EOS```
   ````

### Step 8: Install the Bootloader

This step depends on whether your system uses UEFI or legacy BIOS firmware.

#### For UEFI Systems

1.  Install the `efibootmgr` utility.

    ```bash
    apk add efibootmgr
    ```

2.  Create a boot entry in your firmware. This tells the system how to boot Zebrafish.

    ```bash
    # Read the required kernel command line arguments from the extracted file
    command_line="$(cat /mnt/cmdline.txt)"

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
    # Read the required kernel command line arguments from the extracted file
    command_line="$(cat /mnt/cmdline.txt)"

    cat <<EOS > /mnt/syslinux/syslinux.cfg
    PROMPT 0
    TIMEOUT 10 # Timeout in tenths of a second
    DEFAULT zebrafish

    LABEL zebrafish
      LINUX /zebrafish-kernel
      APPEND $command_line
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
