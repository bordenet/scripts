#!/usr/bin/env bash
################################################################################
# Component: MCP Servers for Claude Code CLI
################################################################################
# PURPOSE: Install and configure MCP servers for Claude Code CLI.
# REUSABLE: YES (with modifications)
# DEPENDENCIES: 10-essentials (for npm)
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is reusable but customize the MCP servers list.
# - Modify the MCP servers to match your project needs.
# - The core pattern (install CLI, configure servers) is universal.
# - Adapt paths and server configurations to your context.
################################################################################

# Component metadata
COMPONENT_NAME="MCP servers for Claude Code CLI"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # Ensure ~/.local/bin directory exists
    LOCAL_BIN_DIR="$HOME/.local/bin"
    if [ ! -d "$LOCAL_BIN_DIR" ]; then
      print_info "Creating ~/.local/bin directory..."
      mkdir -p "$LOCAL_BIN_DIR"
      print_success "Created ~/.local/bin directory"
    fi

    # Add ~/.local/bin to PATH if not already present
    if [[ ":$PATH:" != *":$LOCAL_BIN_DIR:"* ]]; then
      print_info "Adding ~/.local/bin to PATH..."

      # Add to current session
      export PATH="$LOCAL_BIN_DIR:$PATH"

      # Add to shell profile for persistence
      SHELL_PROFILE=""
      if [ -n "$ZSH_VERSION" ]; then
        SHELL_PROFILE="$HOME/.zshrc"
      elif [ -n "$BASH_VERSION" ]; then
        SHELL_PROFILE="$HOME/.bash_profile"
      fi

      if [ -n "$SHELL_PROFILE" ] && [ -f "$SHELL_PROFILE" ]; then
        if ! grep -q "export PATH=\"\$HOME/.local/bin:\$PATH\"" "$SHELL_PROFILE"; then
          echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_PROFILE"
          print_success "Added ~/.local/bin to PATH in $SHELL_PROFILE"
        fi
      fi
    fi

    # Install Claude Code CLI if not available
    if ! command -v claude &> /dev/null; then
      print_info "Installing Claude Code CLI..."

      # Try multiple installation methods
      if timed_confirm "Install Claude Code CLI? This enables advanced MCP server integration." 10 "Y"; then

        # Method 1: Try npm global install
        if command -v npm &> /dev/null; then
          print_info "Installing via npm..."
          timeout 120 npm install -g @anthropics/claude-cli || print_warning "npm installation failed or timed out, trying alternative method"
        fi

        # Method 2: Try downloading binary directly
        if ! command -v claude &> /dev/null; then
          print_info "Downloading Claude Code CLI binary..."

          # Detect architecture
          ARCH=$(uname -m)
          if [ "$ARCH" = "arm64" ]; then
            CLAUDE_URL="https://storage.googleapis.com/anthropic-cli/claude-macos-arm64"
          else
            CLAUDE_URL="https://storage.googleapis.com/anthropic-cli/claude-macos-x64"
          fi

          # Download and install
          if curl -L "$CLAUDE_URL" -o "$LOCAL_BIN_DIR/claude" 2>/dev/null; then
            chmod +x "$LOCAL_BIN_DIR/claude"
            print_success "Claude Code CLI binary installed"
          else
            print_warning "Failed to download Claude Code CLI binary"
          fi
        fi

        # Method 3: Manual installation instructions
        if ! command -v claude &> /dev/null; then
          print_warning "Automatic installation failed. Manual installation required:"
          print_info "1. Visit: https://claude.ai/cli"
          print_info "2. Download the appropriate binary for macOS"
          print_info "3. Move to ~/.local/bin/claude and make executable"
          print_info "4. Restart terminal and run this script again"
        fi
      else
        print_warning "Skipping Claude Code CLI installation"
      fi
    fi

    # Check if Claude Code CLI is available after installation attempt
    if command -v claude &> /dev/null; then
      print_success "Claude Code CLI detected"

      # Configure essential MCP servers for Claude Code
      print_info "Configuring MCP servers for Claude Code development workflow..."

      # Add GitHub MCP server (requires authentication)
      if ! timeout 10 claude mcp list 2>/dev/null | grep -q "github"; then
        check_installing "GitHub MCP server"
        if timeout 30 claude mcp add github npx @modelcontextprotocol/server-github --scope user 2>/dev/null; then
          check_done "GitHub MCP server"
        else
          check_failed "GitHub MCP server"
        fi
      else
        check_exists "GitHub MCP server"
      fi

      # Add filesystem MCP server for project directory
      if ! timeout 10 claude mcp list 2>/dev/null | grep -q "filesystem"; then
        check_installing "Filesystem MCP server"
        if timeout 30 claude mcp add filesystem npx @modelcontextprotocol/server-filesystem "$(pwd)" --scope user 2>/dev/null; then
          check_done "Filesystem MCP server"
        else
          check_failed "Filesystem MCP server"
        fi
      else
        check_exists "Filesystem MCP server"
      fi

      # Add Flutter MCP server
      if ! timeout 10 claude mcp list 2>/dev/null | grep -q "flutter"; then
        check_installing "Flutter MCP server"
        if timeout 30 claude mcp add flutter npx flutter-mcp --scope user 2>/dev/null; then
          check_done "Flutter MCP server"
        else
          check_failed "Flutter MCP server"
        fi
      else
        check_exists "Flutter MCP server"
      fi

      print_warning "IMPORTANT: Set up GitHub authentication:"
      print_info "1. Generate a GitHub Personal Access Token"
      print_info "2. Set GITHUB_TOKEN environment variable or configure in Claude Code"

    else
      print_warning "Claude Code CLI not found after installation attempts"
      print_info "To set up Claude Code MCP servers manually later:"
      print_info "1. Install Claude Code CLI from https://claude.ai/cli"
      print_info "2. Ensure ~/.local/bin is in your PATH"
      print_info "3. Run: claude mcp add github npx @modelcontextprotocol/server-github --scope user"
      print_info "4. Run: claude mcp add filesystem npx @modelcontextprotocol/server-filesystem \$(pwd) --scope user"
      print_info "6. Run: claude mcp add flutter npx flutter-mcp --scope user"
    fi

    section_end
}
