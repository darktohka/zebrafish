//! Atomic read-modify-write helpers for a single TOML file.

use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use toml_edit::DocumentMut;

use crate::efi;

/// Decide which file a given `set` / `add` / `remove` / `edit` should
/// target.
///
/// Returns the resolved path. `[machine]` is always written to the EFI
/// file; everything else is written to `/etc/zebrafish.toml`.
pub fn target_path(
    section: &str,
    efi_dir_override: Option<&Path>,
    explicit: Option<&Path>,
) -> Result<PathBuf> {
    if let Some(p) = explicit {
        return Ok(p.to_path_buf());
    }

    if section == "machine" {
        let efi_dir = match efi_dir_override {
            Some(d) => d.to_path_buf(),
            None => efi::discover_efi_dir()?,
        };
        Ok(crate::path::machine_file(&efi_dir))
    } else {
        Ok(PathBuf::from(crate::path::SYSTEM_FILE))
    }
}

/// Load a TOML document, returning an empty document if the file does
/// not exist.
pub fn load_document(path: &Path) -> Result<DocumentMut> {
    match std::fs::read_to_string(path) {
        Ok(s) => Ok(s.parse::<DocumentMut>()?),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(DocumentMut::new()),
        Err(e) => Err(e).with_context(|| format!("reading {}", path.display())),
    }
}

/// Atomically write a TOML document to a file: write to `<path>.tmp`,
/// then rename. Ensures that a crash during write cannot leave a
/// half-written file.
pub fn write_document(path: &Path, doc: &DocumentMut) -> Result<()> {
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("creating {}", parent.display()))?;
        }
    }
    let tmp = path.with_extension("toml.tmp");
    std::fs::write(&tmp, doc.to_string())
        .with_context(|| format!("writing {}", tmp.display()))?;
    std::fs::rename(&tmp, path)
        .with_context(|| format!("renaming {} to {}", tmp.display(), path.display()))?;
    Ok(())
}
