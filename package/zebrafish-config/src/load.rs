//! Loading and merging the two configuration files.
//!
//! The system configuration lives at `/etc/zebrafish.toml` (always
//! available after `setup-persistence` runs). The machine configuration
//! lives next to `zebrafish-kernel` on the EFI partition and is only
//! available after the EFI partition has been mounted.

use std::path::{Path, PathBuf};

use anyhow::{Context, Result};

use crate::efi;
use crate::schema::Config;

/// Return the resolved paths to (system, machine) configuration files.
///
/// `efi_dir_override` lets the caller skip the discovery step (e.g. when
/// running inside a unit test or when the operator passes `--efi-dir`).
/// `efi` controls whether auto-discovery (mounting the EFI partition) is
/// attempted when no explicit override is given.
pub fn resolve_paths(
    efi_dir_override: Option<&Path>,
    machine_only: bool,
    efi: bool,
) -> Result<(Option<PathBuf>, Option<PathBuf>)> {
    let system = if machine_only {
        None
    } else {
        Some(PathBuf::from(crate::path::SYSTEM_FILE))
    };

    let machine = match efi_dir_override {
        Some(d) => Some(crate::path::machine_file(d)),
        None if efi => match efi::discover_efi_dir() {
            Ok(d) => Some(crate::path::machine_file(&d)),
            Err(_) => None,
        },
        None => None,
    };

    Ok((system, machine))
}

/// Load both configuration files and merge them.
///
/// The machine file is loaded first, then the system file overrides on a
/// per-key basis (we use serde's `Deserialize` on the merged string, so
/// later occurrences of the same key win).
pub fn load(efi_dir_override: Option<&Path>, machine_only: bool, efi: bool) -> Result<Config> {
    let (system, machine) = resolve_paths(efi_dir_override, machine_only, efi)?;
    load_from_paths(system.as_deref(), machine.as_deref())
}

/// Load and merge configuration from explicit paths. Missing files are
/// treated as empty.
pub fn load_from_paths(system: Option<&Path>, machine: Option<&Path>) -> Result<Config> {
    let machine_text = match machine {
        Some(p) => read_optional(p)?,
        None => String::new(),
    };
    let system_text = match system {
        Some(p) => read_optional(p)?,
        None => String::new(),
    };

    // The machine file declares `[machine]`, the system file declares
    // everything else. We concatenate them and let toml::from_str parse
    // the result; the two halves must be disjoint in their top-level
    // keys, which is enforced by the schema.
    let combined = format!("{machine_text}\n{system_text}");
    Ok(Config::from_toml(&combined)?)
}

fn read_optional(path: &Path) -> Result<String> {
    match std::fs::read_to_string(path) {
        Ok(s) => Ok(s),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(String::new()),
        Err(e) => Err(e).with_context(|| format!("reading {}", path.display())),
    }
}
