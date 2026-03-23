#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: install-augment-superpowers.sh
# PURPOSE: Install the superpowers skill system for Augment Code
# USAGE: ./install-augment-superpowers.sh [-v|--verbose] [-h|--help]
#        curl -fsSL https://...install-augment-superpowers.sh | bash
# PLATFORM: macOS, Linux, WSL
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Configuration ---
VERSION="2.0.0"
SUPERPOWERS_REPO="https://github.com/obra/superpowers.git"
SUPERPOWERS_DIR="$HOME/.codex/superpowers"
SKILLS_DIR="$HOME/.agents/skills"
RULES_DIR="$HOME/.augment/rules"
VERBOSE=false

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Logging ---
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
verbose() { [[ "$VERBOSE" == true ]] && echo -e "${BLUE}[DEBUG]${NC} $1" || true; }

# --- Help ---
show_help() {
    cat << 'EOF'
NAME
    install-augment-superpowers.sh - Install superpowers skill system for Augment Code

SYNOPSIS
    install-augment-superpowers.sh [OPTIONS]
    curl -fsSL https://raw.githubusercontent.com/bordenet/scripts/main/experimental/install-augment-superpowers.sh | bash

DESCRIPTION
    Installs the superpowers skill system (from obra/superpowers) and configures
    it to work with Augment Code via native skill discovery. Skills are
    symlinked into ~/.agents/skills/ so Augment discovers them automatically
    in its <available_skills> catalog.

    The installer is self-contained and can be run via curl pipe or directly.
    Re-running is safe (idempotent) — it updates existing installations.

WHAT GETS INSTALLED
    ~/.codex/superpowers/           Superpowers core (cloned from obra/superpowers)
    ~/.agents/skills/<skill>/       Symlinks to each superpowers skill
    ~/.augment/rules/               Augment auto-load rule for skill protocol

OPTIONS
    -h, --help      Display this help message and exit
    -v, --verbose   Show detailed progress information
    --version       Display version information and exit

PREREQUISITES
    • git - For cloning the superpowers repository

EXAMPLES
    # Install with default settings
    ./install-augment-superpowers.sh

    # Install with verbose output
    ./install-augment-superpowers.sh --verbose

    # Install via curl (one-liner)
    curl -fsSL https://raw.githubusercontent.com/bordenet/scripts/main/experimental/install-augment-superpowers.sh | bash

POST-INSTALLATION
    1. Restart Augment (or start a new conversation)
    2. Skills appear automatically in Augment's <available_skills> catalog
    3. The using-superpowers skill governs when/how skills are invoked

AUTHOR
    Matt J Bordenet

SEE ALSO
    https://github.com/obra/superpowers
    https://augmentcode.com
EOF
    exit 0
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help ;;
        -v|--verbose) VERBOSE=true; shift ;;
        --version) echo "install-augment-superpowers.sh version $VERSION"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; echo "Use -h or --help for usage" >&2; exit 1 ;;
    esac
done

# --- Main Installation ---
echo ""
echo "=============================================="
echo "  Superpowers for Augment - Installer v$VERSION"
echo "=============================================="
echo ""

# Check prerequisites
info "Checking prerequisites..."

# Detect platform for install hints
PLATFORM="unknown"
INSTALL_HINT="your package manager"
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macOS"
    INSTALL_HINT="brew install"
elif [[ -f /etc/os-release ]] && grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
    PLATFORM="WSL"
    INSTALL_HINT="sudo apt install"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="Linux"
    INSTALL_HINT="sudo apt install"
fi
verbose "Detected platform: $PLATFORM"

if ! command -v git &> /dev/null; then
    error "git is required but not installed. Install with: $INSTALL_HINT git"
fi
success "git found"
verbose "git version: $(git --version)"

# Create directories
info "Creating directories..."
verbose "Creating $SKILLS_DIR"
mkdir -p "$SKILLS_DIR"
verbose "Creating $RULES_DIR"
mkdir -p "$RULES_DIR"
success "Directories created"

# --- Step 1: Clone or update superpowers ---
if [[ -d "$SUPERPOWERS_DIR/.git" ]]; then
    info "Superpowers already installed, updating..."
    verbose "Running git pull in $SUPERPOWERS_DIR"
    pushd "$SUPERPOWERS_DIR" > /dev/null
    if git pull --quiet origin main 2>/dev/null || git pull --quiet origin master 2>/dev/null; then
        success "Superpowers updated"
    else
        warn "Could not update superpowers (continuing with existing version)"
    fi
    popd > /dev/null
else
    info "Installing superpowers from obra/superpowers..."
    # Clone to temp dir first — if clone fails, existing install is untouched
    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/superpowers-install.XXXXXX")
    verbose "Cloning $SUPERPOWERS_REPO to $tmp_dir"
    if ! git clone --quiet "$SUPERPOWERS_REPO" "$tmp_dir/superpowers"; then
        rm -rf "$tmp_dir"
        error "git clone failed. Check network and try again."
    fi
    # Replace old dir only after clone succeeds
    if [[ -e "$SUPERPOWERS_DIR" ]]; then
        # Move old dir aside, swap new in, then remove old
        mv "$SUPERPOWERS_DIR" "$tmp_dir/superpowers-old"
    fi
    mv "$tmp_dir/superpowers" "$SUPERPOWERS_DIR"
    rm -rf "$tmp_dir"
    success "Superpowers installed"
fi

# --- Step 2: Create skill symlinks for native discovery ---
info "Creating skill symlinks in $SKILLS_DIR..."

# Build set of expected skill names
EXPECTED_SKILLS=()
SKILL_COUNT=0
for skill_dir in "$SUPERPOWERS_DIR"/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name=$(basename "$skill_dir")

    # Only symlink skills that have a SKILL.md (proper skill definition)
    if [[ ! -f "$skill_dir/SKILL.md" ]]; then
        verbose "Skipping $skill_name (no SKILL.md)"
        continue
    fi

    EXPECTED_SKILLS+=("$skill_name")
    target="$SKILLS_DIR/$skill_name"
    if [[ -L "$target" ]]; then
        # Only replace symlinks that point into superpowers (preserve user overrides)
        current=$(readlink "$target")
        case "$current" in
            "$SUPERPOWERS_DIR/skills/"*)
                rm -f "$target"
                ln -s "$skill_dir" "$target"
                verbose "Updated symlink: $skill_name"
                ;;
            *)
                verbose "Preserving user symlink: $skill_name -> $current"
                ;;
        esac
    elif [[ -e "$target" ]]; then
        warn "Skipping $skill_name — $target exists and is not a symlink"
        continue
    else
        verbose "Creating symlink: $skill_name -> $skill_dir"
        ln -s "$skill_dir" "$target"
    fi
    SKILL_COUNT=$((SKILL_COUNT + 1))
done

# Prune stale symlinks that point into superpowers but no longer correspond to a skill
PRUNED=0
for entry in "$SKILLS_DIR"/*; do
    [[ -L "$entry" ]] || continue
    link_target=$(readlink "$entry")
    # Only prune symlinks that point into the superpowers skills directory
    case "$link_target" in
        "$SUPERPOWERS_DIR/skills/"*)
            entry_name=$(basename "$entry")
            # Check if this skill is still expected
            found=false
            for expected in "${EXPECTED_SKILLS[@]}"; do
                if [[ "$expected" == "$entry_name" ]]; then
                    found=true
                    break
                fi
            done
            if [[ "$found" == false ]]; then
                verbose "Pruning stale symlink: $entry_name"
                rm -f "$entry"
                PRUNED=$((PRUNED + 1))
            fi
            ;;
    esac
done

if [[ $PRUNED -gt 0 ]]; then
    info "Pruned $PRUNED stale symlink(s)"
fi
success "Linked $SKILL_COUNT skills"

# --- Step 3: Clean up legacy adapter ---
if [[ -d "$HOME/.codex/superpowers-augment" ]]; then
    info "Removing legacy superpowers-augment adapter..."
    verbose "Removing $HOME/.codex/superpowers-augment"
    rm -rf "$HOME/.codex/superpowers-augment"
    success "Legacy adapter removed"
fi

# --- Step 4: Install Augment auto-load rule ---
info "Installing Augment auto-load rule..."
cat > "$RULES_DIR/superpowers.always.md" << 'RULE_EOF'
# Superpowers Skills

At the START of every conversation, read the `using-superpowers` skill from `<available_skills>`.

Your skills are listed in `<available_skills>`. Read a skill's SKILL.md at the path shown in its `<location>` tag.

Priority: user instructions > skill procedures > system defaults.
Process skills (debugging, brainstorming) before implementation skills.
IF A SKILL APPLIES TO YOUR TASK (even 1% chance), YOU MUST READ AND FOLLOW IT.
RULE_EOF
success "Augment rule installed"

# --- Step 5: Verify installation ---
info "Verifying installation..."
echo ""

VERIFY_FAIL=0

# Check superpowers repo exists
if [[ -d "$SUPERPOWERS_DIR/skills" ]]; then
    success "Superpowers core installed ($SUPERPOWERS_DIR)"
else
    echo -e "${RED}[FAIL]${NC} Superpowers core not found" >&2
    VERIFY_FAIL=1
fi

# Check skill symlinks resolve (iterate without trailing slash to catch broken links)
LINKED=0
BROKEN=0
for entry in "$SKILLS_DIR"/*; do
    [[ -L "$entry" ]] || continue
    # Only check superpowers-owned symlinks
    link_target=$(readlink "$entry")
    case "$link_target" in
        "$SUPERPOWERS_DIR/skills/"*)
            if [[ -f "$entry/SKILL.md" ]]; then
                LINKED=$((LINKED + 1))
            else
                echo -e "${RED}[FAIL]${NC} Broken symlink: $entry -> $link_target" >&2
                BROKEN=$((BROKEN + 1))
            fi
            ;;
    esac
done

if [[ $LINKED -gt 0 && $BROKEN -eq 0 ]]; then
    success "$LINKED skill symlinks verified"
elif [[ $LINKED -gt 0 ]]; then
    warn "$LINKED skills OK, $BROKEN broken symlinks"
    VERIFY_FAIL=1
else
    echo -e "${RED}[FAIL]${NC} No skill symlinks found" >&2
    VERIFY_FAIL=1
fi

# Check rule file exists
if [[ -f "$RULES_DIR/superpowers.always.md" ]]; then
    success "Augment auto-load rule installed"
else
    echo -e "${RED}[FAIL]${NC} Augment rule not found" >&2
    VERIFY_FAIL=1
fi

# Check the meta-skill is accessible
if [[ -f "$SKILLS_DIR/using-superpowers/SKILL.md" ]]; then
    success "Meta-skill (using-superpowers) accessible"
else
    echo -e "${RED}[FAIL]${NC} using-superpowers skill not found at $SKILLS_DIR/using-superpowers/SKILL.md" >&2
    VERIFY_FAIL=1
fi

if [[ $VERIFY_FAIL -ne 0 ]]; then
    error "Verification failed — see errors above"
fi

echo ""
echo "=============================================="
echo "  Installation Complete! ($PLATFORM)"
echo "=============================================="
echo ""
echo "Installed:"
echo "  • $SUPERPOWERS_DIR  - Core skill library"
echo "  • $SKILLS_DIR/<skill>/  - $LINKED skill symlinks"
echo "  • $RULES_DIR/  - Augment auto-load rule"
echo ""
echo "Next steps:"
echo "  1. Restart Augment (or start a new conversation)"
echo "  2. Skills appear automatically in <available_skills>"
echo ""
# Note about personal skills
if [[ -d "$HOME/.codex/skills" ]]; then
    personal_count=$(find "$HOME/.codex/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$personal_count" -gt 0 ]]; then
        echo "Note: $personal_count personal skill(s) found in ~/.codex/skills/"
        echo "  These are NOT auto-discovered by Augment. To enable them:"
        echo "  ln -s ~/.codex/skills/<skill-name> ~/.agents/skills/<skill-name>"
        echo ""
    fi
fi
