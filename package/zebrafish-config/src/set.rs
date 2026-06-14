//! `zebrafish-config set <key> <value>`

use std::process::ExitCode;

use anyhow::{anyhow, bail, Result};
use toml_edit::Value;

use crate::cli::{Ctx, SetArgs};
use crate::path::{KeyPath, Segment};
use crate::store;

pub fn run(ctx: Ctx, args: SetArgs) -> ExitCode {
    match run_inner(ctx, args) {
        Ok(code) => code,
        Err(e) => {
            eprintln!("error: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn run_inner(ctx: Ctx, args: SetArgs) -> Result<ExitCode> {
    let key = KeyPath::parse(&args.key)
        .ok_or_else(|| anyhow!("invalid key path: {}", args.key))?;

    let section = key
        .section()
        .ok_or_else(|| anyhow!("key path must start with a section name"))?;

    if section == "machine" && ctx.file.is_some() {
        bail!("`--file` cannot be used to write [machine]; it is always on the EFI partition");
    }

    let path = store::target_path(section, ctx.efi_dir.as_deref(), ctx.file.as_deref(), ctx.efi)?;
    let mut doc = store::load_document(&path)?;
    apply_set(&mut doc, &key, &args.value)?;
    store::write_document(&path, &doc)?;
    Ok(ExitCode::SUCCESS)
}

fn apply_set(doc: &mut toml_edit::DocumentMut, key: &KeyPath, raw: &str) -> Result<()> {
    let parsed = parse_value(raw);
    let segments = key.segments();
    if segments.is_empty() {
        bail!("empty key path");
    }
    let (head, tail) = segments.split_first().unwrap();
    let Segment::Field(section) = head else {
        bail!("key path must start with a section name");
    };

    // If the section is supposed to be a plain table (e.g. `[machine]`,
    // `[console]`, `[ipv4]`, etc.) we just look it up directly.
    // If the section is supposed to be an array of tables (e.g.
    // `[[wg]]`, `[[nbd-client]]`) the first `tail` segment may be an
    // `Index`. We dispatch based on whether the existing section is
    // an array or a table.
    let (target, rest) = match tail.first() {
        Some(Segment::Index(_)) => {
            // We need an array of tables.
            ensure_array_of_tables(doc, section)?;
            let arr = doc[section].as_array_of_tables_mut().unwrap();
            let Segment::Index(i) = &tail[0] else { unreachable!() };
            if *i >= arr.len() {
                bail!("index {i} out of range for [{section}] (length {})", arr.len());
            }
            (arr.get_mut(*i).unwrap(), &tail[1..])
        }
        _ => {
            // We need a plain table.
            ensure_table(doc, section)?;
            (doc[section].as_table_mut().unwrap(), tail)
        }
    };

    set_in_table(target, rest, parsed)?;
    Ok(())
}

fn ensure_table(doc: &mut toml_edit::DocumentMut, section: &str) -> Result<()> {
    if !doc.contains_key(section) {
        doc[section] = toml_edit::Item::Table(toml_edit::Table::new());
        return Ok(());
    }
    let item = doc.get(section).unwrap();
    if !item.is_table() {
        bail!("{section} exists but is not a table");
    }
    Ok(())
}

fn ensure_array_of_tables(doc: &mut toml_edit::DocumentMut, section: &str) -> Result<()> {
    use toml_edit::ArrayOfTables;
    if !doc.contains_key(section) {
        doc[section] = toml_edit::Item::ArrayOfTables(ArrayOfTables::new());
        return Ok(());
    }
    let item = doc.get(section).unwrap();
    if !item.is_array_of_tables() {
        bail!("{section} exists but is not an array of tables");
    }
    Ok(())
}

fn set_in_table(
    table: &mut toml_edit::Table,
    segments: &[Segment],
    parsed: Value,
) -> Result<()> {
    if segments.is_empty() {
        bail!("internal: empty segment list");
    }
    if segments.len() == 1 {
        let Segment::Field(name) = &segments[0] else {
            bail!("cannot assign a value to an array index");
        };
        table.insert(name, toml_edit::Item::Value(parsed));
        return Ok(());
    }

    let (head, tail) = segments.split_first().unwrap();
    match head {
        Segment::Field(name) => {
            let next = if table.contains_key(name) {
                let existing = table.get_mut(name).unwrap();
                if existing.is_table() {
                    existing.as_table_mut().unwrap()
                } else {
                    bail!("{name} is not a table");
                }
            } else {
                table.insert(name, toml_edit::Item::Table(toml_edit::Table::new()));
                table.get_mut(name).unwrap().as_table_mut().unwrap()
            };
            set_in_table(next, tail, parsed)
        }
        Segment::Index(_) => {
            bail!("nested array indexing is not supported by `set`");
        }
    }
}

fn parse_value(raw: &str) -> Value {
    if let Ok(b) = raw.parse::<bool>() {
        return Value::from(b);
    }
    if let Ok(i) = raw.parse::<i64>() {
        return Value::from(i);
    }
    if let Ok(f) = raw.parse::<f64>() {
        return Value::from(f);
    }
    Value::from(raw)
}
