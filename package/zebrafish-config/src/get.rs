//! `zebrafish-config get <key>`

use std::process::ExitCode;

use anyhow::{anyhow, bail, Result};

use crate::cli::{Ctx, GetArgs};
use crate::path::KeyPath;

pub fn run(ctx: Ctx, args: GetArgs) -> ExitCode {
    match run_inner(ctx, args) {
        Ok(code) => code,
        Err(e) => {
            eprintln!("error: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn run_inner(ctx: Ctx, args: GetArgs) -> Result<ExitCode> {
    let key = KeyPath::parse(&args.key)
        .ok_or_else(|| anyhow!("invalid key path: {}", args.key))?;

    // `get` honours `--file` unconditionally; the `[machine]`-vs-EFI
    // check is enforced by the write commands (`set`, `add`,
    // `remove`, `edit`) only.

    let cfg = if let Some(f) = ctx.file.as_deref() {
        let text = std::fs::read_to_string(f)
            .map_err(|e| anyhow!("reading {}: {e}", f.display()))?;
        crate::schema::Config::from_toml(&text)?
    } else {
        crate::load::load(ctx.efi_dir.as_deref(), false, ctx.efi)?
    };

    let value = match key.lookup(&cfg) {
        Some(v) => v,
        None => {
            if let Some(d) = args.default {
                print!("{d}");
                return Ok(ExitCode::SUCCESS);
            }
            if args.r#bool {
                return Ok(ExitCode::from(2));
            }
            return Ok(ExitCode::from(1));
        }
    };

    if args.r#bool {
        match value.as_bool() {
            Some(b) => {
                print!("{}", if b { "true" } else { "false" });
                return Ok(ExitCode::SUCCESS);
            }
            None => bail!("value at {} is not a boolean: {value}", args.key),
        }
    }

    match value {
        toml::Value::String(s) => print!("{s}"),
        toml::Value::Integer(i) => print!("{i}"),
        toml::Value::Float(f) => print!("{f}"),
        toml::Value::Boolean(b) => print!("{}", if b { "true" } else { "false" }),
        toml::Value::Datetime(dt) => print!("{dt}"),
        toml::Value::Array(_) | toml::Value::Table(_) => {
            print!("{}", value);
        }
    }

    Ok(ExitCode::SUCCESS)
}
