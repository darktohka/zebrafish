//! End-to-end CLI tests for the write commands: `set`, `add`, `remove`.

use std::io::Write;

use assert_cmd::Command;
use tempfile::{NamedTempFile, TempDir};

fn write_temp(contents: &str) -> NamedTempFile {
    let mut f = NamedTempFile::new().expect("create temp file");
    f.write_all(contents.as_bytes()).expect("write");
    f
}

fn write_temp_in_dir(dir: &TempDir, name: &str) -> NamedTempFile {
    let path = dir.path().join(name);
    std::fs::write(&path, "").unwrap();
    NamedTempFile::new_in(dir).unwrap()
}

const INITIAL: &str = r#"
[console]
keymap = "us"
"#;

#[test]
fn set_creates_section_and_key() {
    let f = write_temp(INITIAL);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "set",
            "console.font",
            "lat1-16",
        ])
        .assert()
        .success();

    let after = std::fs::read_to_string(f.path()).unwrap();
    assert!(after.contains("font"), "missing 'font' in {after}");
    assert!(after.contains("lat1-16"), "missing 'lat1-16' in {after}");
    // Existing key should still be there.
    assert!(after.contains("keymap"));
}

#[test]
fn set_replaces_existing_value() {
    let f = write_temp(INITIAL);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "set",
            "console.keymap",
            "dk-latin1",
        ])
        .assert()
        .success();

    let after = std::fs::read_to_string(f.path()).unwrap();
    assert!(after.contains("dk-latin1"));
    assert!(!after.contains("\"us\""), "old value should be gone: {after}");
}

#[test]
fn set_writes_integer() {
    let f = write_temp(INITIAL);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "set", "ssh.port", "12488"])
        .assert()
        .success();

    let after = std::fs::read_to_string(f.path()).unwrap();
    assert!(after.contains("port = 12488"));
}

#[test]
fn set_writes_boolean() {
    let f = write_temp(INITIAL);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "set",
            "headless.enabled",
            "true",
        ])
        .assert()
        .success();

    let after = std::fs::read_to_string(f.path()).unwrap();
    assert!(after.contains("enabled = true"));
}

#[test]
fn add_creates_array_of_tables() {
    let f = write_temp("");
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "add", "wg"])
        .assert()
        .success();

    let after = std::fs::read_to_string(f.path()).unwrap();
    assert!(after.contains("[[wg]]"));
}

#[test]
fn add_appends_to_existing_array() {
    let f = write_temp(
        r#"
[[wg]]
name = "wg0"
"#,
    );
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "add", "wg"])
        .assert()
        .success();

    let after = std::fs::read_to_string(f.path()).unwrap();
    assert_eq!(after.matches("[[wg]]").count(), 2);
}

#[test]
fn remove_drops_section() {
    let f = write_temp(INITIAL);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "remove", "console"])
        .assert()
        .success();

    let after = std::fs::read_to_string(f.path()).unwrap();
    assert!(!after.contains("console"), "section should be gone: {after}");
    assert!(!after.contains("keymap"), "key should be gone: {after}");
}

#[test]
fn remove_drops_specific_key() {
    let f = write_temp(INITIAL);
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "remove",
            "console.keymap",
        ])
        .assert()
        .success();

    let after = std::fs::read_to_string(f.path()).unwrap();
    assert!(!after.contains("keymap"));
    assert!(after.contains("[console]"), "section should remain: {after}");
}

#[test]
fn round_trip_via_cli() {
    // Write some values, then read them back via `get`.
    let dir = TempDir::new().unwrap();
    let f = write_temp_in_dir(&dir, "config.toml");

    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "set",
            "console.keymap",
            "fr-latin1",
        ])
        .assert()
        .success();

    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "get", "console.keymap"])
        .assert()
        .success()
        .stdout("fr-latin1");
}

#[test]
fn set_into_array_of_tables_index() {
    let f = write_temp("");
    // Create an empty array of tables.
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "add", "wg"])
        .assert()
        .success();
    // Now set fields by index.
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "set",
            "wg[0].name",
            "wg0",
        ])
        .assert()
        .success();
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args([
            "--file",
            f.path().to_str().unwrap(),
            "set",
            "wg[0].private_key",
            "abc=",
        ])
        .assert()
        .success();

    // Read back.
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "get", "wg[0].name"])
        .assert()
        .success()
        .stdout("wg0");
}

#[test]
fn set_out_of_range_index_fails() {
    let f = write_temp("");
    Command::cargo_bin("zebrafish-config")
        .unwrap()
        .args(["--file", f.path().to_str().unwrap(), "set", "wg[5].name", "x"])
        .assert()
        .failure();
}
