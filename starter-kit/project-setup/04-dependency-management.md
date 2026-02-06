# Phase 3: Dependency Management (1-2 hours)

## 3.1 Create setup-macos.sh

Create `scripts/setup-macos.sh`:

```bash
#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

log_info "Starting macOS development environment setup..."

# Source all components
for component in scripts/setup-components/*.sh; do
  source "$component"
done

# Run installation
install_homebrew
install_essentials
install_project_dependencies

log_info "Setup complete!"
```

Make it executable:

```bash
chmod +x scripts/setup-macos.sh
```

## 3.2 Create Component: Homebrew

Create `scripts/setup-components/00-homebrew.sh`:

```bash
#!/usr/bin/env bash

install_homebrew() {
  if ! command -v brew &> /dev/null; then
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    log_info "Homebrew already installed"
  fi
}
```

## 3.3 Create Component: Essentials

Create `scripts/setup-components/10-essentials.sh`:

```bash
#!/usr/bin/env bash

install_essentials() {
  log_info "Installing essential tools..."
  
  brew install git
  brew install wget
  brew install jq
  brew install node
  
  log_info "Essential tools installed"
}
```

## 3.4 Create Component: Project Dependencies

Create `scripts/setup-components/60-project.sh`:

```bash
#!/usr/bin/env bash

install_project_dependencies() {
  log_info "Installing project dependencies..."
  
  # Node.js dependencies
  if [ -f "package.json" ]; then
    npm install
  fi
  
  # Go dependencies
  if [ -f "go.mod" ]; then
    go mod download
  fi
  
  # Python dependencies
  if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt
  fi
  
  log_info "Project dependencies installed"
}
```

## 3.5 Create setup-linux.sh

Create `scripts/setup-linux.sh`:

```bash
#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

log_info "Starting Linux development environment setup..."

# Update package manager
sudo apt-get update

# Install essentials
sudo apt-get install -y git wget curl jq build-essential

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

log_info "Setup complete!"
```

Make it executable:

```bash
chmod +x scripts/setup-linux.sh
```

## Verification

```bash
# Test on fresh machine or VM
./scripts/setup-macos.sh  # or setup-linux.sh

# Verify all tools installed
git --version
node --version
npm --version
```

