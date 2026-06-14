//! `zebrafish-config remove <key>`

use std::process::ExitCode;

use anyhow::{anyhow, bail, Result};

use crate::cli::{Ctx, RemoveArgs};
use crate::path::{KeyPath, Segment};
use crate::store;

pub fn run(ctx: Ctx, args: RemoveArgs) -> ExitCode {
    match run_inner(ctx, args) {
        Ok(code) => code,
        Err(e) => {
            eprintln!("error: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn run_inner(ctx: Ctx, args: RemoveArgs) -> Result<ExitCode> {
    let key = KeyPath::parse(&args.key)
        .ok_or_else(|| anyhow!("invalid key path: {}", args.key))?;
    let section = key
        .section()
        .ok_or_else(|| anyhow!("key path must start with a section name"))?;

    if section == "machine" && ctx.file.is_some() {
        bail!("`--file` cannot be used to remove from [machine]; it is always on the EFI partition");
    }

    let path = store::target_path(section, ctx.efi_dir.as_deref(), ctx.file.as_deref(), ctx.efi)?;
    let mut doc = store::load_document(&path)?;
    remove_in_doc(&mut doc, &key)?;
    store::write_document(&path, &doc)?;
    Ok(ExitCode::SUCCESS)
}

fn remove_in_doc(doc: &mut toml_edit::DocumentMut, key: &KeyPath) -> Result<()> {
    let segments = key.segments();
    if segments.is_empty() {
        bail!("empty key path");
    }
    let (head, tail) = segments.split_first().unwrap();
    let Segment::Field(section) = head else {
        bail!("key path must start with a section name");
    };

    if tail.is_empty() {
        doc.remove(section);
        return Ok(());
    }

    let section_item = doc.get_mut(section);
    let Some(item) = section_item else {
        // Section absent; nothing to remove.
        return Ok(());
    };

    remove_in_item(item, tail)
}

fn remove_in_item(item: &mut toml_edit::Item, segments: &[Segment]) -> Result<()> {
    if segments.is_empty() {
        bail!("internal: empty segment list");
    }
    if segments.len() == 1 {
        match &segments[0] {
            Segment::Field(name) => {
                if let Some(t) = item.as_table_mut() {
                    t.remove(name);
                }
            }
            Segment::Index(i) => {
                if let Some(arr) = item.as_array_of_tables_mut() {
                    if *i < arr.len() {
                        arr.remove(*i);
                    }
                } else if let Some(arr) = item.as_array_mut() {
                    if *i < arr.len() {
                        arr.remove(*i);
                    }
                }
            }
        }
        return Ok(());
    }

    let (head, tail) = segments.split_first().unwrap();
    match head {
        Segment::Field(name) => {
            let next = match item {
                toml_edit::Item::Table(t) => t.get_mut(name),
                _ => None,
            };
            if let Some(next_item) = next {
                remove_in_item(next_item, tail)?;
            }
        }
        Segment::Index(_) => {
            bail!("nested indexing into arrays is not supported by `remove`");
        }
    }

    Ok(())
}
