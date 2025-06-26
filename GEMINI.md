# GEMINI.md

This file provides guidance to Gemini when working with code in this repository.

## Commands

This project uses Buildroot to create an immutable OCI container runtime operating system called Zebrafish.

### Configuration

To configure the build, use the `config.sh` script. You need to provide the Buildroot and Zebrafish directories, and the build type (`x64` or `aarch64`).

```bash
./buildroot-scripts/config.sh <path_to_buildroot> <path_to_zebrafish> <x64|aarch64>
```

### Build

To build the project, use the `build.sh` script. You need to provide the Buildroot and Zebrafish directories.

```bash
./buildroot-scripts/build.sh <path_to_buildroot> <path_to_zebrafish>
```

The build process uses `make` and passes the Zebrafish directory as an external Buildroot tree.

### Download sources

To download all the source code for the packages, use the `download.sh` script.

```bash
./buildroot-scripts/download.sh <path_to_buildroot> <path_to_zebrafish>
```

This will run `make source`.

### Clean

To clean the build output, use the `clean.sh` script.

```bash
./buildroot-scripts/clean.sh <path_to_buildroot> [remove_staging]
```

This will remove the `output/target` and `output/images` directories. If you provide a second argument, it will also remove the staging directory.

## Architecture

Zebrafish is an immutable OCI container runtime operating system. It is built using Buildroot.

### Packages

The `package` directory contains the definitions for all the custom packages included in Zebrafish. These packages are:
- `crony`: an NTP client.
- `dive`: a tool for exploring a docker image, layer contents, and discovering ways to shrink the size of your Docker/OCI image.
- `dnsoverhttps`: DNS over HTTPS client.
- `knockrs`: a port-knocking tool.
- `nghttp3`: HTTP/3 library.
- `ngtcp2`: a QUIC library.
- `nodeexporter`: Prometheus exporter for machine metrics.
- `opendoas`: a `doas` implementation.
- `ugrep`: a fast, user-friendly grep.
- `userlandzfs`: a ZFS implementation.
- `zfsexporter`: a ZFS exporter for Prometheus.
- `zrepl`: a one-stop, integrated solution for ZFS replication.

Each package has a `Config.in` file that describes the package configuration and a `.mk` file that contains the build instructions for the package.

### Root Filesystem Overlay

The `rootfs-overlay` directory contains files that are copied directly to the root filesystem. This includes configuration files for various services, init scripts, and other system-wide files.
