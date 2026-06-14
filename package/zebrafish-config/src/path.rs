//! Constants for well-known TOML file paths and helpers for resolving
//! dotted key paths against the structured configuration.

use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::str::FromStr;

use anyhow::{anyhow, bail, Result};

use crate::cli::PathArgs;
use crate::efi;
use crate::schema::Config;
use crate::cli::Ctx;

/// Canonical location of the system-wide configuration file.
pub const SYSTEM_FILE: &str = "/etc/zebrafish.toml";

/// Return the system configuration file path.
pub fn system_file() -> &'static Path {
    Path::new(SYSTEM_FILE)
}

/// Return the machine (EFI-resident) configuration file path.
pub fn machine_file(efi_dir: &Path) -> PathBuf {
    efi_dir.join("zebrafish.toml")
}

/// A parsed dotted key path, e.g. `wg[0].peers[1].public_key`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KeyPath {
    segments: Vec<Segment>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Segment {
    Field(String),
    Index(usize),
}

impl KeyPath {
    pub fn parse(s: &str) -> Option<Self> {
        let s = s.trim();
        if s.is_empty() {
            return None;
        }

        let mut segments: Vec<Segment> = Vec::new();
        let mut chars = s.chars().peekable();
        let mut current = String::new();
        let mut in_index = false;

        let mut bad = false;
        while let Some(&c) = chars.peek() {
            match c {
                '.' => {
                    if in_index {
                        bad = true;
                        break;
                    }
                    if !current.is_empty() {
                        segments.push(Segment::Field(std::mem::take(&mut current)));
                    }
                    chars.next();
                }
                '[' => {
                    if in_index {
                        bad = true;
                        break;
                    }
                    if !current.is_empty() {
                        segments.push(Segment::Field(std::mem::take(&mut current)));
                    }
                    in_index = true;
                    chars.next();
                }
                ']' => {
                    if !in_index {
                        bad = true;
                        break;
                    }
                    let Ok(idx) = current.parse::<usize>() else {
                        bad = true;
                        break;
                    };
                    segments.push(Segment::Index(idx));
                    current.clear();
                    in_index = false;
                    chars.next();
                }
                c if in_index => {
                    if !c.is_ascii_digit() {
                        bad = true;
                        break;
                    }
                    current.push(c);
                    chars.next();
                }
                c => {
                    current.push(c);
                    chars.next();
                }
            }
        }

        if bad || in_index {
            return None;
        }
        if !current.is_empty() {
            segments.push(Segment::Field(current));
        }
        if segments.is_empty() {
            return None;
        }

        Some(Self { segments })
    }

    pub fn section(&self) -> Option<&str> {
        match self.segments.first()? {
            Segment::Field(name) => Some(name),
            Segment::Index(_) => None,
        }
    }

    /// Expose the raw segments. Used by `set` and `remove` to walk
    /// through the document.
    pub fn segments(&self) -> &[Segment] {
        &self.segments
    }

    pub fn lookup(&self, cfg: &Config) -> Option<toml::Value> {
        let view = toml::Value::try_from(cfg).ok()?;
        walk_segments(&self.segments, &view)
    }
}

fn walk_segments(segments: &[Segment], value: &toml::Value) -> Option<toml::Value> {
    if segments.is_empty() {
        return Some(value.clone());
    }
    let (head, tail) = segments.split_first()?;
    match head {
        Segment::Field(name) => {
            // `toml::Value` keeps the original TOML key (the serde
            // rename), so hyphenated section names like `nbd-client`
            // are looked up with the hyphen, not the underscore.
            let table = value.as_table()?;
            let next = table.get(name)?;
            walk_segments(tail, next)
        }
        Segment::Index(i) => {
            let arr = value.as_array()?;
            let next = arr.get(*i)?;
            walk_segments(tail, next)
        }
    }
}

impl FromStr for KeyPath {
    type Err = anyhow::Error;
    fn from_str(s: &str) -> Result<Self> {
        Self::parse(s).ok_or_else(|| anyhow!("invalid key path: {s}"))
    }
}

// ---------------------------------------------------------------------------
// `zebrafish-config path` subcommand

pub fn run(ctx: Ctx, args: PathArgs) -> ExitCode {
    match run_inner(ctx, args) {
        Ok(code) => code,
        Err(e) => {
            eprintln!("error: {e:#}");
            ExitCode::from(1)
        }
    }
}

fn run_inner(ctx: Ctx, args: PathArgs) -> Result<ExitCode> {
    let system: Option<PathBuf> = if args.machine {
        None
    } else {
        Some(PathBuf::from(SYSTEM_FILE))
    };

    let machine: Option<PathBuf> = if args.system {
        None
    } else {
        let efi_dir: PathBuf = match ctx.efi_dir.clone() {
            Some(d) => d,
            None if ctx.efi => efi::discover_efi_dir()?,
            None => bail!("cannot locate machine file without --efi (or --efi-dir)"),
        };
        Some(machine_file(&efi_dir))
    };

    match (system, machine) {
        (Some(s), Some(m)) => {
            println!("{}", s.display());
            println!("{}", m.display());
        }
        (Some(s), None) => println!("{}", s.display()),
        (None, Some(m)) => println!("{}", m.display()),
        (None, None) => {}
    }

    Ok(ExitCode::SUCCESS)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_scalar() {
        let p = KeyPath::parse("ipv4.address").unwrap();
        assert_eq!(p.section(), Some("ipv4"));
    }

    #[test]
    fn parse_indexed() {
        let p = KeyPath::parse("wg[0].peers[1].public_key").unwrap();
        assert_eq!(p.section(), Some("wg"));
        assert_eq!(
            p.segments,
            vec![
                Segment::Field("wg".to_string()),
                Segment::Index(0),
                Segment::Field("peers".to_string()),
                Segment::Index(1),
                Segment::Field("public_key".to_string()),
            ]
        );
    }

    #[test]
    fn parse_hyphenated() {
        let p = KeyPath::parse("nbd-client[2].port").unwrap();
        assert_eq!(p.section(), Some("nbd-client"));
    }

    #[test]
    fn rejects_empty() {
        assert!(KeyPath::parse("").is_none());
    }

    #[test]
    fn rejects_bad_index() {
        assert!(KeyPath::parse("wg[abc]").is_none());
    }
}
