//! End-to-end CLI tests for `zebrafish-config list`.

use std::io::Write;

use assert_cmd::Command;
use tempfile::NamedTempFile;

const FULL_TOML: &str = r#"
[machine]
id = "a71d0f9a4b491ee1db858bd5ae3f3c6f"

[ssh]
port = 12488
keys = ["ssh-ed25519 AAA...", "ssh-ed25519 BBB..."]

[ipv4]
address = "10.0.0.140"

[[wg]]
name = "wg0"
private_key = "pk1"
address = "10.0.3.2/24"

[[wg.peers]]
public_key = "peer1"
allowed_ips = ["10.0.3.1/32"]
"#;

fn write_temp(contents: &str) -> NamedTempFile {
    let mut f = NamedTempFile::new().expect("create temp file");
    f.write_all(contents.as_bytes()).expect("write");
    f
}

#[test]
fn list_toml_whole_file() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "list"])
        .assert()
        .success()
        .stdout(predicates::str::contains("id = \"a71d0f9a4b491ee1db858bd5ae3f3c6f\""))
        .stdout(predicates::str::contains("port = 12488"));
}

#[test]
fn list_toml_section() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "list", "ssh"])
        .assert()
        .success()
        .stdout(predicates::str::contains("port = 12488"))
        .stdout(predicates::str::contains("ssh-ed25519 AAA"));
}

#[test]
fn list_toml_section_with_hyphen() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "list", "wg"])
        .assert()
        .success()
        .stdout(predicates::str::contains("name = \"wg0\""));
}

#[test]
fn list_json_section() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "list",
            "ssh",
            "--format",
            "json",
        ])
        .assert()
        .success()
        .stdout(predicates::str::contains("\"port\": 12488"));
}

#[test]
fn list_shell_emits_scalars() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "list",
            "ssh",
            "--format",
            "shell",
        ])
        .assert()
        .success()
        .stdout(predicates::str::contains("SSH_PORT=12488"))
        .stdout(predicates::str::contains("SSH_KEYS_COUNT=2"))
        .stdout(predicates::str::contains("SSH_KEYS_0='ssh-ed25519 AAA...'"));
}

#[test]
fn list_shell_emits_nested_arrays() {
    let f = write_temp(FULL_TOML);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "list",
            "wg",
            "--format",
            "shell",
        ])
        .assert()
        .success()
        .stdout(predicates::str::contains("WG_COUNT=1"))
        .stdout(predicates::str::contains("WG_0_NAME=wg0"))
        .stdout(predicates::str::contains("WG_0_PEERS_COUNT=1"))
        .stdout(predicates::str::contains("WG_0_PEERS_0_PUBLIC_KEY=peer1"));
}
