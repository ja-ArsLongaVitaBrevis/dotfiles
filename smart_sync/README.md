# Smart Bidirectional File Sync

A Python script that keeps two directories in sync bidirectionally, ensuring both directories always have the most recent version of each file.

## Features

- **"Most Recent Version Wins" Synchronization**: Automatically determines which version of a file is newer and ensures both directories have the most recent version
- **Bidirectional Synchronization**: Changes in either directory are propagated to the other
- **Metadata Preservation**: File metadata (modification times, permissions) is preserved during sync
- **Recursive Operation**: Handles nested directories at any depth
- **Handles All File Events**:
  - File creation: New files are copied to the other directory
  - File modification: Modified files replace older versions in both directories
  - File deletion: Deleted files are removed from both directories
- **Ignore Patterns**: Supports ignoring specific files or directories using patterns
- **Initial Sync**: Performs a comprehensive initial sync when started
- **Loop Prevention**: Prevents sync loops with sophisticated event tracking

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
python smart_sync.py /path/to/dir1 /path/to/dir2
```

Ignore specific files or patterns:

```bash
python smart_sync.py /path/to/dir1 /path/to/dir2 --ignore "*.tmp" ".git" "node_modules"
```

## How It Works

### Initial Synchronization

When started, the script performs an initial sync between the two directories:

1. It identifies all unique files across both directories
2. For each file:
   - If it exists in only one directory, it's copied to the other
   - If it exists in both directories, the modification times are compared, and the newer version is copied to replace the older one
3. This ensures both directories are in a consistent state before real-time monitoring begins

### Real-time Monitoring

After the initial sync, the script:

1. Sets up file system watchers on both directories
2. Detects any changes (creation, modification, deletion) in either directory
3. For each change:
   - For new or modified files, compares modification times if the file exists in both locations
   - Ensures the most recent version is used in both directories
   - For deleted files, removes the corresponding file from the other directory
4. Prevents sync loops by tracking recent events

## Examples

Sync two project directories:

```bash
python smart_sync.py ~/projects/project-a ~/projects/project-b
```

Sync with ignoring temporary files and version control:

```bash
python smart_sync.py ~/documents/work ~/documents/backup --ignore "*.tmp" "*.swp" ".git" ".svn"
```

## Notes

- The script uses absolute paths internally to avoid any path resolution issues
- Both directories will be created if they don't exist
- The script logs all actions to the console
- The "most recent version wins" strategy ensures that after any sync operation, both directories will have identical copies of all files, with each file being the most up-to-date version
