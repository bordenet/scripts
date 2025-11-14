# Identity Purge Tool - Requirements Document

**Document Version:** 1.0
**Date:** 2025-01-13
**Status:** Design Phase
**Implementation:** Shell script (bash) or Go application (TBD based on complexity)

---

## Executive Summary

A comprehensive macOS utility to discover and permanently remove all traces of defunct email identities from the system. The tool addresses the problem of "ghost accounts" - identities from former employers or deleted services that persist in local system configurations, causing authentication failures, unwanted prompts, and general UX friction.

**Primary Goal:** Eliminate all authentication credentials, cached data, and configuration references for specified email identities while preserving actual user data files.

---

## Problem Statement

### The Core Problem

When user accounts are deleted on remote services (former employer Office 365, defunct SaaS products, etc.), the local macOS system retains extensive traces:

- Keychain entries with passwords and certificates
- Browser profiles, cookies, saved passwords, and autofill data
- Email account configurations and cached mailboxes
- Application-specific credentials (Slack workspaces, Teams, etc.)
- SSH keys and configuration entries
- Cloud storage account configurations
- System-level Internet Accounts

### User Impact

These ghost accounts cause:

1. **Authentication friction** - Prompts to sign into accounts that no longer exist
2. **Autofill pollution** - Old email addresses appearing in form fills
3. **Visual clutter** - Dead accounts appearing in account pickers and preferences
4. **Workflow interruption** - Having to skip/dismiss dead account prompts repeatedly
5. **Security concerns** - Stale credentials remaining accessible

### Example Identities

Real-world examples from the user:
- `matt.bordenet@telepathy.ai` (defunct employer)
- `matt.bordenet@stash.com` (deleted account)
- `mattbordenet@stellaautomotive.com` (former employer)

---

## User Requirements

### FR1: Comprehensive Identity Discovery

**Requirement:** The tool MUST automatically discover all email identities present on the system.

**Rationale:** Users may not remember all defunct identities. Automatic discovery reveals forgotten ghost accounts.

**Acceptance Criteria:**
- Scan keychain for email patterns
- Scan browser databases (Safari, Chrome, Edge, Firefox)
- Scan application preferences and data stores
- Scan Mail.app configurations
- Scan SSH keys and configuration
- Scan cloud storage configurations
- Present deduplicated list of all discovered identities

### FR2: Manual Identity Specification

**Requirement:** The tool MUST allow users to manually specify identities not auto-discovered.

**Rationale:** Some ghost accounts may exist in locations not covered by automated scanning, or in formats that don't match email patterns.

**Acceptance Criteria:**
- Menu option to add custom identity string
- Accept email addresses in standard formats
- Add manually-specified identities to the selection list

### FR3: Interactive Selection Interface

**Requirement:** The tool MUST present discovered identities in a numbered menu with multi-select capability.

**Rationale:** User may want to purge multiple identities in a single run but maintain control over which ones.

**Acceptance Criteria:**
- Numbered list of identities with occurrence counts
- Support single selection (e.g., `3`)
- Support multi-select (e.g., `1,3,5`)
- Support range selection (e.g., `1-4`)
- Support "all" option for batch operations

### FR4: What-If Mode (Dry Run)

**Requirement:** The tool MUST support a `--what-if` mode that performs discovery and displays the menu without executing any deletions.

**Rationale:** Critical safety mechanism allowing users to preview what would be found before committing to destructive operations.

**Acceptance Criteria:**
- `--what-if` flag performs full discovery
- Displays complete menu with all found identities
- Exits immediately after menu display
- No deletions or system modifications occur
- Same discovery logic as full execution mode

### FR5: Detailed Preview Before Deletion

**Requirement:** For each selected identity, the tool MUST display a detailed preview of what will be deleted before proceeding.

**Rationale:** Two-stage safety mechanism - selection is intent, preview is verification.

**Acceptance Criteria:**
- Show grouped categories (Keychain, Browsers, Mail, etc.)
- Show item counts per category
- Highlight operations with data loss (mail deletion, profile deletion)
- Present clear, readable format
- Wait for explicit confirmation before proceeding

### FR6: Individual Confirmations

**Requirement:** When multiple identities are selected, the tool MUST preview and confirm each one individually before deletion.

**Rationale:** Prevents batch operations from deleting more than intended. User maintains granular control.

**Acceptance Criteria:**
- Sequential processing of selected identities
- Full preview for each identity
- Individual confirmation prompt for each
- Ability to skip individual identities while continuing to others
- Clear progress indication (e.g., "Processing 2 of 3")

### FR7: Comprehensive Deletion Scope

**Requirement:** The tool MUST delete ALL authentication and configuration traces of an identity across all discoverable locations.

**Philosophy:** "Scorched earth" - if it contains the identity string, it's a deletion candidate.

**Locations to purge:**

#### Keychain (all item types)
- Internet passwords
- Application passwords
- Generic passwords
- Certificates (S/MIME, code signing, etc.)
- Private keys
- Secure notes
- Any item where account, label, comment, or notes contain the identity

#### Browsers (profile-level deletion)
- **Safari:** Cookies, history, cache, saved passwords, autofill data
- **Chrome:** Entire profiles associated with identity (sync account match or profile name match)
- **Edge:** Entire profiles associated with identity
- **Firefox:** Entire profiles associated with identity

#### Mail.app
- Account configuration (from Accounts.plist)
- Mailbox directories with all downloaded email

#### Application Support (comprehensive scan)
- **Microsoft Office:**
  - Group Containers (UBF8T346G9.Office)
  - Container directories (com.microsoft.*)
  - Offer surgical vs. full reset based on preview
- **Communication apps:** Slack, Discord, Teams, Zoom workspace/team data
- **Development tools:** VS Code, JetBrains IDE account data
- **All apps:** Scan plists, JSON configs, SQLite databases for identity strings

#### Cloud Storage
- **OneDrive:** Remove account configuration from preferences (preserve file directories)
- **Google Drive, Dropbox:** Remove account configurations where found

#### SSH
- Private/public key pairs where public key comment matches identity
- `~/.ssh/config` entries for domains associated with identity (e.g., telepathy.ai hosts)

#### Internet Accounts (System Preferences/Settings)
- Remove system-level account integrations where identity matches
- Attempt automated removal, flag for manual if automated fails

#### System Certificates
- **Flag only** - do not auto-delete
- Report in exit summary for manual review

**Acceptance Criteria:**
- All listed locations scanned
- All matching items deleted (except flagged categories)
- Deletions logged comprehensively
- Errors reported with actionable follow-up

### FR8: Data Preservation Boundaries

**Requirement:** The tool MUST preserve actual user data files while deleting authentication/configuration data.

**Rationale:** The goal is to remove ghost credentials, not destroy valuable files.

**Explicit preservation rules:**

**NEVER touch:**
- `.psafe3` files (Password Safe databases)
- `.git` directories and git repository history
- Files in cloud storage directories (e.g., `~/Library/CloudStorage/OneDrive-*/`)
- Documents, spreadsheets, or other user-created content
- Application data that isn't authentication-related

**Delete configurations, not data:**
- OneDrive account config: DELETE
- OneDrive files: PRESERVE
- Mail account config: DELETE
- Downloaded email: DELETE (this is cached data, not original files)
- Browser sync config: DELETE
- Browser bookmarks: DELETE (part of profile associated with identity)

**Acceptance Criteria:**
- Hardcoded exclusions for `.psafe3`, `.git`, cloud storage file directories
- Clear distinction between config/credential files and user data
- File type and location analysis before deletion
- Conservative approach: when in doubt, flag for manual review

### FR9: Smart Error Handling

**Requirement:** The tool MUST handle errors gracefully and continue processing other items.

**Strategy:** Auto-handle obvious issues, skip items that fail, report all errors with actionable guidance.

**Error scenarios:**

**Auto-handled (with user prompt):**
- Browsers running (database locked) → Prompt to quit browser
- Keychain locked → Prompt to unlock
- Insufficient permissions for specific operations → Request sudo elevation

**Skipped and reported:**
- Permission denied errors that can't be auto-resolved
- File/database locked despite closing apps
- Unexpected file formats or corruption

**Acceptance Criteria:**
- No hard failures that terminate the entire script
- All errors logged with context
- Exit report lists all errors with specific manual remediation steps
- User can choose to abort or continue when errors occur

### FR10: Comprehensive Logging

**Requirement:** The tool MUST log all operations, discoveries, deletions, and errors to a timestamped log file.

**Location:** `/tmp/purge-identity-YYYYMMDD-HHMMSS.log`

**Content:**
- Timestamp for each operation
- Discovery results (what was found, where)
- Deletion operations (what was deleted)
- All errors with full context
- Timing information
- User responses to prompts

**Log lifecycle:**
- Auto-cleanup logs older than 24 hours on script startup
- Report log location in exit summary

**Acceptance Criteria:**
- Every operation logged
- Log survives script crashes
- Timestamped entries for debugging
- Old logs automatically cleaned up
- Log path displayed to user at exit

### FR11: Modern Console UX

**Requirement:** The tool MUST provide a polished, informative console interface with real-time feedback.

**Visual elements:**

**ANSI color coding:**
- Yellow: Running timer (top-right corner)
- Green: Success indicators (✓)
- Red: Errors (✗)
- Cyan: Section headers
- White: Normal output

**Timer:**
- Display format: `[Elapsed: HH:MM:SS]`
- Position: Top-right corner
- Update frequency: Every 5 seconds
- Total time in exit report

**Progress indicators:**
- Compact single-line updates during scanning
- Category-based progress (e.g., `[3/8] Chrome... scanning...`)
- Replace line on update (no scrolling spam)

**Acceptance Criteria:**
- ANSI colors used appropriately (not excessive)
- Timer visible and updating throughout execution
- Progress clear without being verbose
- Total execution time reported at exit

**Note for Go implementation:** If complexity requires Go instead of bash, use `lipgloss` and related libraries for modern TUI experience.

### FR12: Privilege Elevation

**Requirement:** The tool MUST request elevated privileges only when necessary and with clear messaging.

**Strategy:** Smart elevation - don't request sudo upfront, elevate only for operations that require it.

**Operations requiring sudo:**
- Some keychain operations (system keychain access)
- Deleting files owned by other users or system
- Modifying system-level preferences

**Acceptance Criteria:**
- No sudo request in `--what-if` mode (unless needed for complete discovery)
- Clear message before elevation: "Requesting elevated privileges to access Keychain..."
- Minimal sudo usage (only when required)
- Graceful handling if sudo denied

### FR13: Browser Process Management

**Requirement:** The tool MUST detect running browsers and prompt for closure before attempting deletion.

**Rationale:** Browser databases are locked while the application is running. Auto-quitting without permission could cause data loss.

**Behavior:**
- Detect if Safari, Chrome, Edge, Firefox are running
- Prompt user: "Safari is running and will block deletion. Quit Safari now? [y/N]"
- Wait for user action (manual quit or script-assisted quit)
- Verify closure before proceeding
- If user declines, skip browser operations and report in errors

**Acceptance Criteria:**
- Process detection for all supported browsers
- User controls when apps quit
- Verification that apps actually closed
- Graceful handling if apps won't close

### FR14: One-Way Door Warnings

**Requirement:** The tool MUST explicitly warn users before irreversible or system-critical operations.

**Operations requiring explicit warnings:**

**System stability risks:**
- Deleting system certificates → "WARNING: System certificate found. Removing may affect VPN/corporate network. Continue? [y/N]"
- Removing Internet Accounts → "WARNING: Removing system account may affect other apps. Continue? [y/N]"

**Data loss risks:**
- Large mailbox deletion → "WARNING: Deleting 2.3GB of email. This is permanent. Continue? [y/N]"
- Browser profile deletion → "WARNING: Deleting entire Chrome profile 'Work'. All bookmarks/extensions/settings will be lost. Continue? [y/N]"
- Office full reset → "WARNING: Full Office reset will remove ALL accounts and require re-activation. Continue? [y/N]"

**Irreversible operations:**
- SSH key deletion → "WARNING: SSH key deletion is permanent. Ensure key not needed elsewhere. Continue? [y/N]"

**Acceptance Criteria:**
- Warnings clearly indicate risk type
- User must explicitly confirm ([y/N] prompt)
- Default is safe (N)
- Operation skipped if user declines

### FR15: Exit Report

**Requirement:** The tool MUST provide a comprehensive summary of all operations upon completion.

**Report contents:**

**Summary section:**
- Total execution time
- Per-identity deletion counts
- Overall success/failure status

**Error section:**
- List of all errors encountered
- Specific remediation steps for each error
- Commands to manually complete failed operations

**Log reference:**
- Full path to detailed log file

**Format example:**
```
=== Purge Complete ===
Total time: 00:03:42

matt.bordenet@telepathy.ai: 47 items deleted
matt.bordenet@stash.com: 23 items deleted

ERRORS (2):
  1. Chrome profile locked - Close Chrome and run:
     rm -rf ~/Library/Application Support/Google/Chrome/Profile\ 2
  2. System certificate flagged - Review manually:
     Certificate: Telepathy Inc. Root CA

Log: /tmp/purge-identity-20251113-143022.log
```

**Acceptance Criteria:**
- Always displayed, even on partial failures
- Clear, actionable error messages
- Copy-pasteable commands for manual remediation
- Log path clearly visible

---

## Non-Functional Requirements

### NFR1: Platform

**Requirement:** macOS-only. No cross-platform support required.

**Rationale:** Tool is specifically designed for macOS system structures (Keychain, Library, etc.).

### NFR2: Performance

**Requirement:** Complete discovery and deletion within reasonable time (< 5 minutes for typical system).

**Rationale:** Comprehensive scanning of Application Support could be slow. Need to balance thoroughness with usability.

### NFR3: Safety

**Requirement:** Fail-safe design. Errors should never leave system in broken state.

**Rationale:** This is a destructive tool. Safety is paramount.

**Implementation:**
- What-if mode as default workflow
- Multiple confirmation stages
- Explicit warnings for risky operations
- Comprehensive error handling
- Preserve data files at all costs

### NFR4: Maintainability

**Requirement:** Well-commented code, clear structure, modular design.

**Rationale:** Tool may need updates as macOS changes or new applications emerge.

**Implementation:**
- Modular functions for each deletion category
- Clear separation of discovery, preview, deletion logic
- Extensive inline comments
- Configuration variables for paths and patterns

---

## Out of Scope

The following are explicitly NOT requirements:

1. **Cross-platform support** - Not targeting Linux or Windows
2. **Git history rewriting** - Not modifying git commit history to remove identity from past commits
3. **Remote account deletion** - Not interacting with remote services to delete accounts
4. **Backup/restore** - Not creating backups before deletion (user responsible for backups)
5. **Selective file preservation** - Not asking about individual files; category-level decisions only
6. **Encrypted volume support** - Not handling FileVault or encrypted external volumes specially
7. **Network shares** - Not scanning SMB/NFS mounted shares
8. **Time Machine exclusions** - Not managing Time Machine to prevent deleted data from being restored

---

## Success Criteria

The tool is successful if:

1. **Discovery completeness** - Finds >95% of identity traces across common applications
2. **Zero system breakage** - No reports of broken macOS systems post-execution
3. **User confidence** - What-if mode provides sufficient detail for informed decisions
4. **Error handling** - Graceful degradation; errors don't prevent completion
5. **User satisfaction** - Ghost account prompts/friction eliminated for purged identities

---

## Risk Assessment

### High Risks

**R1: Data Loss**
- **Risk:** Accidentally deleting important files
- **Mitigation:** Strict preservation rules, what-if mode, multiple confirmations, comprehensive logging

**R2: System Instability**
- **Risk:** Deleting system certificates or critical configs
- **Mitigation:** Flag-only for system certs, explicit warnings, conservative approach

**R3: Incomplete Deletion**
- **Risk:** Missing identity traces in unexpected locations
- **Mitigation:** Comprehensive scanning, user can re-run tool, manual identity entry

### Medium Risks

**R4: Performance Issues**
- **Risk:** Slow scanning on systems with large Application Support directories
- **Mitigation:** Progress indicators, option to skip slow scans, Go rewrite if needed

**R5: Browser Compatibility**
- **Risk:** Browser database formats change between versions
- **Mitigation:** Graceful error handling, flag for manual review if parsing fails

### Low Risks

**R6: False Positives**
- **Risk:** Flagging unrelated items that happen to contain identity string
- **Mitigation:** Preview before deletion, user confirmation required

---

## Implementation Decision Points

### Decision 1: Shell Script vs. Go Application

**Current decision:** Start with bash shell script.

**Criteria to pivot to Go:**
- Script exceeds 1000 lines
- Performance issues with comprehensive scanning
- Complex SQLite database parsing required
- Need for better error handling/recovery
- Desire for compiled binary distribution

**Go implementation requirements:**
- Use `lipgloss` and `bubbles` for TUI
- Use `viper` for configuration management
- Maintain same UX/workflow as shell script

### Decision 2: Configuration File Support

**Current decision:** No configuration file initially.

**Future consideration:** If users want to maintain a persistent list of identities to auto-purge, add `~/.purge-identities.conf` support.

---

## Appendix: User Stories

### US1: Former Employee Account Cleanup

**As a** user who left a company
**I want to** remove all traces of my former work email
**So that** I stop getting prompts to sign into accounts that no longer exist

**Acceptance:** All keychain, browser, and application traces of work email are removed

### US2: Deleted Service Account Removal

**As a** user whose account was deleted on a third-party service
**I want to** remove local credentials and cached data
**So that** autofill stops suggesting a defunct email address

**Acceptance:** Browser autofill, saved passwords, and cookies for deleted account are removed

### US3: Privacy-Conscious Periodic Cleanup

**As a** privacy-conscious user
**I want to** periodically review and remove old identities
**So that** my system only contains credentials I actively use

**Acceptance:** Discovery mode reveals forgotten accounts for evaluation

### US4: Safe Exploration Before Deletion

**As a** cautious user
**I want to** see what would be deleted before committing
**So that** I can verify nothing important will be lost

**Acceptance:** What-if mode shows complete discovery results without making changes

---

**End of Requirements Document**
