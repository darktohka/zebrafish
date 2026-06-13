//! Serde types matching the Zebrafish TOML schema.
//!
//! See `TOML_CONFIG_PLAN.md` §3 for the canonical schema.

use serde::{Deserialize, Serialize};

/// Top-level configuration object. Mirrors the on-disk TOML file.
#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Config {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub machine: Option<Machine>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub console: Option<Console>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub headless: Option<Flag>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rescue: Option<Flag>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub hostname: Option<Hostname>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ssh: Option<Ssh>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ipv4: Option<IpConfig>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ipv6: Option<IpConfig>,

    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub wg: Vec<WireGuardInterface>,

    #[serde(
        rename = "wg-server",
        default,
        skip_serializing_if = "Vec::is_empty"
    )]
    pub wg_server: Vec<WireGuardInterface>,

    #[serde(
        rename = "nbd-client",
        default,
        skip_serializing_if = "Vec::is_empty"
    )]
    pub nbd_client: Vec<NbdClient>,

    #[serde(
        rename = "nbd-server",
        default,
        skip_serializing_if = "Vec::is_empty"
    )]
    pub nbd_server: Vec<NbdServer>,

    #[serde(
        rename = "zfs-key",
        default,
        skip_serializing_if = "Vec::is_empty"
    )]
    pub zfs_key: Vec<ZfsKey>,

    #[serde(
        rename = "zfs-mount",
        default,
        skip_serializing_if = "Vec::is_empty"
    )]
    pub zfs_mount: Vec<ZfsMount>,

    #[serde(
        rename = "docker-registry",
        default,
        skip_serializing_if = "Vec::is_empty"
    )]
    pub docker_registry: Vec<DockerRegistry>,
}

/// `[machine]` — only present in the EFI-resident `zebrafish.toml`.
#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Machine {
    pub id: String,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Console {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub keymap: Option<String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub font: Option<String>,
}

/// A boolean flag. Presence implies `enabled = true`; absence implies `false`.
#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Flag {
    #[serde(default)]
    pub enabled: bool,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Hostname {
    pub name: String,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Ssh {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub port: Option<u16>,

    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub keys: Vec<String>,
}

/// Shared struct for `[ipv4]` and `[ipv6]`.
///
/// For IPv4, `subnet` is a dotted netmask string ("255.255.255.0").
/// For IPv6, `netmask` is a numeric prefix length (0..=128).
/// Each struct instance only uses one of the two.
#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct IpConfig {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub address: Option<String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub broadcast: Option<String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub subnet: Option<String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub netmask: Option<u8>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub gateway: Option<String>,

    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub dns: Vec<String>,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct WireGuardInterface {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub private_key: Option<String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub address: Option<String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub listen_port: Option<u16>,

    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub peers: Vec<WireGuardPeer>,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct WireGuardPeer {
    pub public_key: String,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub endpoint: Option<String>,

    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub allowed_ips: Vec<String>,

    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub persistent_keepalive: Option<u16>,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct NbdClient {
    pub address: String,
    pub port: u16,
    pub device: String,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct NbdServer {
    pub address: String,
    pub device: String,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ZfsKey {
    pub dataset: String,
    pub key: String,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ZfsMount {
    pub name: String,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DockerRegistry {
    pub hostname: String,
    pub username: String,
    pub password: String,
}

impl Config {
    /// Parse a configuration from a TOML string.
    pub fn from_toml(s: &str) -> Result<Self, toml::de::Error> {
        toml::from_str(s)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const FULL_TOML: &str = r#"
[machine]
id = "a71d0f9a4b491ee1db858bd5ae3f3c6f"

[console]
keymap = "dk-latin1"
font = "lat1-16"

[headless]
enabled = true

[rescue]
enabled = true

[hostname]
name = "triton-srv"

[ssh]
port = 12488
keys = ["ssh-ed25519 AAA... user@laptop", "ssh-ed25519 AAA... phone@mobi"]

[ipv4]
address = "10.0.0.140"
broadcast = "10.0.0.255"
subnet = "255.255.255.0"
gateway = "10.0.0.1"
dns = ["1.1.1.1", "8.8.8.8"]

[ipv6]
address = "2603:c020:800d::14"
netmask = 64
gateway = "2603:c020:800d::1"
dns = ["2606:4700:4700::1111"]

[[wg]]
name = "wg0"
private_key = "WEPJ...s1E="
address = "10.0.3.2/24"
listen_port = 49427

[[wg.peers]]
public_key = "dJG2...5Bw="
endpoint = "88.99.163.115:49427"
allowed_ips = ["10.0.3.1/32"]
persistent_keepalive = 25

[[wg.peers]]
public_key = "peer2...="
allowed_ips = ["10.0.3.3/32"]

[[wg-server]]
name = "wg-in"
private_key = "WEPJ...s1E="
address = "10.0.4.1/24"
listen_port = 49427

[[wg-server.peers]]
public_key = "client...="
allowed_ips = ["10.0.4.2/32"]

[[nbd-client]]
address = "10.0.3.1"
port = 4284
device = "/dev/nbd0"

[[nbd-server]]
address = "10.0.4.1"
device = "/dev/nbd1"

[[zfs-key]]
dataset = "archangel/vault"
key = "1d42...ff58"

[[zfs-mount]]
name = "archangel"

[[docker-registry]]
hostname = "registry.tohka.us"
username = "triton"
password = "a94d...7cb"
"#;

    #[test]
    fn parses_full_toml() {
        let cfg: Config = toml::from_str(FULL_TOML).unwrap();

        assert_eq!(
            cfg.machine.as_ref().map(|m| m.id.as_str()),
            Some("a71d0f9a4b491ee1db858bd5ae3f3c6f")
        );
        assert_eq!(
            cfg.console.as_ref().and_then(|c| c.keymap.as_deref()),
            Some("dk-latin1")
        );
        assert_eq!(cfg.headless.as_ref().map(|f| f.enabled), Some(true));
        assert_eq!(cfg.rescue.as_ref().map(|f| f.enabled), Some(true));
        assert_eq!(
            cfg.hostname.as_ref().map(|h| h.name.as_str()),
            Some("triton-srv")
        );

        let ssh = cfg.ssh.as_ref().unwrap();
        assert_eq!(ssh.port, Some(12488));
        assert_eq!(ssh.keys.len(), 2);

        let ipv4 = cfg.ipv4.as_ref().unwrap();
        assert_eq!(ipv4.address.as_deref(), Some("10.0.0.140"));
        assert_eq!(ipv4.dns, vec!["1.1.1.1", "8.8.8.8"]);

        let ipv6 = cfg.ipv6.as_ref().unwrap();
        assert_eq!(ipv6.netmask, Some(64));
        assert_eq!(ipv6.dns, vec!["2606:4700:4700::1111"]);

        assert_eq!(cfg.wg.len(), 1);
        let wg0 = &cfg.wg[0];
        assert_eq!(wg0.name.as_deref(), Some("wg0"));
        assert_eq!(wg0.listen_port, Some(49427));
        assert_eq!(wg0.peers.len(), 2);
        assert_eq!(wg0.peers[0].public_key, "dJG2...5Bw=");
        assert_eq!(wg0.peers[0].allowed_ips, vec!["10.0.3.1/32"]);

        assert_eq!(cfg.wg_server.len(), 1);
        assert_eq!(cfg.wg_server[0].name.as_deref(), Some("wg-in"));

        assert_eq!(cfg.nbd_client.len(), 1);
        assert_eq!(cfg.nbd_client[0].device, "/dev/nbd0");

        assert_eq!(cfg.nbd_server.len(), 1);
        assert_eq!(cfg.nbd_server[0].device, "/dev/nbd1");

        assert_eq!(cfg.zfs_key.len(), 1);
        assert_eq!(cfg.zfs_key[0].dataset, "archangel/vault");

        assert_eq!(cfg.zfs_mount.len(), 1);
        assert_eq!(cfg.zfs_mount[0].name, "archangel");

        assert_eq!(cfg.docker_registry.len(), 1);
        assert_eq!(cfg.docker_registry[0].hostname, "registry.tohka.us");
    }

    #[test]
    fn empty_toml_yields_default() {
        let cfg: Config = toml::from_str("").unwrap();
        assert_eq!(cfg, Config::default());
    }

    #[test]
    fn roundtrips_full_toml() {
        let cfg: Config = toml::from_str(FULL_TOML).unwrap();
        let serialised = toml::to_string_pretty(&cfg).unwrap();
        let cfg2: Config = toml::from_str(&serialised).unwrap();
        assert_eq!(cfg, cfg2);
    }
}
