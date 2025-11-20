# purge-identity.sh

Comprehensive macOS identity purge tool that discovers and permanently removes all traces of specified email identities from the system.

## Overview

This tool performs deep scanning across macOS to find and remove all references to a specified email identity, including:
- Keychain entries (passwords, certificates, keys)
- Browser data (Safari, Chrome, Edge, Firefox profiles and credentials)
- Mail.app accounts and data
- Application Support credentials
- SSH keys and configurations
- Internet Accounts (System Preferences)
- Cloud storage configurations (iCloud, Dropbox, Google Drive)

## Platform

**macOS only** - Requires Bash 4.0+ (install via Homebrew: `brew install bash`)

## Usage

```bash
./purge-identity.sh [OPTIONS]
```

### Options

- `--what-if` - Dry-run mode: perform discovery and display menu only (no deletions)
- `--verbose` - Enable verbose debug logging
- `-h, --help` - Show detailed help documentation

### Interactive Mode

When run without arguments, the script operates in interactive mode:

1. **Discovery Phase**: Scans system for email identities
2. **Selection Menu**: Choose which identity to purge
3. **Preview**: Review all items that will be deleted
4. **Confirmation**: Multiple confirmation stages before deletion
5. **Execution**: Performs deletion with progress tracking
6. **Report**: Displays summary of actions taken

## Dependencies

- macOS security framework (keychain operations)
- `jq` (JSON parsing) - Install: `brew install jq`
- `sqlite3` (database queries) - Pre-installed on macOS

## Safety Features

### Protected Files

The following patterns are **never** deleted:
- `*.psafe3` - Password Safe databases
- `.git` - Git repositories
- User data files in protected directories

### Confirmation Stages

1. Identity selection confirmation
2. Preview of all items to be deleted
3. Final confirmation before execution
4. Per-item confirmation for critical operations

### What-If Mode

Use `--what-if` to safely preview what would be deleted without making any changes:

```bash
./purge-identity.sh --what-if
```

## Examples

### Basic Usage

```bash
# Interactive mode with discovery
./purge-identity.sh

# Dry-run to preview changes
./purge-identity.sh --what-if

# Verbose logging for debugging
./purge-identity.sh --verbose
```

### Typical Workflow

1. Run in what-if mode to see what will be deleted:
   ```bash
   ./purge-identity.sh --what-if
   ```

2. Review the preview carefully

3. Run for real if satisfied:
   ```bash
   ./purge-identity.sh
   ```

4. Follow the interactive prompts

## Architecture

The script is modular with functionality split across library files:

- `lib/utils.sh` - Logging, timer, display functions
- `lib/helpers.sh` - Helper functions
- `lib/help.sh` - Help documentation
- `lib/scanners-browsers.sh` - Browser scanners
- `lib/scanners-system.sh` - System app scanners
- `lib/deleters-keychain.sh` - Keychain deletion
- `lib/deleters-apps.sh` - App data deletion
- `lib/ui.sh` - UI functions
- `lib/processing.sh` - Discovery, execution, reporting

## Logging

Logs are written to `/tmp/purge-identity-YYYYMMDD-HHMMSS.log`

## Exit Codes

- `0` - Success
- `1` - Error (see log for details)
- `2` - User cancelled operation

## Security Considerations

- Requires sudo for some operations (keychain access, system files)
- Irreversible deletions - use what-if mode first
- Review preview carefully before confirming
- Backup important data before running

## Limitations

- Some cloud storage configurations may require manual cleanup
- Browser profiles in use cannot be deleted (close browsers first)
- System-level accounts may require additional manual steps

## Troubleshooting

### "Bash 4.0 required" Error

Install Homebrew bash:
```bash
brew install bash
```

### "jq not found" Error

Install jq:
```bash
brew install jq
```

### Permission Denied Errors

The script will prompt for sudo when needed. Ensure you have admin privileges.

### Browser Profiles Not Deleted

Close all browser instances before running the script.

## Author

Matt J Bordenet

## Last Updated

2025-11-20

