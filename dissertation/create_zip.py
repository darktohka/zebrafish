import os
import zipfile
from pathlib import Path

EXCLUDE_EXTENSIONS = {'.md', '.zip', '.py'}
EXCLUDE_FILES = {'build.sh', '.gitignore', 'output.pdf'}
EXCLUDE_FOLDERS = {'.vscode'}

def load_gitignore_patterns(gitignore_path):
    patterns = set()
    if gitignore_path.exists():
        with gitignore_path.open() as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and line != '*.pdf':
                    patterns.add(line)
    return patterns

def is_ignored(path, patterns):
    for pattern in patterns:
        if path.match(pattern):
            return True
    return False

def should_exclude(path, patterns):
    if path.name in EXCLUDE_FILES:
        return True
    if path.suffix in EXCLUDE_EXTENSIONS:
        return True
    if any(part in EXCLUDE_FOLDERS for part in path.parts):
        return True
    if is_ignored(path, patterns):
        return True
    return False

def main():
    base_dir = Path(__file__).parent
    gitignore_patterns = load_gitignore_patterns(base_dir / '.gitignore')
    zip_path = base_dir / 'archive.zip'

    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(base_dir):
            root_path = Path(root)
            # Exclude folders
            dirs[:] = [d for d in dirs if d not in EXCLUDE_FOLDERS and not is_ignored(root_path / d, gitignore_patterns)]
            for file in files:
                file_path = root_path / file
                rel_path = file_path.relative_to(base_dir)
                if should_exclude(rel_path, gitignore_patterns):
                    continue
                zipf.write(file_path, rel_path)

if __name__ == "__main__":
    main()