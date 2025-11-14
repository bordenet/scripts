#!/usr/bin/env bash
#
# setup-and-run.sh - One-command setup and execution for review-codebase
#
# This script handles all dependency installation, virtual environment setup,
# and execution so non-Python engineers can get immediate value without
# dealing with venv management.
#
# Usage:
#   ./setup-and-run.sh              # Start web UI
#   ./setup-and-run.sh /path/to/repo  # CLI mode
#   ./setup-and-run.sh -h           # Show help

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
SETUP_FILE="${SCRIPT_DIR}/setup.py"
PYTHON_MIN_VERSION="3.9"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

show_help() {
    cat <<EOF
review-codebase - Setup and Run Script

USAGE:
    $(basename "$0") [OPTIONS] [REPOSITORY_PATH]

OPTIONS:
    -h, --help          Show this help message and exit
    -f, --force-setup   Force recreation of virtual environment
    -v, --verbose       Enable verbose output

ARGUMENTS:
    REPOSITORY_PATH     Optional path to repository for CLI mode.
                        If not provided, starts web UI mode.

MODES:
    Web UI Mode (default):
        ./setup-and-run.sh
        Starts the web interface on http://localhost:5000

    CLI Mode:
        ./setup-and-run.sh /path/to/repository
        Analyzes the specified repository and outputs results

EXAMPLES:
    # Start web UI
    ./setup-and-run.sh

    # Analyze a repository via CLI
    ./setup-and-run.sh ~/projects/my-app

    # Force rebuild of environment
    ./setup-and-run.sh --force-setup

    # Get help
    ./setup-and-run.sh --help

NOTES:
    - First run will install all dependencies (may take 1-2 minutes)
    - Virtual environment is managed automatically in .venv/
    - Python ${PYTHON_MIN_VERSION}+ is required

EOF
}

check_python_version() {
    local python_cmd="$1"

    if ! command -v "$python_cmd" &>/dev/null; then
        return 1
    fi

    local version
    version=$("$python_cmd" --version 2>&1 | awk '{print $2}')
    local major minor
    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)

    # Check if version >= 3.9
    if [[ "$major" -ge 3 ]] && [[ "$minor" -ge 9 ]]; then
        echo "$python_cmd"
        return 0
    fi

    return 1
}

find_python() {
    # Try different Python commands in order of preference
    local python_commands=("python3.12" "python3.11" "python3.10" "python3.9" "python3" "python")

    for cmd in "${python_commands[@]}"; do
        if python_cmd=$(check_python_version "$cmd"); then
            echo "$python_cmd"
            return 0
        fi
    done

    return 1
}

setup_venv() {
    local force_setup="${1:-false}"

    # Check if venv exists and is valid
    if [[ "$force_setup" == "false" ]] && [[ -d "$VENV_DIR" ]] && [[ -f "$VENV_DIR/bin/python" ]]; then
        log_info "Virtual environment already exists"
        return 0
    fi

    log_info "Setting up virtual environment..."

    # Remove old venv if it exists
    if [[ -d "$VENV_DIR" ]]; then
        log_warning "Removing old virtual environment"
        rm -rf "$VENV_DIR"
    fi

    # Find Python
    local python_cmd
    if ! python_cmd=$(find_python); then
        log_error "Python ${PYTHON_MIN_VERSION}+ is required but not found"
        log_error "Please install Python ${PYTHON_MIN_VERSION} or later"
        exit 1
    fi

    log_info "Using Python: $python_cmd ($($python_cmd --version 2>&1))"

    # Create virtual environment
    log_info "Creating virtual environment..."
    "$python_cmd" -m venv "$VENV_DIR"

    log_success "Virtual environment created"
}

install_dependencies() {
    log_info "Checking dependencies..."

    # Activate virtual environment
    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"

    # Upgrade pip
    log_info "Upgrading pip..."
    python -m pip install --upgrade pip --quiet

    # Check if dependencies are already installed
    if python -c "import codebase_reviewer" 2>/dev/null; then
        log_info "Dependencies already installed"
        return 0
    fi

    # Install dependencies
    log_info "Installing dependencies (this may take 1-2 minutes)..."

    if [[ -f "$REQUIREMENTS_FILE" ]]; then
        pip install -r "$REQUIREMENTS_FILE" --quiet
    fi

    if [[ -f "$SETUP_FILE" ]]; then
        pip install -e "$SCRIPT_DIR" --quiet
    fi

    log_success "Dependencies installed"
}

# ============================================================================
# Main Logic
# ============================================================================

main() {
    local force_setup=false
    local repo_path=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force-setup)
                force_setup=true
                shift
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo ""
                show_help
                exit 1
                ;;
            *)
                repo_path="$1"
                shift
                ;;
        esac
    done

    # Change to script directory
    cd "$SCRIPT_DIR"

    echo ""
    log_info "review-codebase Setup & Run"
    echo ""

    # Setup virtual environment
    setup_venv "$force_setup"

    # Install dependencies
    install_dependencies

    # Activate virtual environment
    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"

    echo ""

    # Run the tool
    if [[ -n "$repo_path" ]]; then
        # CLI mode
        log_info "Running in CLI mode for: $repo_path"
        echo ""

        if [[ ! -d "$repo_path" ]]; then
            log_error "Repository path does not exist: $repo_path"
            exit 1
        fi

        # Run analysis
        python -m codebase_reviewer analyze "$repo_path"

    else
        # Web UI mode
        log_info "Starting web UI..."
        log_info "Access at: http://localhost:5000"
        echo ""
        log_warning "Press Ctrl+C to stop the server"
        echo ""

        # Run web server
        python -m codebase_reviewer web
    fi
}

# ============================================================================
# Entry Point
# ============================================================================

main "$@"
