# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS development environment setup. The primary entry point is `.bash_profile`, which orchestrates the loading of various tool configurations through modular shell scripts.

## Architecture

### Shell Configuration System

The `.bash_profile` file uses a modular architecture that sources configuration files from various subdirectories:

- **Modular Loading Pattern**: Each tool/language has its own subdirectory with a setup script (e.g., `nvm/.nvm_setup.sh`, `Python/.python.sh`, `Elixir/.Elixir.sh`)
- **Path Resolution**: Uses `$BASH_SOURCE` to determine the dotfiles directory path, stored in `$DIR_PATH`
- **Sourcing Order**: Homebrew → AWS → GCloud → NVM/Node → Git → Helpers → Language-specific tools (Elixir, Rust, Python) → AI Tools

Key directories:
- `nvm/` - Node.js version management
- `git_setup/` - Git configuration and prompt
- `dx-tools/aws/` - AWS CLI setup
- `Python/`, `Elixir/`, `Rust/` - Language-specific configurations
- `AiTools/` - AI tool configurations
- `smart_sync/` - Smart bidirectional file sync utility (Python)
- `sync_files/` - Basic bidirectional file sync utility (Python)

### Python Projects

Two standalone Python utilities exist in this repository:

#### smart_sync (Recommended)
A sophisticated bidirectional file sync tool with "most recent version wins" strategy:
- **Location**: `smart_sync/smart_sync.py`
- **Key Feature**: Automatically determines which file version is newer and ensures both directories have the most recent version
- **Dependencies**: `watchdog` library (see `smart_sync/requirements.txt`)
- **Test Script**: `smart_sync/test_smart_sync.py` demonstrates functionality with temporary directories

#### sync_files (Legacy)
Basic bidirectional file sync without version comparison:
- **Location**: `sync_files/file_sync.py`
- **Note**: Simpler implementation, use `smart_sync` for production use

## Development Commands

### Python Projects

For `smart_sync/` or `sync_files/`:

```bash
# Create and activate virtual environment
cd smart_sync  # or sync_files
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
python3 -m pip install -r requirements.txt

# Run smart sync
python3 smart_sync.py /path/to/dir1 /path/to/dir2 --ignore "*.tmp" ".git" "node_modules"

# Run tests
python3 test_smart_sync.py
```

### Shell Configuration

```bash
# Reload bash configuration
source ~/.bash_profile
# or use the alias
source_bash_profile

# View npm global packages
get_npm_global_pkgs
```

## Code Patterns

### smart_sync.py Architecture

The smart sync utility follows an event-driven architecture:

1. **SmartSyncHandler Class**: Inherits from `FileSystemEventHandler` (watchdog library)
   - Handles file events: creation, modification, deletion, moves
   - Implements loop prevention via `recent_events` dictionary with 2-second event window
   - Uses modification time comparison (`os.path.getmtime()`) to determine which version to keep

2. **Ignore Patterns**:
   - Default patterns in `DEFAULT_IGNORE_PATTERNS` (`.DS_Store`, `__pycache__`, `node_modules`, `.git`, etc.)
   - Additional patterns via `--ignore` CLI argument
   - Pattern matching checks both full paths and path components

3. **Initial Sync**: `perform_initial_sync()` function
   - Walks both directories to collect all unique files
   - Compares modification times for files that exist in both locations
   - Ensures both directories are consistent before starting real-time monitoring

4. **Bidirectional Monitoring**:
   - Creates two `Observer` instances and two `SmartSyncHandler` instances (one for each direction)
   - Each directory watches the other, enabling true bidirectional sync

### Shell Script Patterns

- **Conditional Loading**: All `.sh` files assume they're sourced, not executed
- **Path Variables**: Use `DIR_PATH` to reference the dotfiles root
- **Alias Conventions**: Provide both direct and alternate alias names (e.g., `get_npm_global_pkgs` and `npm_get_global_pkgs`)

## Key Utilities and Functions

From `.helpers.sh`:
- `killPort <port>` - Kill process running on specified port
- `listProcessOnPort <port>` - List process on specified port
- `moveToTrash <path>` - Move file/directory to trash
- `get_myip` - Get public IP address
- `get_os_cores` - Display CPU core information

## Environment Considerations

- **OS**: macOS (Darwin) - uses macOS-specific commands like `sysctl`, `lsof`
- **Shell**: Bash (with Zsh deprecation warning silenced via `BASH_SILENCE_DEPRECATION_WARNING=1`)
- **Architecture**: Supports Apple Silicon (M1) with Rosetta 2 alias: `rosetta2`
- **Version Control**: Uses Git with custom prompt (`.git-prompt.sh`)
