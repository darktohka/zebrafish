//! Find and mount the EFI system partition.

use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{anyhow, bail, Context, Result};

/// Default mount point for the EFI system partition.
pub const EFI_MOUNT_POINT: &str = "/run/zebrafish/efi";

/// The name of the kernel image we look for on the EFI partition.
pub const KERNEL_IMAGE: &str = "zebrafish-kernel";

/// Errors that can occur while locating the EFI partition.
#[derive(Debug, thiserror::Error)]
pub enum EfiError {
    #[error("could not run lsblk: {0}")]
    Lsblk(#[source] std::io::Error),

    #[error("found {0} EFI system partitions, expected exactly 1")]
    Ambiguous(usize),

    #[error("no EFI system partition found")]
    NotFound,

    #[error("could not mount {partition} at {mount_point}: {source}")]
    Mount {
        partition: PathBuf,
        mount_point: PathBuf,
        #[source]
        source: std::io::Error,
    },
}

/// Return the name of the single EFI system partition, e.g. `sda1` or `nvme0n1p1`.
///
/// Uses the same filter as the existing `configure` and `upgrade` scripts:
/// a `vfat` filesystem with PARTFLAGS `0x4`.
pub fn find_efi_partition() -> Result<String, EfiError> {
    let output = Command::new("lsblk")
        .args(["-nr", "-o", "NAME,FSTYPE,PARTFLAGS"])
        .output()
        .map_err(EfiError::Lsblk)?;

    if !output.status.success() {
        return Err(EfiError::Lsblk(std::io::Error::other(format!(
            "lsblk exited with status {}",
            output.status
        ))));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut found: Vec<String> = stdout
        .lines()
        .filter(|line| {
            let mut parts = line.split_whitespace();
            matches!(
                (parts.next(), parts.next(), parts.next()),
                (Some(_), Some("vfat"), Some("0x4"))
            )
        })
        .map(|line| line.split_whitespace().next().unwrap().to_string())
        .collect();

    match found.len() {
        1 => Ok(found.pop().unwrap()),
        n if n > 1 => Err(EfiError::Ambiguous(n)),
        _ => Err(EfiError::NotFound),
    }
}

/// Idempotently mount the EFI system partition read-only at
/// [`EFI_MOUNT_POINT`]. If it is already mounted, this is a no-op.
pub fn mount_efi() -> Result<PathBuf> {
    let partition_name = find_efi_partition()?;
    let partition = PathBuf::from(format!("/dev/{partition_name}"));

    let mount_point = Path::new(EFI_MOUNT_POINT);
    std::fs::create_dir_all(mount_point)
        .with_context(|| format!("creating mount point {}", mount_point.display()))?;

    // If the mount point is already mounted, do nothing.
    if is_mounted(mount_point)? {
        return Ok(partition);
    }

    let status = Command::new("mount")
        .args(["-r", "-t", "vfat"])
        .arg(&partition)
        .arg(mount_point)
        .status();

    match status {
        Ok(s) if s.success() => Ok(partition),
        Ok(s) => bail!("mount exited with status {s}"),
        Err(e) => Err(EfiError::Mount {
            partition,
            mount_point: mount_point.to_path_buf(),
            source: e,
        }
        .into()),
    }
}

fn is_mounted(path: &Path) -> Result<bool> {
    let mounts = std::fs::read_to_string("/proc/mounts")
        .with_context(|| "reading /proc/mounts")?;
    Ok(mounts.lines().any(|line| {
        let mount_point = line.split_whitespace().nth(1);
        match mount_point {
            Some(p) => Path::new(p) == path,
            None => false,
        }
    }))
}

/// Find the directory on the EFI partition that contains [`KERNEL_IMAGE`].
///
/// Requires the EFI partition to be mounted first; call [`mount_efi`] if unsure.
///
/// Searches recursively (mirroring the `find ... -name zebrafish-kernel` pattern
/// used by the shell scripts in `lib/zebrafish/functions` and `lib/zebrafish/upgrade`).
pub fn kernel_dir(efi_mount: &Path) -> Result<PathBuf> {
    let mut stack = vec![efi_mount.to_path_buf()];

    while let Some(dir) = stack.pop() {
        let candidate = dir.join(KERNEL_IMAGE);
        if candidate.exists() {
            return Ok(dir);
        }
        if let Ok(entries) = std::fs::read_dir(&dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    stack.push(path);
                }
            }
        }
    }

    Err(anyhow!(
        "could not find {KERNEL_IMAGE} under {}",
        efi_mount.display()
    ))
}

/// Mount the EFI partition (if needed) and return the directory
/// containing `zebrafish-kernel`. This is the main entry point used by
/// the rest of the CLI.
pub fn discover_efi_dir() -> Result<PathBuf> {
    let _ = mount_efi()?;
    let mount = Path::new(EFI_MOUNT_POINT);
    kernel_dir(mount)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mount_point_is_constant() {
        assert_eq!(EFI_MOUNT_POINT, "/run/zebrafish/efi");
        assert_eq!(KERNEL_IMAGE, "zebrafish-kernel");
    }
}
