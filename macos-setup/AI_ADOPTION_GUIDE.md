# AI Assistant Adoption Guide for macOS Setup System

**Target Audience:** Claude Code, Google Gemini, and other AI coding assistants

**Purpose:** This guide provides step-by-step instructions for AI assistants to copy and customize this modular macOS setup system for new repositories.

---

## Overview

This directory (`macos-setup/`) contains a **portable, modular macOS development environment setup system** designed to be copied into new repositories and customized for project-specific needs.

**Key Concept:** Instead of writing monolithic setup scripts, this system uses numbered, self-contained components that execute in order.

---

## Quick Adoption Checklist for AI Assistants

When a user asks to "add macOS setup to this repo" or "copy the setup system", follow these steps:

### Step 1: Copy the Template Structure

```bash
# From the scripts repo, copy to target repo
cp -r /path/to/scripts/macos-setup /path/to/target-repo/scripts/

# Or if already in target repo:
# Copy these directories/files:
#   - macos-setup/lib/
#   - macos-setup/setup-components/
#   - macos-setup/setup-macos-template.sh
#   - macos-setup/README.md
#   - macos-setup/AI_ADOPTION_GUIDE.md (this file)
```

### Step 2: Rename Main Script

```bash
cd /path/to/target-repo/scripts/macos-setup/
mv setup-macos-template.sh setup-macos.sh
```

### Step 3: Customize Header in setup-macos.sh

Update lines 4-5 to reflect the new project:

```bash
#!/usr/bin/env bash
################################################################################
# [PROJECT NAME] macOS Development Environment Setup
################################################################################
# PURPOSE: Complete development environment setup for [PROJECT NAME]
```

### Step 4: Review and Select Components

Each component in `setup-components/` has a header indicating if it's REUSABLE:

- **REUSABLE: YES** = Generic component, keep as-is or customize
- **REUSABLE: NO** = Project-specific, remove or heavily modify

**Action:** Read each component header and decide:
- Keep (generic and needed)
- Customize (partially relevant)
- Remove (not relevant to new project)

### Step 5: Remove Unnecessary Components

```bash
# Example: Remove mobile development if not needed
rm setup-components/20-mobile.sh
rm setup-components/21-java.sh
rm setup-components/22-flutter.sh
rm setup-components/23-android.sh
rm setup-components/24-ios.sh
rm setup-components/25-cloud-tools.sh
```

### Step 6: Create Project-Specific Components

For project-specific tools, create new components following the numbering scheme:

```bash
# Create a new component for the project
cat > setup-components/60-project-tools.sh << 'EOF'
#!/usr/bin/env bash
################################################################################
# Component: Project-Specific Tools
################################################################################
# PURPOSE: Install tools specific to [PROJECT NAME]
# REUSABLE: NO
# DEPENDENCIES: 00-homebrew, 10-essentials
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is project-specific and should be heavily customized
################################################################################

COMPONENT_NAME="Project-specific tools"

install_component() {
    section_start "$COMPONENT_NAME"

    # Example: Install project dependencies
    if [ -f "$REPO_ROOT/package.json" ]; then
        check_installing "npm dependencies"
        cd "$REPO_ROOT"
        npm install > /dev/null 2>&1
        check_done "npm dependencies"
    fi

    section_end
}
EOF
```

### Step 7: Test the Setup Script

```bash
# Syntax check
bash -n setup-macos.sh

# Dry-run test (if components are idempotent)
./setup-macos.sh --yes --verbose
```

### Step 8: Update Repository README

Add a reference to the setup script in the project's main README.md:

```markdown
## Development Setup

For macOS development environment setup:

\`\`\`bash
./scripts/macos-setup/setup-macos.sh
\`\`\`

See [scripts/macos-setup/README.md](./scripts/macos-setup/README.md) for details.
```

---

## Component Numbering Guide

Use this numbering scheme for new components:

| Range | Purpose | Examples |
|-------|---------|----------|
| 00-09 | Foundation (package managers) | `00-homebrew.sh` |
| 10-19 | Core development tools | `10-essentials.sh` (Node, Go, etc.) |
| 20-29 | Platform-specific dev | `20-mobile.sh`, `22-flutter.sh` |
| 30-49 | Additional tooling | `30-web-tools.sh`, `40-browser-tools.sh` |
| 50-59 | Utilities | `50-utilities.sh` |
| 60-69 | **Project-specific** | `60-project-tools.sh`, `61-database-setup.sh` |
| 70-79 | Configuration/environment | `70-env.sh` |
| 80-99 | Advanced/optional features | `80-mcp-claude-desktop.sh` |

**Coordination Components:** Some components (like `20-mobile.sh`) are coordinators that source sub-components:
- `20-mobile.sh` (coordinator) → `21-java.sh`, `22-flutter.sh`, `23-android.sh`, `24-ios.sh`, `25-cloud-tools.sh`

---

## Component Template

When creating new components, use this template:

```bash
#!/usr/bin/env bash
################################################################################
# Component: [Component Name]
################################################################################
# PURPOSE: [One-line description of what this component does]
# REUSABLE: [YES or NO]
# DEPENDENCIES: [List of required components, e.g., 00-homebrew, 10-essentials]
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - [Guidance for future AI assistants or humans adopting this component]
# - [What to customize, what to keep as-is]
# - [Any gotchas or important considerations]
################################################################################

# Component metadata
COMPONENT_NAME="[Display name shown during installation]"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # Check if tool is already installed
    if ! command -v [tool] &> /dev/null; then
        # Optionally confirm large downloads
        if timed_confirm "[Tool] is required. Install?"; then
            check_installing "[Tool name]"

            # Install command (suppress verbose output)
            brew install [tool] > /dev/null 2>&1

            # Verify installation succeeded
            if command -v [tool] &> /dev/null; then
                check_done "[Tool name]"
            else
                check_failed "[Tool name]"
            fi
        else
            print_warning "Skipping [tool] installation"
        fi
    else
        check_exists "[Tool name]"
    fi

    section_end
}
```

---

## Available Helper Functions

Components can use these functions (provided by main script and libraries):

### Status Reporting (Verbose Mode)

```bash
check_installing "Tool Name")    # Shows "[ ] Installing Tool Name..."
check_done "Tool Name")           # Shows "[✓] Installed Tool Name"
check_exists "Tool Name")         # Shows "[✓] Tool Name already installed"
check_failed "Tool Name")         # Shows "[✗] Failed to install Tool Name"
                                  # Also adds to FAILED_INSTALLS array
```

### Logging (Respects VERBOSE Flag)

```bash
print_info "Message")      # Shown only in verbose mode
print_success "Message")   # Shown only in verbose mode
print_warning "Message")   # Shown only in verbose mode
print_error "Message")     # ALWAYS shown (errors are never hidden)
```

### Section Management (Compact Mode)

```bash
section_start "Section Name")  # Begin a component section
section_update "Step Name")    # Update progress in compact mode
section_end()                  # End section (shows success/failure summary)
```

### User Confirmation

```bash
# Interactive prompt with timeout (respects AUTO_YES flag)
if timed_confirm "Install large package?"; then
    # User said yes or AUTO_YES=true
fi
```

### Global Variables Available in Components

```bash
$REPO_ROOT          # Absolute path to repository root
$AUTO_YES           # true if --yes flag passed (non-interactive mode)
$VERBOSE            # true if verbose output enabled
$SCRIPT_DIR         # Directory containing setup-macos.sh
$COMPONENT_DIR      # Directory containing components (setup-components/)
```

### Functions from lib/common.sh

```bash
# Logging
log_info "message")
log_success "message")
log_warning "message")
log_error "message")
log_debug "message")           # Only shown if DEBUG=1
log_header "Header Text")
log_section "Section Text")

# Error handling
die "Error message")           # Exit with error
require_command "git" "brew install git"  # Verify command exists
require_file "/path/to/file"   # Verify file exists
require_directory "/path/to/dir")  # Verify directory exists

# Path utilities
get_script_dir()               # Get directory of calling script
get_repo_root()                # Find repository root (.git directory)

# User interaction
ask_yes_no "Question?" "y")    # Returns 0 for yes, 1 for no
                               # Respects AUTO_YES global variable

# Platform checks
is_macos()                     # Returns 0 if macOS
is_linux()                     # Returns 0 if Linux
is_root()                      # Returns 0 if running as root
is_set VAR_NAME                # Returns 0 if variable is set

# String utilities
to_lowercase "STRING")
to_uppercase "STRING")
trim "  string  ")             # Remove leading/trailing whitespace
```

---

## Common Patterns

### Pattern 1: Install Homebrew Package

```bash
if ! command -v [tool] &> /dev/null; then
    check_installing "[Tool name]"
    brew install [tool] > /dev/null 2>&1
    check_done "[Tool name]"
else
    check_exists "[Tool name]"
fi
```

### Pattern 2: Install with Confirmation

```bash
if ! command -v [tool] &> /dev/null; then
    if timed_confirm "Install [tool]? (Large download)"; then
        check_installing "[Tool name]"
        brew install [tool] > /dev/null 2>&1
        check_done "[Tool name]"
    else
        print_warning "Skipping [tool]"
    fi
else
    check_exists "[Tool name]"
fi
```

### Pattern 3: Add to Shell Profile

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

### Pattern 4: Install npm/pip Package Globally

```bash
if ! command -v [tool] &> /dev/null; then
    check_installing "[Tool name]"
    npm install -g [package] > /dev/null 2>&1
    # OR: pip install [package] > /dev/null 2>&1
    check_done "[Tool name]"
else
    check_exists "[Tool name]"
fi
```

### Pattern 5: Clone and Configure Repository

```bash
TOOL_DIR="$HOME/.config/[tool]"
if [ ! -d "$TOOL_DIR" ]; then
    check_installing "[Tool] configuration"
    git clone https://github.com/[repo].git "$TOOL_DIR" > /dev/null 2>&1
    check_done "[Tool] configuration"
else
    check_exists "[Tool] configuration"
fi
```

---

## Workflow for AI Assistants

When asked to adopt this system, follow this workflow:

1. **Understand the Target Project**
   - What language(s) does it use?
   - What tools/frameworks are required?
   - Are there any special dependencies?

2. **Copy Base Structure**
   - Copy `lib/`, `setup-components/`, `setup-macos-template.sh`
   - Rename `setup-macos-template.sh` to `setup-macos.sh`

3. **Filter Components**
   - Keep: Generic components (00-homebrew, 10-essentials)
   - Review: Platform-specific components (20-mobile, 30-web-tools)
   - Remove: Unnecessary components
   - Customize: Partially relevant components

4. **Add Project-Specific Components**
   - Create 60-69 range components for project tools
   - Follow the component template
   - Use appropriate helper functions

5. **Test Syntax**
   - `bash -n setup-macos.sh`
   - `bash -n setup-components/*.sh`

6. **Document**
   - Update project README with setup instructions
   - Add adoption notes to new components

---

## Testing Checklist

Before committing, verify:

- [ ] All scripts pass syntax check: `bash -n *.sh`
- [ ] Main script sources libraries correctly
- [ ] Components export `install_component()` function
- [ ] Numbering follows the scheme (00-09, 10-19, etc.)
- [ ] Headers include PURPOSE, REUSABLE, DEPENDENCIES, ADOPTION NOTES
- [ ] Project-specific components use 60-69 range
- [ ] README.md updated with setup instructions

---

## Examples of Adoption

### Example 1: Python Data Science Project

**Scenario:** New Python project using pandas, jupyter, matplotlib

**Steps:**
1. Copy base structure
2. Remove: 20-mobile.sh and sub-components, 30-web-tools.sh, 40-browser-tools.sh
3. Keep: 00-homebrew, 10-essentials (for pyenv), 50-utilities
4. Create: `60-python-datascience.sh`

```bash
#!/usr/bin/env bash
################################################################################
# Component: Python Data Science Tools
################################################################################
# PURPOSE: Install Python data science stack (pandas, jupyter, matplotlib)
# REUSABLE: NO
# DEPENDENCIES: 00-homebrew
################################################################################

COMPONENT_NAME="Python data science tools"

install_component() {
    section_start "$COMPONENT_NAME"

    # Install pyenv if not present
    if ! command -v pyenv &> /dev/null; then
        check_installing "pyenv"
        brew install pyenv > /dev/null 2>&1
        check_done "pyenv"
    else
        check_exists "pyenv"
    fi

    # Install Python 3.11
    if ! pyenv versions | grep -q "3.11"; then
        check_installing "Python 3.11"
        pyenv install 3.11 > /dev/null 2>&1
        pyenv global 3.11
        check_done "Python 3.11"
    else
        check_exists "Python 3.11"
    fi

    # Install data science packages
    check_installing "Data science packages"
    pip install pandas jupyter matplotlib scikit-learn > /dev/null 2>&1
    check_done "Data science packages"

    section_end
}
```

### Example 2: React Web Application

**Scenario:** React + TypeScript project with ESLint, Prettier

**Steps:**
1. Copy base structure
2. Remove: 20-mobile.sh and sub-components, 50-utilities (unless needed)
3. Keep: 00-homebrew, 10-essentials (Node.js), 30-web-tools, 40-browser-tools (Playwright)
4. Customize: 30-web-tools to include specific versions
5. Create: `60-react-project.sh` for project-specific setup

### Example 3: Go Backend Service

**Scenario:** Go microservice with PostgreSQL, Redis

**Steps:**
1. Copy base structure
2. Remove: Mobile, web tools, browser tools
3. Keep: 00-homebrew, 10-essentials (includes Go)
4. Create: `60-backend-services.sh`

```bash
install_component() {
    section_start "$COMPONENT_NAME"

    # Install PostgreSQL
    if ! command -v psql &> /dev/null; then
        check_installing "PostgreSQL"
        brew install postgresql@15 > /dev/null 2>&1
        brew services start postgresql@15 > /dev/null 2>&1
        check_done "PostgreSQL"
    else
        check_exists "PostgreSQL"
    fi

    # Install Redis
    if ! command -v redis-cli &> /dev/null; then
        check_installing "Redis"
        brew install redis > /dev/null 2>&1
        brew services start redis > /dev/null 2>&1
        check_done "Redis"
    else
        check_exists "Redis"
    fi

    section_end
}
```

---

## Troubleshooting

### Component Not Executing

**Symptom:** Component file exists but doesn't run

**Checks:**
1. Does filename start with numeric prefix? (e.g., `60-mycomponent.sh`)
2. Is `install_component()` function defined?
3. Syntax valid? Run `bash -n component.sh`
4. Is component in `setup-components/` directory?

### Helper Functions Undefined

**Symptom:** `section_start: command not found`

**Checks:**
1. Is `lib/common.sh` being sourced in main script?
2. Is `lib/ui.sh` being sourced?
3. Are helper functions defined before component loop?

### Wrong Execution Order

**Symptom:** Component runs before dependencies

**Fix:**
- Rename with appropriate prefix
- Remember lexicographic order: 00 < 10 < 20 < ... < 90
- Dependencies should have lower numbers than dependents

---

## Summary

**To adopt this system in a new repo:**

1. ✅ Copy `lib/`, `setup-components/`, `setup-macos-template.sh`
2. ✅ Rename to `setup-macos.sh`
3. ✅ Update header with project name
4. ✅ Remove unnecessary components
5. ✅ Create project-specific components (60-69)
6. ✅ Test syntax: `bash -n setup-macos.sh`
7. ✅ Update project README
8. ✅ Run setup: `./setup-macos.sh --yes --verbose`

**Remember:** This system is designed to be **copied and customized**, not used as a submodule or dependency.

---

## Questions for AI Assistants

If uncertain during adoption, ask the user:

1. "What development tools does this project require?"
2. "Are there any large downloads I should confirm before installing?"
3. "Should I keep the mobile development components (Flutter, Android, iOS)?"
4. "Does this project need database setup (PostgreSQL, MySQL, Redis)?"
5. "Should I create a project-specific component for installing dependencies?"

**Default approach:** When in doubt, keep it minimal. It's easier to add components later than to remove unwanted installations.

---

**Last Updated:** 2025-11-16
**Version:** 1.0
