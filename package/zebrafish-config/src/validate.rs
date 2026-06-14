//! `zebrafish-config validate`

use std::process::ExitCode;

use anyhow::{bail, Result};

use crate::cli::{Ctx, ValidateArgs};
use crate::load;

pub fn run(ctx: Ctx, args: ValidateArgs) -> ExitCode {
    match run_inner(ctx, args) {
        Ok(code) => code,
        Err(e) => {
            eprintln!("error: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn run_inner(ctx: Ctx, args: ValidateArgs) -> Result<ExitCode> {
    if let Some(f) = ctx.file.as_deref() {
        let text = std::fs::read_to_string(f)?;
        let cfg: crate::schema::Config = toml::from_str(&text)?;
        validate_required(&cfg)?;
        return Ok(ExitCode::SUCCESS);
    }

    if args.machine {
        let cfg = load::load(ctx.efi_dir.as_deref(), true, ctx.efi)?;
        // For the machine file, only `[machine]` is allowed; require
        // `id` to be present.
        let m = cfg.machine.as_ref().ok_or_else(|| {
            anyhow::anyhow!("EFI-resident zebrafish.toml must contain a [machine] section")
        })?;
        if m.id.is_empty() {
            bail!("[machine].id is required in the EFI-resident zebrafish.toml");
        }
        return Ok(ExitCode::SUCCESS);
    }
    if args.system {
        let text = std::fs::read_to_string(crate::path::SYSTEM_FILE)
            .unwrap_or_default();
        let cfg: crate::schema::Config = toml::from_str(&text)?;
        validate_required(&cfg)?;
        return Ok(ExitCode::SUCCESS);
    }

    // Both files: load merged, then check the machine file's
    // requirement separately.
    let cfg = load::load(ctx.efi_dir.as_deref(), false, ctx.efi)?;
    validate_required(&cfg)?;
    Ok(ExitCode::SUCCESS)
}

fn validate_required(cfg: &crate::schema::Config) -> Result<()> {
    let m = cfg.machine.as_ref().ok_or_else(|| {
        anyhow::anyhow!("[machine] section is required (lives on the EFI partition)")
    })?;
    if m.id.is_empty() {
        bail!("[machine].id is required");
    }
    Ok(())
}
