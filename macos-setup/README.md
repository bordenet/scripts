# macOS Development Environment Setup Scripts

A modular, component-based architecture for maintainable macOS setup scripts that reduces complexity by ~65% while enabling selective component reuse across projects.

## Overview

This project provides a **reusable template system** for macOS development environment setup scripts. Instead of maintaining monolithic setup scripts that are difficult to customize and maintain, this architecture breaks installation logic into self-contained, numbered components that execute in a predictable order.

### Key Benefits

- **Reduced Complexity**: Modular architecture reduces script complexity by ~65%
- **Selective Reuse**: Copy only the components you need for your project
- **Consistent UI**: Supports both verbose and compact output modes
- **Error Tracking**: Automatic failure tracking with summary reports
- **Easy Customization**: Clear component structure with adoption notes
- **AI-Friendly**: Comprehensive guide for AI-assisted customization

## Quick Start

### For New Projects

Copy the template system to your project:

```bash
# Copy to your project
cp -r macos-setup/lib your-project/scripts/
cp -r macos-setup/setup-components your-project/scripts/
cp macos-setup/setup-macos-template.sh your-project/scripts/setup-macos.sh

# Customize components for your project
# See setup-components/ADOPTERS_GUIDE.md for detailed instructions
```

### Running the Setup Script

```bash
# Interactive mode with verbose output (default)
./setup-macos-template.sh

# Non-interactive with compact output
./setup-macos-template.sh --yes

# Non-interactive with verbose output
./setup-macos-template.sh --yes --verbose
```

## Architecture

### Directory Structure

```
macos-setup/
├── README.md                      # This file
├── setup-macos-template.sh        # Main orchestrator script
├── lib/
│   ├── common.sh                  # Shared functions (logging, colors, etc.)
│   └── migrate-to-standard.sh     # Migration helper script
└── setup-components/              # Installation components (executed in order)
    ├── ADOPTERS_GUIDE.md         # Comprehensive adoption guide
    ├── 00-homebrew.sh            # Package manager (foundation)
    ├── 10-essentials.sh          # Essential dev tools (Node, Go, Xcode)
    ├── 20-mobile.sh              # Mobile development (Flutter, Android)
    ├── 30-web-tools.sh           # Web development tools
    ├── 40-browser-tools.sh       # Browser automation (Playwright)
    ├── 50-utilities.sh           # CLI utilities
    ├── 70-env.sh                 # Environment file setup
    ├── 80-mcp-claude-desktop.sh  # Claude Desktop MCP servers
    └── 90-mcp-claude-code.sh     # Claude Code MCP servers
```

### Component Execution Order

Components are executed in **lexicographic order** based on their numeric prefix:

- **00-09**: Foundation (package managers, core dependencies)
- **10-19**: Core development tools (languages, compilers)
- **20-49**: Platform-specific and additional tooling
- **50-69**: Utilities and helpers
- **70-89**: Configuration and environment setup
- **90-99**: Advanced features and optional components

Dependencies are managed through ordering: components assume earlier components have run successfully.

## Components

### Core Components (Reusable)

| Component | Purpose | Dependencies | Reusable |
|-----------|---------|--------------|----------|
| `00-homebrew.sh` | Installs Homebrew package manager | None | ✅ Yes |
| `10-essentials.sh` | Node.js, TypeScript, Go, AWS CDK, Xcode CLI | 00-homebrew | ✅ Yes |
| `20-mobile.sh` | Flutter SDK, Android Studio, CocoaPods | 00-homebrew, 10-essentials | ✅ Yes |
| `30-web-tools.sh` | ESLint, Prettier, Jest, web dev tools | 10-essentials | ✅ Yes |
| `40-browser-tools.sh` | Playwright browser automation | 10-essentials | ✅ Yes |
| `50-utilities.sh` | AWS CLI, ImageMagick, other utilities | 00-homebrew | ✅ Yes |
| `70-env.sh` | Environment files and shell config | None | ✅ Yes |
| `80-mcp-claude-desktop.sh` | Claude Desktop MCP servers | 10-essentials | ✅ Yes |
| `90-mcp-claude-code.sh` | Claude Code MCP servers | 10-essentials | ✅ Yes |

### Project-Specific Components (Not Reusable)

| Component | Purpose | Reusable |
|-----------|---------|----------|
| `60-monorepo.sh` | Project-specific monorepo dependencies | ❌ No |

## Usage

### Command-Line Options

```bash
./setup-macos-template.sh [OPTIONS]

Options:
  -y, --yes       Automatically confirm all prompts (enables compact output)
  -v, --verbose   Show detailed output (verbose mode)
  -h, --help      Display help message and exit

Examples:
  ./setup-macos-template.sh                # Interactive with verbose output
  ./setup-macos-template.sh --yes          # Non-interactive with compact output
  ./setup-macos-template.sh --yes --verbose # Non-interactive with verbose output
```

### Output Modes

#### Verbose Mode (Default)

Shows detailed progress for each installation:

```
[ ] Installing Homebrew...
[✓] Installing Homebrew... Done!
[→] Node.js already installed
[ ] Installing TypeScript...
[✓] Installing TypeScript... Done!
```

#### Compact Mode (--yes without --verbose)

Shows section-level progress with minimal output:

```
[…] Essential development tools (Node.js)
[…] Essential development tools (TypeScript)
[✓] Essential development tools
```

## Customization

### For New Projects

See **[`setup-components/ADOPTERS_GUIDE.md`](./setup-components/ADOPTERS_GUIDE.md)** for comprehensive instructions on:

- Copying and customizing components
- Creating project-specific components
- Understanding the component interface
- Testing your setup
- Common patterns and best practices

### Component Interface

Every component exports a single `install_component()` function:

```bash
#!/usr/bin/env bash
################################################################################
# Component: <Component Name>
################################################################################
# PURPOSE: <Brief description>
# REUSABLE: <YES or NO>
# DEPENDENCIES: <Required components>
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - <Customization guidance>
################################################################################

COMPONENT_NAME="Display Name"

install_component() {
    section_start "$COMPONENT_NAME"

    # Installation logic here
    if ! command -v tool &> /dev/null; then
      check_installing "Tool Name"
      brew install tool > /dev/null 2>&1
      check_done "Tool Name"
    else
      check_exists "Tool Name"
    fi

    section_end
}
```

### Available Helper Functions

Components have access to these functions from the main script:

**Status Reporting:**
- `check_installing()` - Show installation in progress
- `check_done()` - Mark installation complete
- `check_exists()` - Note tool already installed
- `check_failed()` - Mark installation failed (tracked automatically)

**Logging:**
- `print_info()` - Show info message (verbose mode only)
- `print_success()` - Show success message (verbose mode only)
- `print_warning()` - Show warning (verbose mode only)
- `print_error()` - Show error (always visible)

**Section Management:**
- `section_start()` - Begin a component section
- `section_end()` - End a component section
- `section_update()` - Update progress in compact mode

**User Interaction:**
- `timed_confirm()` - Interactive prompt with timeout (respects --yes flag)

**Global Variables:**
- `$REPO_ROOT` - Repository root directory
- `$AUTO_YES` - Non-interactive mode flag
- `$VERBOSE` - Verbose output flag

## Error Handling

### Automatic Error Tracking

Failed installations are automatically tracked when using `check_failed()`:

```bash
if ! command -v tool &> /dev/null; then
  check_installing "Tool Name"
  brew install tool > /dev/null 2>&1
  if ! command -v tool &> /dev/null; then
    check_failed "Tool Name"  # Automatically tracked
  else
    check_done "Tool Name"
  fi
fi
```

### Summary Report

After all components complete, the script displays:

1. **Installation Summary**: Successfully installed tools and configurations
2. **Manual Steps**: Required post-installation actions
3. **Error Report**: Failed installations with recommended actions

## Best Practices

### Component Design

1. **Make components idempotent** - Safe to run multiple times
2. **Check before installing** - Verify tool isn't already present
3. **Handle errors gracefully** - Use `check_failed()` for tracking
4. **Suppress verbose output** - Redirect to `/dev/null` for clean logs
5. **Document dependencies** - List required components in header
6. **Provide adoption notes** - Guide future customization

### Installation Safety

1. **Use timeouts** for network operations: `timeout 180 npm install`
2. **Confirm large downloads** with `timed_confirm()`
3. **Verify installations** - Check command availability after install
4. **Return to `$REPO_ROOT`** after directory changes
5. **Test both modes** - Verbose and compact output

### Testing

Test your setup in multiple scenarios:

```bash
# Fresh installation (compact)
./setup-macos-template.sh --yes

# Fresh installation (verbose)
./setup-macos-template.sh --yes --verbose

# Re-run on configured system (should detect existing tools)
./setup-macos-template.sh --yes

# Interactive mode (test prompts)
./setup-macos-template.sh
```

## Library Functions

### common.sh

The `lib/common.sh` library provides:

**Logging Functions:**
- `log_info()`, `log_success()`, `log_warning()`, `log_error()`, `log_debug()`
- `log_header()`, `log_section()`

**Error Handling:**
- `die()` - Exit with error message
- `require_command()` - Verify command exists
- `require_file()`, `require_directory()` - Verify paths exist

**Path Utilities:**
- `get_script_dir()` - Get current script directory
- `get_repo_root()` - Find repository root

**User Interaction:**
- `ask_yes_no()` - Interactive yes/no prompt

**Validation:**
- `is_macos()`, `is_linux()`, `is_root()` - Platform checks
- `is_set()` - Check if variable is set

**String Utilities:**
- `to_lowercase()`, `to_uppercase()`, `trim()`

## Migration from Monolithic Scripts

If you have an existing monolithic setup script:

1. **Identify sections** - Group related installations
2. **Create components** - Extract each section into a numbered component
3. **Test incrementally** - Verify each component works independently
4. **Preserve logic** - Keep error handling and conditionals
5. **Update paths** - Use `$REPO_ROOT` for absolute paths

See `lib/migrate-to-standard.sh` for migration helpers.

## Examples

### Conditional Installation with Prompt

```bash
if ! command -v flutter &> /dev/null; then
  if timed_confirm "Install Flutter SDK? (Large download ~1GB)" 15 "N"; then
    check_installing "Flutter SDK"
    brew install flutter > /dev/null 2>&1
    check_done "Flutter SDK"
  else
    print_warning "Skipping Flutter installation"
  fi
fi
```

### Environment Variable Configuration

```bash
SHELL_PROFILE=""
if [ -n "${ZSH_VERSION:-}" ]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [ -n "${BASH_VERSION:-}" ]; then
  SHELL_PROFILE="$HOME/.bash_profile"
fi

if [ -n "$SHELL_PROFILE" ] && [ -f "$SHELL_PROFILE" ]; then
  if ! grep -q "export MY_VAR" "$SHELL_PROFILE"; then
    echo 'export MY_VAR="value"' >> "$SHELL_PROFILE"
    print_success "Added MY_VAR to $SHELL_PROFILE"
  fi
fi
```

## Troubleshooting

### Component Not Executing

- Verify filename starts with numeric prefix (00-, 10-, etc.)
- Check that `install_component()` function is exported
- Test for syntax errors: `bash -n component.sh`
- Ensure executable: `chmod +x component.sh`

### Functions Not Available

- Verify component is sourced (not executed as subprocess)
- Check that `common.sh` is sourced in main script
- Ensure helper functions are defined before component loop

### Wrong Execution Order

- Rename components with appropriate numeric prefix
- Remember lexicographic sort: 00 → 10 → 20 → ... → 90
- Check for duplicate prefixes

## Requirements

- **macOS** (this is macOS-specific)
- **Internet connection** (for package downloads)
- **Admin privileges** (for some operations, password will be requested)

## Support

For questions or issues:

1. Review component headers for ADOPTION NOTES
2. See [`setup-components/ADOPTERS_GUIDE.md`](./setup-components/ADOPTERS_GUIDE.md) for detailed guidance
3. Check existing components for implementation patterns
4. Test changes in a VM or container before running on main system

## Version History

- **v1.0** (2025-11-07) - Initial modular architecture
  - Component-based system with numeric ordering
  - Dual output modes (verbose/compact)
  - Automatic error tracking
  - Comprehensive adoption guide
  - Reusable components for common dev tools

## License

Part of the [bordenet/scripts](https://github.com/bordenet/scripts) repository.

## Related Documentation

- **[ADOPTERS_GUIDE.md](./setup-components/ADOPTERS_GUIDE.md)** - Comprehensive customization guide
- **[common.sh](./lib/common.sh)** - Shared function library
- **Repository README** - [../README.md](../README.md)
