//! `zebrafish-config list [section]`

use std::process::ExitCode;

use anyhow::Result;

use crate::cli::{Ctx, ListArgs};

pub fn run(ctx: Ctx, args: ListArgs) -> ExitCode {
    match run_inner(ctx, args) {
        Ok(code) => code,
        Err(e) => {
            eprintln!("error: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn run_inner(ctx: Ctx, args: ListArgs) -> Result<ExitCode> {
    let cfg = if let Some(f) = ctx.file.as_deref() {
        let text = std::fs::read_to_string(f)?;
        crate::schema::Config::from_toml(&text)?
    } else {
        crate::load::load(ctx.efi_dir.as_deref(), ctx.machine_only)?
    };

    let view = toml::Value::try_from(&cfg)?;
    let table = view.as_table().expect("Config is always a table");

    let section_value: Option<(&str, &toml::Value)> = match args.section.as_deref() {
        Some(name) => {
            // `toml::Value` preserves the original TOML key (the
            // serde rename), so we look up using the user-supplied
            // section name as-is, including hyphens.
            match table.get(name) {
                Some(value) => Some((name, value)),
                None => {
                    eprintln!("section not present: {name}");
                    return Ok(ExitCode::from(1));
                }
            }
        }
        None => None,
    };

    match args.format {
        crate::cli::ListFormat::Toml => {
            let out = match section_value {
                Some((name, v)) => format!("[{}]\n{}\n", name, v),
                None => toml::to_string_pretty(&cfg)?,
            };
            print!("{out}");
        }
        crate::cli::ListFormat::Json => {
            let out = match section_value {
                Some((_, v)) => serde_json::to_string_pretty(v)?,
                None => serde_json::to_string_pretty(&cfg)?,
            };
            println!("{out}");
        }
        crate::cli::ListFormat::Shell => {
            let root = section_value.map(|(_, v)| v).unwrap_or(&view);
            let prefix: Vec<String> = match section_value {
                Some((name, _)) => vec![name.to_uppercase()],
                None => vec![],
            };
            emit_shell(root, &prefix);
        }
    }

    Ok(ExitCode::SUCCESS)
}

fn emit_shell(value: &toml::Value, prefix: &[String]) {
    if let Some(t) = value.as_table() {
        for (k, v) in t {
            let mut next = prefix.to_vec();
            next.push(k.to_uppercase());
            emit_shell(v, &next);
        }
    } else if let Some(a) = value.as_array() {
        let mut count = prefix.to_vec();
        count.push("COUNT".to_string());
        println!("{}={}", count.join("_"), a.len());

        for (i, item) in a.iter().enumerate() {
            let mut next = prefix.to_vec();
            next.push(i.to_string());
            emit_shell(item, &next);
        }
    } else {
        let key = prefix.join("_");
        let rendered = match value {
            toml::Value::String(s) => shell_quote(s),
            other => other.to_string(),
        };
        println!("{key}={rendered}");
    }
}

fn shell_quote(s: &str) -> String {
    if s.chars()
        .all(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '-' | '.' | '/' | ':' | '+' | '='))
    {
        s.to_string()
    } else {
        format!("'{}'", s.replace('\'', "'\\''"))
    }
}
