#!/usr/bin/env bash
################################################################################
# Library: scorch-repo-lib.sh
################################################################################
# PURPOSE: Helper functions for scorch-repo.sh
# USAGE: source "$SCRIPT_DIR/lib/scorch-repo-lib.sh"
################################################################################

# Function: show_help
# Description: Display help information
show_help() {
    cat << EOF
NAME
    ${SCRIPT_NAME} - Remove build cruft by deleting files listed in .gitignore

SYNOPSIS
    ${SCRIPT_NAME} [OPTIONS] [DIRECTORY]

DESCRIPTION
    Scans .gitignore files and systematically deletes all local files matching
    the patterns, with the exception of .env* files which are protected.

    The purpose is to ferret out and delete build cruft so that a repository
    can be effectively minimized on disk, without destroying local secrets.

    By default, operates on a single repository. Use -r/--recursive with --all
    to process multiple repositories in a directory tree.

OPTIONS
    -h, --help
        Display this help message and exit

    --what-if
        Show what would be deleted without actually deleting anything.
        Displays summary count by default, full list with -v/--verbose.

    -f, --force
        DANGEROUS: Skip safety confirmations and delete immediately.
        Still requires initial confirmation with 10-second timeout.

    -v, --verbose
        Enable verbose output. Shows each file being processed.
        In --what-if mode, shows full list of files and total size.

    -i, --interactive
        Interactive mode: prompt before each deletion operation.
        Conservative mode with y|N prompts (10-second timeout, defaults to No).

    -r, --recursive
        Scan for git repositories recursively in subdirectories.
        Must be used with --all flag.

    --all
        Process all repositories found (with -r) or in current directory.
        Without this flag, displays interactive menu for selection.

ARGUMENTS
    DIRECTORY
        Target directory to process. Default: current directory (.)
        With -r/--recursive, searches this directory for git repositories.

EXAMPLES
    # Preview what would be deleted in current repo
    ${SCRIPT_NAME} --what-if

    # Preview with detailed file list
    ${SCRIPT_NAME} --what-if -v

    # Delete with confirmation prompts (safe mode)
    ${SCRIPT_NAME} -i

    # Delete all build cruft in current repo (with safety confirmation)
    ${SCRIPT_NAME}

    # Process specific repository
    ${SCRIPT_NAME} ../RecipeArchive

    # Process all repos in directory tree
    ${SCRIPT_NAME} -r --all ~/GitHub

    # Dangerous: force delete without prompts (still has initial confirmation)
    ${SCRIPT_NAME} -f

SAFETY FEATURES
    • .env* files are NEVER deleted (protects secrets)
    • Default safety confirmation before any deletion
    • Interactive mode (-i) prompts before each operation
    • Force mode (-f) still requires initial confirmation
    • All confirmations use y|N with 10-second timeout defaulting to No

EXIT STATUS
    0   Success
    1   General error
    2   Invalid arguments

ENVIRONMENT
    DEBUG=1
        Enable debug output

SEE ALSO
    git-clean(1), gitignore(5)

AUTHOR
    Matt J Bordenet

EOF
    exit 0
}

# Function: human_readable_size
# Description: Convert bytes to human-readable format
# Parameters:
#   $1 - Size in bytes
human_readable_size() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit_index=0
    local size="$bytes"

    while (( $(echo "$size >= 1024" | bc -l 2>/dev/null || echo 0) )) && (( unit_index < 4 )); do
        size=$(echo "scale=2; $size / 1024" | bc -l)
        ((unit_index++))
    done

    printf "%.2f %s" "$size" "${units[$unit_index]}"
}

# Function: get_file_size
# Description: Get size of file or directory in bytes
# Parameters:
#   $1 - Path to file or directory
get_file_size() {
    local path="$1"
    
    if [[ -f "$path" ]]; then
        # File size
        stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null || echo 0
    elif [[ -d "$path" ]]; then
        # Directory size (sum of all files)
        find "$path" -type f -exec stat -f%z {} \; 2>/dev/null | awk '{sum+=$1} END {print sum+0}' || \
        find "$path" -type f -exec stat -c%s {} \; 2>/dev/null | awk '{sum+=$1} END {print sum+0}' || \
        echo 0
    else
        echo 0
    fi
}

# Function: is_env_file
# Description: Check if path is a .env file (protected)
# Parameters:
#   $1 - Path to check
# Returns: 0 if .env file, 1 otherwise
is_env_file() {
    local path="$1"
    local basename
    basename="$(basename "$path")"
    
    # Protect any file starting with .env
    if [[ "$basename" == .env* ]]; then
        return 0
    fi
    
    return 1
}

# Function: find_git_repos
# Description: Find git repositories in directory
# Parameters:
#   $1 - Directory to search
#   $2 - Recursive flag (true/false)
# Output: Prints repository paths, one per line
find_git_repos() {
    local search_dir="$1"
    local recursive="$2"
    
    if [[ "$recursive" == true ]]; then
        # Recursive search
        find "$search_dir" -type d -name ".git" 2>/dev/null | while IFS= read -r git_dir; do
            dirname "$git_dir"
        done
    else
        # Non-recursive: check current level and one level deep
        for dir in "$search_dir"/*/; do
            if [[ -d "$dir/.git" ]]; then
                echo "$dir"
            else
                # Check second level
                for subdir in "$dir"*/; do
                    if [[ -d "$subdir/.git" ]]; then
                        echo "$subdir"
                    fi
                done
            fi
        done
    fi
}

# Function: get_ignored_files
# Description: Get list of files that match .gitignore patterns
# Parameters:
#   $1 - Repository directory
# Output: Prints ignored file paths, one per line
get_ignored_files() {
    local repo_dir="$1"

    # Change to repo directory
    pushd "$repo_dir" > /dev/null || return 1

    # Check if .gitignore exists
    if [[ ! -f .gitignore ]]; then
        log_info "No .gitignore found in $repo_dir"
        popd > /dev/null || return 0
        return 0
    fi

    # Use git check-ignore in batch mode for efficiency
    # Find all files and directories, then check them all at once
    {
        find . -type f 2>/dev/null | grep -v '^\./\.git/'
        find . -type d 2>/dev/null | grep -v '^\./\.git' | grep -v '^\.$'
    } | git check-ignore --stdin 2>/dev/null | while IFS= read -r item; do
        # Skip .env files
        if ! is_env_file "$item"; then
            # For directories, check if they contain .env files
            if [[ -d "$item" ]]; then
                if find "$item" -type f -name ".env*" -print -quit 2>/dev/null | grep -q .; then
                    log_warning "Skipping directory $item (contains .env file)"
                    continue
                fi
            fi
            echo "$item"
        else
            log_info "Protecting .env file: $item"
        fi
    done

    popd > /dev/null || return 0
}

# Function: delete_item
# Description: Delete a file or directory
# Parameters:
#   $1 - Path to delete
#   $2 - Repository directory (for relative path display)
# Returns: 0 on success, 1 on failure
delete_item() {
    local item="$1"
    local repo_dir="$2"
    local size

    # Get size before deletion
    size=$(get_file_size "$item")

    if [[ -d "$item" ]]; then
        if rm -rf "$item" 2>/dev/null; then
            log_info "Deleted directory: $item"
            ((TOTAL_DIRS_DELETED++))
            TOTAL_SIZE_FREED=$((TOTAL_SIZE_FREED + size))
            return 0
        else
            log_error "Failed to delete directory: $item"
            return 1
        fi
    elif [[ -f "$item" ]]; then
        if rm -f "$item" 2>/dev/null; then
            log_info "Deleted file: $item"
            ((TOTAL_FILES_DELETED++))
            TOTAL_SIZE_FREED=$((TOTAL_SIZE_FREED + size))
            return 0
        else
            log_error "Failed to delete file: $item"
            return 1
        fi
    fi

    return 1
}

# Function: process_repository
# Description: Process a single repository
# Parameters:
#   $1 - Repository directory
process_repository() {
    local repo_dir="$1"
    local repo_name
    repo_name="$(basename "$repo_dir")"

    log_info "Processing repository: $repo_name"

    # Check if it's a git repository
    if [[ ! -d "$repo_dir/.git" ]]; then
        log_warning "Not a git repository: $repo_dir"
        ((REPOS_SKIPPED++))
        return 1
    fi

    # Get ignored files into array
    local ignored_files=()
    while IFS= read -r file; do
        ignored_files+=("$file")
    done < <(get_ignored_files "$repo_dir")

    if [[ ${#ignored_files[@]} -eq 0 ]]; then
        log_info "No ignored files found in $repo_name"
        ((REPOS_PROCESSED++))
        return 0
    fi

    # Calculate total size
    local total_size=0
    local file_count=0
    local dir_count=0

    for item in "${ignored_files[@]}"; do
        local full_path="$repo_dir/$item"
        local item_size
        item_size=$(get_file_size "$full_path")
        total_size=$((total_size + item_size))

        if [[ -d "$full_path" ]]; then
            ((dir_count++))
        elif [[ -f "$full_path" ]]; then
            ((file_count++))
        fi
    done

    # Display summary
    echo
    echo -e "${BOLD}Repository: $repo_name${NC}"
    echo "  Files to delete: $file_count"
    echo "  Directories to delete: $dir_count"
    echo "  Total size: $(human_readable_size "$total_size")"

    # What-if mode
    if [[ "$WHAT_IF" == true ]]; then
        if [[ "$VERBOSE" == true ]]; then
            echo
            echo "Files and directories that would be deleted:"
            for item in "${ignored_files[@]}"; do
                local full_path="$repo_dir/$item"
                local item_size
                item_size=$(get_file_size "$full_path")
                echo "  - $item ($(human_readable_size "$item_size"))"
            done
        fi
        ((REPOS_PROCESSED++))
        return 0
    fi

    # Interactive mode - ask for confirmation
    if [[ "$INTERACTIVE" == true ]]; then
        echo
        if ! ask_yes_no_timed "Delete these files from $repo_name?" 10; then
            log_info "Skipped $repo_name"
            ((REPOS_SKIPPED++))
            return 0
        fi
    fi

    # Delete files
    pushd "$repo_dir" > /dev/null || return 1

    for item in "${ignored_files[@]}"; do
        if [[ "$INTERACTIVE" == true ]] && [[ "$VERBOSE" == true ]]; then
            # Ask for each item in verbose interactive mode
            if ! ask_yes_no_timed "Delete $item?" 10; then
                log_info "Skipped: $item"
                continue
            fi
        fi

        delete_item "$item" "$repo_dir"
    done

    popd > /dev/null || return 0

    ((REPOS_PROCESSED++))
    log_success "Completed processing $repo_name"
}

