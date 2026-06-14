use std::process::ExitCode;

use clap::Parser;

mod add;
mod cli;
mod edit;
mod efi;
mod get;
mod list;
mod load;
mod path;
mod remove;
mod schema;
mod set;
mod store;
mod validate;

use crate::cli::{Cli, Command, Ctx};

fn main() -> ExitCode {
    let cli = Cli::parse();
    let mut ctx = Ctx::from_cli(&cli);

    // Auto-populate efi_dir when --efi is given without --efi-dir, so that
    // downstream code (load, store, path) doesn't need to re-discover.
    if ctx.efi && ctx.efi_dir.is_none() {
        if let Ok(dir) = efi::discover_efi_dir() {
            ctx.efi_dir = Some(dir);
        }
    }

    match cli.command {
        Command::Get(args) => get::run(ctx, args),
        Command::Set(args) => set::run(ctx, args),
        Command::List(args) => list::run(ctx, args),
        Command::Add(args) => add::run(ctx, args),
        Command::Remove(args) => remove::run(ctx, args),
        Command::Edit(args) => edit::run(ctx, args),
        Command::Path(args) => path::run(ctx, args),
        Command::Validate(args) => validate::run(ctx, args),
    }
}
