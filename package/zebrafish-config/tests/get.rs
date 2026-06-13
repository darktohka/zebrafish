//! End-to-end CLI tests for `zebrafish-config get`.

use std::io::Write;

use assert_cmd::Command;
use tempfile::NamedTempFile;

const FULL_TOML: &str = r#"
[machine]
id = "a71d0f9a4b491ee1db858bd5ae3f3c6f"

[console]
keymap = "dk-latin1"
font = "lat1-16"

[headless]
enabled = true

[rescue]
enabled = false

[hostname]
name = "triton-srv"

[ssh]
port = 12488
keys = ["ssh-ed25519 AAA... user@laptop", "ssh-ed25519 BBB... phone@mobi"]

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

[[wg]]
name = "wg0"
private_key = "WEPJ...s1E="
address = "10.0.3.2/24"
listen_port = 49427

[[wg.peers]]
public_key = "peer1pk"
allowed_ips = ["10.0.3.1/32"]
persistent_keepalive = 25

[[wg.peers]]
public_key = "peer2pk"
allowed_ips = ["10.0.3.3/32"]

[[nbd-client]]
address = "10.0.3.1"
port = 4284
device = "/dev/nbd0"

[[docker-registry]]
hostname = "registry.tohka.us"
username = "triton"
password = "secret"
"#;

fn write_temp(contents: &str) -> NamedTempFile {
    let mut f = NamedTempFile::new().expect("create temp file");
    f.write_all(contents.as_bytes()).expect("write");
    f
}

#[test]
fn get_scalar_string() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "get", "machine.id"])
        .assert()
        .success()
        .stdout("a71d0f9a4b491ee1db858bd5ae3f3c6f");
}

#[test]
fn get_scalar_integer() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "get", "ssh.port"])
        .assert()
        .success()
        .stdout("12488");
}

#[test]
fn get_indexed_array() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "get",
            "ssh.keys[1]",
        ])
        .assert()
        .success()
        .stdout("ssh-ed25519 BBB... phone@mobi");
}

#[test]
fn get_nested_path() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "get",
            "wg[0].peers[1].public_key",
        ])
        .assert()
        .success()
        .stdout("peer2pk");
}

#[test]
fn get_hyphenated_section() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "get", "nbd-client[0].device"])
        .assert()
        .success()
        .stdout("/dev/nbd0");
}

#[test]
fn get_missing_key_exits_nonzero() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "get", "missing.key"])
        .assert()
        .failure()
        .code(1);
}

#[test]
fn get_with_default_prints_default() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "get",
            "missing.key",
            "--default",
            "fallback",
        ])
        .assert()
        .success()
        .stdout("fallback");
}

#[test]
fn get_bool_true() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "get", "--bool", "headless.enabled"])
        .assert()
        .success()
        .stdout("true");
}

#[test]
fn get_bool_false() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "get", "--bool", "rescue.enabled"])
        .assert()
        .success()
        .stdout("false");
}

#[test]
fn get_bool_missing_exits_2() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "get",
            "--bool",
            "missing.flag",
        ])
        .assert()
        .failure()
        .code(2);
}
