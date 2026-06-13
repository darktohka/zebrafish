//! `zebrafish-config edit`

use std::env;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, ExitCode};

use anyhow::{Context, Result};

use crate::cli::{Ctx, EditArgs};
use crate::efi;
use crate::path as pf;
use crate::store;

pub fn run(ctx: Ctx, _args: EditArgs) -> ExitCode {
    match run_inner(ctx) {
        Ok(code) => code,
        Err(e) => {
            eprintln!("error: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn run_inner(ctx: Ctx) -> Result<ExitCode> {
    let path: PathBuf = match ctx.file.clone() {
        Some(f) => f,
        None => PathBuf::from(pf::SYSTEM_FILE),
    };
    // Make sure the file exists before launching the editor.
    if !path.exists() {
        // Try to ensure the parent dir exists, and create an empty file.
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("creating {}", parent.display()))?;
        }
        std::fs::write(&path, "").with_context(|| format!("creating {}", path.display()))?;
    }

    let editor = env::var("EDITOR").unwrap_or_else(|_| "nano".to_string());
    let status = Command::new(&editor)
        .arg(&path)
        .status()
        .with_context(|| format!("running editor {editor}"))?;

    if !status.success() {
        // Don't lose the editor's exit code, but don't validate either.
        return Ok(ExitCode::from(status.code().unwrap_or(1) as u8));
    }

    // After editing, validate the file we just wrote.
    let _ = store::load_document(&path)?;
    let _ = efi::discover_efi_dir().ok();

    Ok(ExitCode::SUCCESS)
}
