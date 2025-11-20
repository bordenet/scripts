#!/usr/bin/env bash
################################################################################
# Script Name: lib/help.sh
################################################################################
# PURPOSE: Help documentation for purge-identity tool
# USAGE: Source this file from main script or lib/common.sh
# PLATFORM: macOS
################################################################################

show_help() {
    cat << 'EOF'
NAME
    purge-identity.sh - Comprehensive macOS identity purge tool

SYNOPSIS
    purge-identity.sh EMAIL [OPTIONS]

DESCRIPTION
    Permanently removes all traces of a SPECIFIED email identity from macOS.
    You must explicitly provide the email address to purge - there is no
    auto-discovery menu to prevent accidental deletions.

    Targets authentication credentials, cached data, and configuration
    references while preserving actual user data files.

    The tool provides comprehensive discovery across:
      • Keychain (passwords, certificates, keys)
      • Browsers (Safari, Chrome, Edge, Firefox)
      • Mail.app (accounts and mailboxes)
      • Application Support (app-specific credentials)
      • SSH (keys and configuration)
      • Internet Accounts (system-level accounts)
      • Cloud storage (OneDrive, Google Drive configs)

    SAFETY FEATURES:
      • What-if mode for safe preview before execution
      • Multiple confirmation stages before deletion
      • Explicit warnings for one-way door operations
      • Comprehensive logging of all operations
      • Preserves .psafe3, .git, and user data files

ARGUMENTS
    EMAIL
        The email address to purge. This is REQUIRED - the script will not
        run without an explicitly specified email address.

OPTIONS
    --what-if
        Dry-run mode. Discover where the email exists and show what would
        be deleted without actually deleting anything.

    --verbose
        Enable verbose debug logging to console. All operations are always
        logged to /tmp/purge-identity-YYYYMMDD-HHMMSS.log regardless.

    -h, --help
        Display this help message and exit.

WORKFLOW
    1. Email Validation
       - Validates the provided email format
       - Ensures explicit user intent

    2. Discovery Phase
       - Scans system for the specified email only
       - Reports all locations where found

    3. Preview & Confirmation
       - Detailed preview of what will be deleted
       - Explicit confirmation required
       - Warnings for risky operations (data loss, system impact)

    4. Deletion & Exit Report
       - Performs deletions only after confirmation
       - Summary of all operations performed
       - Comprehensive error listing with remediation steps
       - Log file location for detailed review

EXAMPLES
    # Safe preview: see where an email exists without deleting
    ./purge-identity.sh user@oldcompany.com --what-if

    # Delete all traces of a specific email
    ./purge-identity.sh user@oldcompany.com

    # Verbose mode for debugging
    ./purge-identity.sh user@oldcompany.com --verbose

WARNINGS
    This tool performs PERMANENT DELETIONS. Deleted data cannot be recovered.

    Specifically:
      • Mail.app mailboxes are DELETED (not archived)
      • Browser profiles are DELETED (bookmarks, history, all settings)
      • SSH keys are DELETED (ensure keys not needed elsewhere)
      • Keychain entries are DELETED (passwords unrecoverable)

    ALWAYS run --what-if mode first to verify operations before committing.

    The tool preserves:
      • .psafe3 files (Password Safe databases)
      • .git directories (repository history)
      • User data files in cloud storage directories
      • Application data files (only configs/credentials deleted)

PLATFORM
    macOS only - Script will exit with error on other platforms

DEPENDENCIES
    • macOS security framework (built-in)
    • jq (JSON parsing) - install via: brew install jq
    • sqlite3 (built-in on macOS)

EXIT CODES
    0    Success
    1    Error occurred (check log file for details)
    2    User cancelled operation

LOGGING
    All operations are logged to:
      /tmp/purge-identity-YYYYMMDD-HHMMSS.log

    Logs are automatically cleaned up after 24 hours.

EXAMPLES OF IDENTITIES
    • Former employer accounts (user@oldcompany.com)
    • Deleted service accounts (user@deletedservice.com)
    • Deprecated personal emails (old.email@provider.com)

AUTHOR
    Matt J Bordenet

SEE ALSO
    security(1), sqlite3(1), jq(1)

EOF
    exit 0
}

