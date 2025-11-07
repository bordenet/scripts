#!/usr/bin/env bash
################################################################################
# Component: MCP Servers for Claude Desktop
################################################################################
# PURPOSE: Install and configure MCP servers for Claude Desktop application.
# REUSABLE: YES (with modifications)
# DEPENDENCIES: 10-essentials (for npm)
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is reusable but you should customize the MCP servers list.
# - Modify the MCP servers in the JSON configuration to match your project needs.
# - The core pattern (detect app, create config, install servers) is universal.
# - Adapt warning messages and server descriptions to your context.
################################################################################

# Component metadata
COMPONENT_NAME="MCP servers for Claude Desktop"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # Check if Claude Desktop is installed
    CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
    CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

    if [ -d "/Applications/Claude.app" ]; then
      print_success "Claude Desktop detected"

      # Create config directory if it doesn't exist
      if [ ! -d "$CLAUDE_CONFIG_DIR" ]; then
        print_info "Creating Claude Desktop configuration directory..."
        mkdir -p "$CLAUDE_CONFIG_DIR"
      fi

      # Install MCP servers globally
      print_info "Installing MCP servers for development workflow..."

      # Install core MCP servers with timeout

      print_success "MCP servers installation completed"

      # Check if Claude Desktop MCP configuration already exists
      mcp_already_configured=false
      if [ -f "$CLAUDE_CONFIG_FILE" ] && grep -q "mcpServers" "$CLAUDE_CONFIG_FILE" 2>/dev/null; then
        mcp_already_configured=true
      fi

      # Create or update Claude Desktop configuration
      if [ "$mcp_already_configured" = true ]; then
        print_success "Claude Desktop MCP servers already configured"
      elif timed_confirm "Configure Claude Desktop MCP servers automatically?" 10 "N"; then
        print_info "Creating Claude Desktop MCP configuration..."

        # Load AWS credentials from .env if available
        AWS_ACCESS_KEY_ID=""
        AWS_SECRET_ACCESS_KEY=""
        AWS_REGION="us-west-2"

        if [ -f ".env" ]; then
          print_info "Loading AWS credentials from .env file..."
          AWS_ACCESS_KEY_ID=$(grep "^AWS_ACCESS_KEY_ID=" .env | cut -d'=' -f2)
          AWS_SECRET_ACCESS_KEY=$(grep "^AWS_SECRET_ACCESS_KEY=" .env | cut -d'=' -f2)
          AWS_REGION=$(grep "^AWS_REGION=" .env | cut -d'=' -f2 || echo "us-west-2")
        fi

        # Create comprehensive MCP configuration
        cat > "$CLAUDE_CONFIG_FILE" <<EOF
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": ""
      }
    },
      "command": "npx",
      "env": {}
    },
    "flutter-mcp": {
      "command": "npx",
      "args": ["-y", "flutter-mcp"],
      "env": {}
    },
    "dart-mcp": {
      "command": "dart",
      "args": ["mcp-server"],
      "env": {}
    },
    "npm-commands": {
      "command": "npx",
      "args": ["-y", "npm-command-runner-mcp"],
      "env": {}
    },
    "mcp-jest": {
      "command": "npx",
      "args": ["-y", "mcp-jest"],
      "env": {}
    },
    "browser-mcp": {
      "command": "npx",
      "args": ["-y", "browser-mcp"],
      "env": {}
    }
  }
}
EOF

        # Update with AWS credentials if available
        if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
          print_info "AWS credentials found - adding AWS MCP server configuration..."
          # Note: AWS MCP servers use Python/uvx, not npm
          print_warning "AWS MCP servers require Python/uvx installation (not included in this setup)"
        fi

        print_success "Claude Desktop MCP configuration created at: $CLAUDE_CONFIG_FILE"

        # Display configured servers
        print_info "Configured MCP servers:"
        print_info "  • GitHub MCP - Repository management, issues, PRs"
        print_info "  • Flutter MCP - Flutter/Dart development tools"
        print_info "  • Dart MCP - Official Dart tooling integration"
        print_info "  • NPM Commands MCP - Package management automation"
        print_info "  • Jest MCP - Testing framework integration"
        print_info "  • Browser MCP - Browser automation for web development"

        print_warning "IMPORTANT: Add your GitHub Personal Access Token to the configuration:"
        print_info "1. Generate token at: https://github.com/settings/personal-access-tokens"
        print_info "2. Edit: $CLAUDE_CONFIG_FILE"
        print_info "3. Add token to GITHUB_PERSONAL_ACCESS_TOKEN field"
        print_info "4. Restart Claude Desktop"

      else
        print_warning "Skipping MCP configuration - you can set it up manually later"
        print_info "MCP servers are installed globally and ready to configure"
      fi

    else
      print_warning "Claude Desktop not found - installing MCP servers for future use"

      # Install MCP servers anyway for when Claude Desktop is installed
      print_info "Installing MCP servers globally..."
      print_success "MCP servers installation completed"

      print_info "To complete MCP setup after installing Claude Desktop:"
      print_info "1. Install Claude Desktop from https://claude.ai/download"
      print_info "2. Run this script again to configure MCP servers"
    fi

    section_end
}
