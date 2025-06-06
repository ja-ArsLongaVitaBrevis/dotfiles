# Bidirectional File Sync

A Python script that keeps two directories in sync bidirectionally. Any changes (creation, modification, deletion) in either directory will be propagated to the other.

## Features

- Bidirectional synchronization between two directories
- Handles file creation, modification, and deletion events
- Supports ignoring specific files or directories using patterns
- Performs initial sync when started
- Prevents sync loops with event tracking
- Preserves file metadata

## Requirements

- Python 3.6+
- watchdog library (included in requirements.txt)

## Installation

1. Clone or download this repository
2. Install the required dependencies:

```bash
pip install -r requirements.txt
# OR
python3 -m pip install -r requirements.txt
```

## Usage

Basic usage:

```bash
python file_sync.py /path/to/dir1 /path/to/dir2
```

Ignore specific files or patterns:

```bash
python file_sync.py /path/to/dir1 /path/to/dir2 --ignore "*.tmp" ".git" "node_modules"
```

## How It Works

1. When started, the script performs an initial sync between the two directories
2. It then sets up file system watchers on both directories
3. Any changes in either directory are detected and propagated to the other
4. To prevent sync loops, the script tracks recent events and ignores duplicates
5. The script runs continuously until interrupted with Ctrl+C

## Examples

Sync two project directories:

```bash
python file_sync.py ~/projects/project-a ~/projects/project-b
```

Sync with ignoring temporary files and version control:

```bash
python file_sync.py ~/documents/work ~/documents/backup --ignore "*.tmp" "*.swp" ".git" ".svn"
```

## Notes

- The script uses absolute paths internally to avoid any path resolution issues
- Both directories must exist or will be created if they don't
- File metadata (modification times, permissions) is preserved during sync
- The script logs all actions to the console
