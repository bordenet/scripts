# Dependency Management

## Purpose

Ensure reproducible environments by capturing ALL dependencies in a single script.

## Implementation (setup-macos.sh)

**Modular Component Architecture**:

```
scripts/
├── setup-macos.sh              # Main entry point
└── setup-components/
    ├── 00-homebrew.sh          # Package manager
    ├── 10-essentials.sh        # Core tools (git, wget, etc.)
    ├── 20-mobile.sh            # Flutter, Android Studio, Xcode
    ├── 30-web-tools.sh         # Node.js, npm
    ├── 40-browser-tools.sh     # Chrome, Safari dev tools
    ├── 50-utilities.sh         # Optional tools
    ├── 60-monorepo.sh          # Project-specific setup
    ├── 70-env.sh               # Environment variables
    ├── 80-mcp-claude-desktop.sh # AI tools
    └── 90-mcp-claude-code.sh   # AI development tools
```

## Example Component (`10-essentials.sh`)

```bash
#!/usr/bin/env bash

install_essentials() {
  section_start "Essential Development Tools"

  # Git
  if ! command -v git &> /dev/null; then
    brew install git
  fi

  # wget
  if ! command -v wget &> /dev/null; then
    brew install wget
  fi

  # jq (JSON processor)
  if ! command -v jq &> /dev/null; then
    brew install jq
  fi

  section_end
}
```

## Main Script (`setup-macos.sh`)

```bash
#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
init_script

# Source all components
for component in scripts/setup-components/*.sh; do
  source "$component"
done

# Run installation
log_header "your-project Development Environment Setup"

install_homebrew
install_essentials
install_mobile_tools
install_web_tools
install_browser_tools
install_utilities
setup_monorepo
configure_environment
install_mcp_tools

log_success "Setup complete!"
```

## Benefits

- ✅ New team members: One command to full environment
- ✅ CI/CD: Reproducible build environments
- ✅ Documentation: Script IS the documentation
- ✅ Maintenance: Update script when dependencies change

