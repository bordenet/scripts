# Prompt for Implementing purge-identity Tool

Use this prompt to resume implementation of the purge-identity tool:

---

I need you to implement a macOS identity purge tool based on comprehensive requirements and design documents that have already been created.

**Context:**
Read these two documents first:
1. `docs/plans/2025-01-13-purge-identity-requirements.md` - Complete requirements specification
2. `docs/plans/2025-01-13-purge-identity-design.md` - Detailed technical design

**Your Task:**
Implement `purge-identity.sh` following the design specifications exactly. This is a shell script (bash) that will discover and permanently delete all traces of specified email identities from macOS.

**Key Requirements:**
- Comprehensive identity discovery (keychain, browsers, Mail.app, Application Support, SSH, etc.)
- Interactive menu with multi-select support
- `--what-if` dry-run mode for safe preview
- Individual preview and confirmation for each selected identity
- ANSI colors with yellow timer in top-right corner
- Smart error handling with actionable exit report
- Logging to `/tmp/purge-identity-YYYYMMDD-HHMMSS.log`
- Never touch `.psafe3`, `.git`, or user data files
- Preserve files in cloud storage directories while deleting account configs

**Implementation Approach:**
1. Follow the modular design in the design document
2. Reference `mu.sh` for code style (compact output, error collection, ANSI formatting)
3. Start with Phase 1 from the implementation roadmap (core infrastructure)
4. Test each module as you build it
5. Use the brainstorming skill if you need to refine any aspects
6. Use verification-before-completion skill before marking work complete

**Critical Safety Rules:**
- Implement file preservation checks (`is_preserved_file()`) FIRST
- Always show warnings for one-way door operations
- Test on a VM or with `--what-if` mode before real deletions
- Handle errors gracefully (continue processing, collect errors, report at end)

**Style Guidelines:**
- Follow the code style in `bu.sh` and `mu.sh`
- Extensive inline comments
- Clear function headers with purpose/parameters/returns
- Use ANSI colors sparingly but effectively
- Compact console output with spinner/progress indicators

**Success Criteria:**
- Script discovers identities across all specified locations
- `--what-if` mode works correctly (shows menu then exits)
- Deletion works with proper confirmations and warnings
- Error handling is comprehensive
- Exit report is clear and actionable
- Code is well-commented and maintainable

**Deliverables:**
1. `purge-identity.sh` - Fully functional script
2. Test the script in `--what-if` mode
3. Document any deviations from the design and why
4. Commit with descriptive message following repo conventions

Start by reading both design documents, then begin implementation starting with Phase 1 (core infrastructure). Ask questions if any requirements are unclear.

---

**Optional Enhancement:**
If the shell script becomes unwieldy (>1000 lines) or performance is poor, propose migration to Go using the Go implementation design from the design document (with lipgloss/bubbles for TUI).
