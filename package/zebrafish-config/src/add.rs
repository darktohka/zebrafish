//! `zebrafish-config add <section>`

use std::process::ExitCode;

use anyhow::{anyhow, bail, Result};
use toml_edit::ArrayOfTables;

use crate::cli::{AddArgs, Ctx};
use crate::store;

pub fn run(ctx: Ctx, args: AddArgs) -> ExitCode {
    match add_inner(ctx, &args) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("error: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn add_inner(ctx: Ctx, args: &AddArgs) -> Result<()> {
    let section = &args.section;
    if section == "machine" {
        bail!("cannot `add` to [machine]; it is a single-value section");
    }

    let path = store::target_path(section, ctx.efi_dir.as_deref(), ctx.file.as_deref())?;
    let mut doc = store::load_document(&path)?;

    let item = doc
        .entry(section)
        .or_insert(toml_edit::Item::ArrayOfTables(ArrayOfTables::new()));
    let arr = item
        .as_array_of_tables_mut()
        .ok_or_else(|| anyhow!("{section} exists but is not an array of tables"))?;
    arr.push(toml_edit::Table::new());

    store::write_document(&path, &doc)?;
    Ok(())
}
