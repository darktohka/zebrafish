use std::path::PathBuf;

use clap::{Args, Parser, Subcommand, ValueHint};

#[derive(Debug, Parser)]
#[command(
    name = "zebrafish-config",
    version,
    about = "Read and edit Zebrafish TOML configuration files",
    long_about = None,
)]
pub struct Cli {
    /// Path to the EFI partition directory containing zebrafish.toml.
    /// Overrides the auto-discovered EFI directory.
    #[arg(long, global = true, value_hint = ValueHint::DirPath)]
    pub efi_dir: Option<PathBuf>,

    /// Override the configuration file to operate on.
    /// Applies to read commands (`get`, `list`, `validate`) and write
    /// commands (`set`, `add`, `remove`, `edit`) alike. Without this
    /// flag, read commands merge the EFI and system files, and write
    /// commands pick the right file automatically.
    #[arg(long, global = true, value_hint = ValueHint::FilePath)]
    pub file: Option<PathBuf>,

    /// Only consider the EFI-resident zebrafish.toml (used by setup-persistence).
    #[arg(long, global = true)]
    pub machine_only: bool,

    /// Suppress non-error output.
    #[arg(long, global = true)]
    pub quiet: bool,

    /// Increase verbosity.
    #[arg(long, global = true, conflicts_with = "quiet")]
    pub verbose: bool,

    #[command(subcommand)]
    pub command: Command,
}

#[derive(Debug, Subcommand)]
pub enum Command {
    /// Read a single value at the given dotted key path.
    Get(GetArgs),

    /// Write a scalar value at the given dotted key path.
    Set(SetArgs),

    /// Print the whole configuration (or one section) in a chosen format.
    List(ListArgs),

    /// Add a new entry to an array of tables (e.g. `add wg`).
    Add(AddArgs),

    /// Remove a section, an array element, or a scalar key.
    Remove(RemoveArgs),

    /// Open the configuration file in $EDITOR.
    Edit(EditArgs),

    /// Print the path to the file(s) that would be read or written.
    Path(PathArgs),

    /// Validate the configuration file(s) and exit non-zero on any error.
    Validate(ValidateArgs),
}

/// A `file` reference is bundled with every subcommand invocation so
/// the implementation does not have to thread the top-level `Cli`
/// through to every handler.
#[derive(Debug, Default, Clone)]
pub struct Ctx {
    pub file: Option<PathBuf>,
    pub efi_dir: Option<PathBuf>,
    pub machine_only: bool,
}

impl Ctx {
    pub fn from_cli(cli: &Cli) -> Self {
        Self {
            file: cli.file.clone(),
            efi_dir: cli.efi_dir.clone(),
            machine_only: cli.machine_only,
        }
    }
}

#[derive(Debug, Args)]
pub struct GetArgs {
    /// Dotted key path, e.g. `ipv4.dns[0]` or `wg[2].peers[0].public_key`.
    #[arg(required = true)]
    pub key: String,

    /// Default value to return if the key is missing.
    #[arg(long)]
    pub default: Option<String>,

    /// Treat the value as a boolean and print `true` / `false`.
    /// Exits non-zero on missing values, so callers can distinguish
    /// "explicitly false" from "not present" via the exit code alone.
    #[arg(long, conflicts_with = "default")]
    pub r#bool: bool,
}

#[derive(Debug, Args)]
pub struct SetArgs {
    /// Dotted key path.
    #[arg(required = true)]
    pub key: String,

    /// Value to write. Booleans, integers, and strings are inferred.
    #[arg(required = true)]
    pub value: String,
}

#[derive(Debug, Args)]
pub struct ListArgs {
    /// Restrict the listing to a single top-level section (e.g. `wg`, `ipv4`).
    #[arg(value_name = "SECTION")]
    pub section: Option<String>,

    /// Output format.
    #[arg(long, value_enum, default_value_t = ListFormat::Toml)]
    pub format: ListFormat,
}

#[derive(Debug, Clone, Copy, clap::ValueEnum)]
pub enum ListFormat {
    Toml,
    Json,
    Shell,
}

#[derive(Debug, Args)]
pub struct AddArgs {
    /// Top-level section name (must be an array of tables), e.g. `wg`.
    #[arg(required = true)]
    pub section: String,
}

#[derive(Debug, Args)]
pub struct RemoveArgs {
    /// Dotted key path. For an array element, address it as `wg[2]`.
    #[arg(required = true)]
    pub key: String,
}

#[derive(Debug, Args)]
pub struct EditArgs {}

#[derive(Debug, Args)]
pub struct PathArgs {
    /// Print only the system file path (`/etc/zebrafish.toml`).
    #[arg(long, conflicts_with = "machine")]
    pub system: bool,

    /// Print only the machine (EFI) file path.
    #[arg(long, conflicts_with = "system")]
    pub machine: bool,
}

#[derive(Debug, Args)]
pub struct ValidateArgs {
    /// Validate only the machine (EFI) file.
    #[arg(long, conflicts_with = "system")]
    pub machine: bool,

    /// Validate only the system file.
    #[arg(long, conflicts_with = "machine")]
    pub system: bool,
}
