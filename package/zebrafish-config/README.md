# `zebrafish-config`

A small Rust CLI for reading and editing the Zebrafish TOML
configuration files.

## Overview

Zebrafish stores its configuration in two TOML files:

- `<EFI>/zebrafish.toml` — placed next to the `zebrafish-kernel` image
  on the EFI system partition. Holds the `[machine]` section only,
  because it is the only configuration value that is needed before
  `/etc` is writable (it is the ZFS vault passphrase).
- `/etc/zebrafish.toml` — system-wide configuration. Available after
  `setup-persistence` runs.

This binary parses and edits those files. Every consumer in
`/etc/init.d/S*` and `/lib/zebrafish/*` calls it through thin shell
helpers (`zf_get`, `zf_has`, `zfs_get_machine_id`) defined in
`/lib/zebrafish/functions`.

## Subcommands

```
zebrafish-config get <key>           # read a single value
zebrafish-config set <key> <value>   # write a scalar value
zebrafish-config list [<section>]    # print everything (or one section)
zebrafish-config add <section>       # append to an array of tables
zebrafish-config remove <key>        # drop a section, array element, or key
zebrafish-config edit                # open the file in $EDITOR
zebrafish-config path                # print the paths to the config files
zebrafish-config validate            # syntax-check the files
```

Common flags:

```
--file <path>     # override the file to operate on
--efi             # enable EFI partition access (auto-discover and mount)
--efi-dir <path>  # override the discovered EFI directory
--quiet, --verbose
```

## Key paths

Keys use dotted notation:

```
machine.id
console.keymap
console.font
headless.enabled
rescue.enabled
hostname.name
ssh.port
ssh.keys[0]
ipv4.address
ipv4.dns[1]
ipv6.netmask
wg[0].peers[1].public_key
nbd-client[2].port
nbd-server[0].device
zfs-key[0].dataset
zfs-mount[0].name
docker-registry[0].username
```

Hyphenated top-level section names are spelled with hyphens (matching
the on-disk TOML); underscored struct fields are translated internally
so users never see the underscores.

## `list` output formats

The `list` subcommand can render the configuration in three formats:

- `toml` (default) — pretty-printed TOML.
- `json` — JSON via `serde_json`.
- `shell` — `KEY=VALUE` lines that can be `eval`'d by shell scripts.
  For arrays, indexed variables are emitted (`WG_0_NAME=...`,
  `WG_0_PEERS_0_PUBLIC_KEY=...`, plus `WG_COUNT=N`).

## Examples

Print the entire configuration:

```sh
zebrafish-config list
```

Print just the WireGuard section:

```sh
zebrafish-config list wg
```

Read a single value:

```sh
zebrafish-config get ipv4.address
```

Check whether a boolean flag is set:

```sh
zebrafish-config get --bool rescue.enabled
```

Add a new WireGuard interface:

```sh
zebrafish-config add wg
```

After adding, populate the new table with `set`:

```sh
zebrafish-config set wg[1].name wg1
zebrafish-config set wg[1].private_key "$KEY"
zebrafish-config set wg[1].address 10.0.4.2/24
zebrafish-config set wg[1].listen_port 49428
```

Edit the file by hand:

```sh
zebrafish-config edit
```

## Shell helpers

`/lib/zebrafish/functions` exposes:

| Helper                       | Purpose                                                                                        |
| :--------------------------- | :--------------------------------------------------------------------------------------------- |
| `zf_get <key>`               | Print a value, or nothing on missing. Exits non-zero on missing.                              |
| `zf_get_default <key> <dflt>` | Print a value, or `<dflt>` on missing.                                                        |
| `zf_has <key>`               | Print `true` / `false`. Always exits 0.                                                        |
| `zf_has_present <key>`       | Returns 0 if the key is present, non-zero otherwise. Useful for `[ -n "$(...) ]` patterns.    |
| `zfs_get_machine_id`         | Read `[machine].id` from the EFI file. Used by `setup-persistence`.                            |
| `zfs_efi_unmount`            | Unmount the EFI partition and clear the in-process mount state. Used by `setup-persistence`, the shutdown `rcK` script, and `upgrade`. |

## EFI mount lifecycle

The EFI system partition is mounted only on demand. During boot,
`setup-persistence` calls `zfs_get_machine_id` which uses
`zebrafish-config --efi` to mount the partition at
`/run/zebrafish/efi`, read `[machine].id`, and exits. The mount is
then dropped immediately by `setup-persistence` via `zfs_efi_unmount`.

Any later script that needs the EFI file (for example
`/lib/zebrafish/upgrade`) mounts and unmounts it on its own. The
shutdown `/etc/init.d/rcK` script calls `zfs_efi_unmount` defensively.
