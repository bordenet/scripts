#!/usr/bin/env bash
################################################################################
# Component: Web Development Tools
################################################################################
# PURPOSE: Install and configure tools for web development.
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is reusable.
# - Review the list of VS Code extensions and customize if needed.
################################################################################

# Component metadata
COMPONENT_NAME="Web development tools"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # ImageMagick (for icon generation)
    if ! command -v magick &> /dev/null; then
      check_installing "ImageMagick"
      brew install imagemagick > /dev/null 2>&1
      check_done "ImageMagick"
    else
      check_exists "ImageMagick"
    fi

    # Git (usually pre-installed but ensure latest)
    if ! command -v git &> /dev/null; then
      check_installing "Git"
      brew install git > /dev/null 2>&1
      check_done "Git"
    else
      check_exists "Git ($(git --version | awk '{print $3}'))"
    fi

    # Visual Studio Code
    if ! command -v code &> /dev/null; then
      if timed_confirm "Visual Studio Code is recommended for development. Install? (Large download ~200MB)"; then
        check_installing "Visual Studio Code"
        brew install --cask visual-studio-code > /dev/null 2>&1
        check_done "Visual Studio Code"
      else
        print_warning "Skipping VS Code - you can install it later with: brew install --cask visual-studio-code"
      fi
    else
      check_exists "Visual Studio Code"
    fi



    # Install VS Code extensions
    if command -v code &> /dev/null; then
      if timed_confirm "Install VS Code extensions from .vscode/extensions.txt?"; then
        if [ -f ".vscode/extensions.txt" ]; then
          print_info "Installing VS Code extensions from .vscode/extensions.txt..."
          while IFS= read -r extension; do
            if [ -n "$extension" ]; then
              # Use 'code --install-extension' but suppress all output for already-installed extensions
              if ! code --list-extensions 2>/dev/null | grep -q "^${extension}$"; then
                check_installing "$extension"
                if code --install-extension "$extension" > /dev/null 2>&1; then
                  check_done "$extension"
                else
                  check_failed "$extension"
                fi
              fi
            fi
          done < ".vscode/extensions.txt"
          print_success "Extensions from .vscode/extensions.txt installed"
        else
          print_warning "No .vscode/extensions.txt found. Skipping extension installation."
        fi
      fi

      print_info "Installing comprehensive VS Code extensions..."

      # Essential extensions for our tech stack
      declare -a extensions=(
        "golang.go"                                    # Go language support
        "ms-vscode.vscode-typescript-next"            # TypeScript support
        "ms-vscode.vscode-node-azure-pack"            # Node.js development
        "amazonwebservices.aws-toolkit-vscode"        # AWS development
        "hashicorp.terraform"                         # Infrastructure as Code
        "ms-vscode-remote.remote-containers"          # Container development
        "ms-vscode-remote.remote-ssh"                 # Remote development
        "vscode-icons-team.vscode-icons"              # File icons
        "redhat.vscode-yaml"                          # YAML support
        "ms-python.python"                            # Python support (for automation)
        "bradlc.vscode-tailwindcss"                   # Tailwind CSS (future web app)
        "esbenp.prettier-vscode"                      # Code formatting
        "ms-vscode.test-adapter-converter"            # Testing support
        "hbenl.vscode-test-explorer"                  # Test explorer
        "ms-playwright.playwright"                    # Playwright test support
      )

      new_installs=0
      already_installed=0

      for extension in "${extensions[@]}"; do
        if ! code --list-extensions 2>/dev/null | grep -q "^${extension}$"; then
          check_installing "$extension"
          if code --install-extension "$extension" --force > /dev/null 2>&1; then
            check_done "$extension"
            new_installs=$((new_installs + 1))
          else
            check_failed "$extension"
          fi
        else
          already_installed=$((already_installed + 1))
        fi
      done

      if [ $new_installs -gt 0 ]; then
        print_success "Installed $new_installs new VS Code extensions"
      fi
      if [ $already_installed -gt 0 ]; then
        print_info "$already_installed extensions already installed"
      fi
    fi

    section_end
}
