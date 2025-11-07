# Setup Script Adopters Guide for AI Agents

This guide explains how the modularized setup script architecture works and how to adopt/adapt it for other git repositories.

## Architecture Overview

The setup script uses a **component-based architecture** where installation logic is broken into reusable, self-contained modules:

```
scripts/
├── setup-macos.sh                 # Main orchestrator script
├── lib/
│   └── common.sh                  # Shared functions (logging, colors, etc.)
└── setup-components/              # Installation components
    ├── 00-homebrew.sh            # Package manager (reusable)
    ├── 10-essentials.sh          # Essential dev tools (reusable)
    ├── 20-mobile.sh              # Mobile development (reusable)
    ├── 30-web-tools.sh           # Web development (reusable)
    ├── 40-browser-tools.sh       # Browser automation (reusable)
    ├── 50-utilities.sh           # CLI utilities (reusable)
    ├── 60-monorepo.sh            # Project-specific (NOT reusable)
    ├── 70-env.sh                 # Environment files (reusable)
    ├── 80-mcp-claude-desktop.sh  # Claude Desktop MCP (reusable)
    └── 90-mcp-claude-code.sh     # Claude Code MCP (reusable)
```

## Key Design Principles

### 1. **Numeric Ordering**
Components are executed in lexicographic order based on their filename prefix:
- `00-*` = Foundation (Homebrew, package manager)
- `10-*` = Core tools (Node, Go, Xcode CLI)
- `20-*` = Platform-specific (mobile, web)
- `30-50-*` = Additional tooling
- `60-90-*` = Advanced/optional features

Dependencies are managed through ordering: components assume earlier components have run successfully.

### 2. **Component Interface**
Every component must export a single function:

```bash
install_component() {
    section_start "$COMPONENT_NAME"

    # Installation logic here
    # Use: check_installing(), check_done(), check_exists(), check_failed()
    # Use: print_info(), print_success(), print_warning(), print_error()
    # Use: timed_confirm() for user prompts

    section_end
}
```

### 3. **Shared Function Scope**
Components have access to all helper functions from the main script:
- **check_***: Installation status reporting (verbose/compact modes)
- **section_***: Section lifecycle management
- **print_***: Logging with color support
- **timed_confirm()**: Interactive prompts with timeouts
- **REPO_ROOT**: Repository root path
- **AUTO_YES**, **VERBOSE**: Global flags

### 4. **Error Tracking**
Failures are tracked automatically via the `check_failed()` function which populates the global `FAILED_INSTALLS` array. The main script displays a summary at the end.

## Adopting for a New Repository

### Step 1: Copy the Foundation

```bash
# Copy the core infrastructure
cp -r scripts/lib your-repo/scripts/
cp scripts/setup-macos.sh your-repo/scripts/
mkdir -p your-repo/scripts/setup-components
```

### Step 2: Copy Reusable Components

Only copy components marked `REUSABLE: YES` in their headers:

```bash
# Essential components (usually needed)
cp scripts/setup-components/00-homebrew.sh your-repo/scripts/setup-components/
cp scripts/setup-components/10-essentials.sh your-repo/scripts/setup-components/
cp scripts/setup-components/70-env.sh your-repo/scripts/setup-components/

# Optional components (based on your tech stack)
cp scripts/setup-components/20-mobile.sh your-repo/scripts/setup-components/  # If using Flutter
cp scripts/setup-components/30-web-tools.sh your-repo/scripts/setup-components/  # If web development
# etc.
```

### Step 3: Customize Components

Edit copied components to match your project needs:

**Example: Customizing 10-essentials.sh**
```bash
#!/usr/bin/env bash
################################################################################
# Component: Essential Development Tools
################################################################################
# PURPOSE: Install essential development tools like Node, Go, and Xcode CLI.
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is reusable.
# - Comment out or remove installations you don't need.
################################################################################

install_component() {
    section_start "Essential development tools"

    # Node.js - KEEP THIS if you use JavaScript/TypeScript
    if ! command -v node &> /dev/null; then
      check_installing "Node.js"
      brew install node > /dev/null 2>&1
      check_done "Node.js"
    else
      check_exists "Node.js ($(node --version))"
    fi

    # Go - REMOVE THIS if you don't use Go
    # if ! command -v go &> /dev/null; then
    #   check_installing "Go"
    #   brew install go > /dev/null 2>&1
    #   check_done "Go"
    # else
    #   check_exists "Go ($(go version | awk '{print $3}'))"
    # fi

    # Add YOUR project-specific tools here
    if ! command -v rust &> /dev/null; then
      check_installing "Rust"
      brew install rust > /dev/null 2>&1
      check_done "Rust"
    fi

    section_end
}
```

### Step 4: Create Project-Specific Components

For project-specific logic, create new components:

```bash
cat > your-repo/scripts/setup-components/60-your-project.sh <<'EOF'
#!/usr/bin/env bash
################################################################################
# Component: Your Project Setup
################################################################################
# PURPOSE: Install project-specific dependencies.
# REUSABLE: NO
# DEPENDENCIES: 10-essentials
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is NOT reusable - it's specific to this project.
# - Delete this component when adopting for other projects.
################################################################################

COMPONENT_NAME="Your Project dependencies"

install_component() {
    section_start "$COMPONENT_NAME"

    # Your project-specific installation logic here
    if [ -f "package.json" ]; then
      print_info "Installing npm dependencies..."
      npm install > /dev/null 2>&1
      print_success "Dependencies installed"
    fi

    section_end
}
EOF
```

### Step 5: Update Main Script Header

Edit `setup-macos.sh` to reflect your project:

```bash
################################################################################
# YourProject macOS Development Environment Setup
################################################################################
# PURPOSE: Complete development environment setup for macOS
#   - List your project's specific requirements here
#
# USAGE:
#   ./scripts/setup-macos.sh [OPTIONS]
#
# NOTES:
#   - macOS only
#   - Run once for initial environment setup
#   - See setup-components/ADOPTERS_GUIDE.md for customization
################################################################################
```

### Step 6: Test Your Setup

```bash
# Test in non-interactive mode
./scripts/setup-macos.sh --yes

# Test verbose output
./scripts/setup-macos.sh --yes --verbose

# Test interactive mode
./scripts/setup-macos.sh --verbose
```

## Component Template

Use this template when creating new components:

```bash
#!/usr/bin/env bash
################################################################################
# Component: <Component Name>
################################################################################
# PURPOSE: <Brief description>
# REUSABLE: <YES or NO>
# DEPENDENCIES: <List of required components, e.g., 00-homebrew, 10-essentials>
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - <Specific guidance for future adopters>
# - <What to customize>
# - <What to remove>
################################################################################

# Component metadata
COMPONENT_NAME="<Display name for section>"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # Installation logic
    if ! command -v <tool> &> /dev/null; then
      check_installing "<Tool Name>"
      brew install <tool> > /dev/null 2>&1
      if ! command -v <tool> &> /dev/null; then
        print_error "<Tool> installation failed"
        check_failed "<Tool>"
      else
        check_done "<Tool Name>"
      fi
    else
      check_exists "<Tool Name>"
    fi

    section_end
}
```

## Common Patterns

### Pattern: Conditional Installation with Prompt
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

### Pattern: Version Check
```bash
if ! command -v node &> /dev/null; then
  check_installing "Node.js"
  brew install node > /dev/null 2>&1
  check_done "Node.js"
else
  check_exists "Node.js ($(node --version))"
fi
```

### Pattern: Shell Profile Configuration
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

### Pattern: Directory Navigation Safety
```bash
# Always return to REPO_ROOT after cd operations
if [ -d "subdir" ]; then
  cd subdir
  # Do work
  cd "$REPO_ROOT"  # Explicit return
fi

# Or use subshell to avoid cd altogether
if [ -d "subdir" ]; then
  (cd subdir && npm install)
fi
```

## Output Modes

The script supports two output modes via the `VERBOSE` flag:

### Verbose Mode (default)
```
[ ] Installing Homebrew...
[✓] Installing Homebrew... Done!
[→] Node.js already installed
```

### Compact Mode (--yes without --verbose)
```
[…] Essential development tools (Node.js)
[✓] Essential development tools
```

Use `section_update()` in compact mode to show progress without cluttering output.

## Error Handling

### Automatic Error Tracking
```bash
check_failed "Component Name"
# Automatically adds to FAILED_INSTALLS array
# Displayed in final summary
```

### Manual Error Handling
```bash
if ! some_command; then
  print_error "Command failed"
  print_info "Try: <suggestion>"
  die "Setup failed"  # Exits with error
fi
```

## Best Practices

1. **Use timeouts** for network operations: `timeout 120 npm install`
2. **Suppress output** for clean logs: `command > /dev/null 2>&1`
3. **Check command availability** before using: `command -v tool &> /dev/null`
4. **Provide fallbacks** for optional components
5. **Document dependencies** in component headers
6. **Use meaningful names** for check_* functions
7. **Return to REPO_ROOT** after directory changes
8. **Test both verbose and compact modes**
9. **Handle both fresh installs and re-runs** (idempotent)
10. **Use timed_confirm()** for large downloads or destructive operations

## Testing Checklist

When adopting this architecture:

- [ ] Test `./scripts/setup-macos.sh --yes` (compact, non-interactive)
- [ ] Test `./scripts/setup-macos.sh --yes --verbose` (verbose, non-interactive)
- [ ] Test `./scripts/setup-macos.sh --verbose` (verbose, interactive)
- [ ] Test on fresh macOS installation
- [ ] Test when tools are already installed (re-run)
- [ ] Test with network failures (timeout behavior)
- [ ] Test with user declining optional components
- [ ] Verify all components execute in correct order
- [ ] Verify error tracking and final summary
- [ ] Verify shell profile modifications work

## Troubleshooting

### Component not executing
- Check filename starts with numeric prefix (00-, 10-, etc.)
- Verify `install_component()` function is exported
- Check for bash syntax errors: `bash -n component.sh`
- Ensure component is executable: `chmod +x component.sh`

### Functions not available in component
- Verify component is sourced (not executed as subprocess)
- Check that common.sh is sourced correctly in main script
- Ensure helper functions are defined before component loop

### Wrong execution order
- Rename components with appropriate numeric prefix
- Remember: lexicographic sort (00 → 10 → 20 → ... → 90)
- Check for duplicate prefixes

## Migration from Monolithic Script

If you have an existing monolithic setup script:

1. **Identify sections**: Look for logical groupings (package manager, languages, tools)
2. **Create components**: Extract each section into a component file
3. **Test incrementally**: Comment out old code, test component, then delete old code
4. **Preserve logic**: Keep conditional checks, error handling, and user prompts
5. **Update paths**: Change relative paths to use `$REPO_ROOT`
6. **Test thoroughly**: Ensure behavior matches original script

## Support

For questions or issues with this architecture:
- Review component headers for ADOPTION NOTES
- Check CLAUDE.md for project-specific guidance
- Examine existing components for patterns
- Test changes in a VM or container before running on main system

---

**Last Updated**: 2025-11-07
**Architecture Version**: 1.0
**Maintainer**: RecipeArchive Project
