# lib/display-layout-help.sh — usage text for display-layout.sh
# Sourced by display-layout.sh; not executable directly.
# shellcheck shell=bash

usage() {
  cat <<EOF
$SCRIPT_NAME — deterministic macOS display-layout capture and recovery

SYNOPSIS
  $SCRIPT_NAME [--dir DIRECTORY] [-v|--verbose] <command> [arguments]
  $SCRIPT_NAME --help

PURPOSE
  macOS can forget or reinterpret multi-monitor arrangements after sleep/wake,
  hot-plug events, clamshell transitions, dock/KVM behavior, monitor power
  events, or inconsistent display identity/EDID visibility. This script uses
  displayplacer to save the *current known-good* monitor configuration as a
  named profile and restore it later with one command.

  It manages LOCAL display geometry for one Mac: monitor position/origin,
  primary display, resolution, scaling, refresh rate, rotation, and mirroring
  where displayplacer includes them. It does NOT configure Universal Control's
  separate Mac-to-Mac/iPad pointer-sharing topology, nor does it manage window
  placement inside applications.

QUICK START
  1. Connect a desk configuration using its normal, stable cabling. In
     System Settings > Displays, arrange screens exactly as desired.

  2. Capture that known-good state:
       $SCRIPT_NAME save desk-a-lid-open

  3. When monitor geometry goes haywire, restore it:
       $SCRIPT_NAME restore desk-a-lid-open

  4. Create separate profiles for every materially different hardware state:
       $SCRIPT_NAME save desk-a-clamshell
       $SCRIPT_NAME save desk-b-lid-open
       $SCRIPT_NAME save travel-internal-only

COMMANDS
  save <name>              Save the current displayplacer-generated layout.
                           Overwrite requires confirmation.
  restore <name>           Validate connected display IDs, then apply a saved
                           layout. Requires confirmation unless
                           DISPLAY_LAYOUT_NO_CONFIRM=1 is set.
  validate <name>          Compare display IDs saved in a profile against the
                           IDs visible to displayplacer right now.
  current                  Print the complete current displayplacer inventory,
                           including its suggested restore command.
  show <name>              Print a saved layout file and its exact command.
  list                     List saved layout profiles.
  delete <name>            Delete a saved layout and metadata; asks first.
  path                     Print the directory holding saved profiles.
  doctor                   Check macOS, displayplacer, paths, saved layouts,
                           and print operational troubleshooting guidance.
  help                     Print this help text.

OPTIONS
  --dir DIRECTORY          Use DIRECTORY instead of the default profile store.
  -v, --verbose            Enable verbose output (dependency search, IDs).
  -h, --help               Print this help text.

ENVIRONMENT
  DISPLAY_LAYOUT_DIR        Profile storage directory.
                             Default: $LAYOUT_DIR_DEFAULT
  DISPLAYPLACER_BIN         Explicit executable path for displayplacer. Use
                             this when it is intentionally not on PATH.
  DISPLAY_LAYOUT_NO_CONFIRM Set to 1 to suppress the normal confirmation before
                             restoring a profile that validates successfully.
                             A mismatched-ID restore always asks first.

INSTALLATION
  displayplacer is installed automatically via Homebrew if not found. To
  install it manually:

       brew install displayplacer

  Make this script executable after placing it in a stable location:

       chmod +x display-layout.sh

  Optional: put it somewhere on PATH or symlink it to ~/bin:

       mkdir -p ~/bin
       ln -sf /absolute/path/to/display-layout.sh ~/bin/display-layout

  The script finds displayplacer via PATH first, then falls back to the normal
  Homebrew paths:

       Apple Silicon: /opt/homebrew/bin/displayplacer
       Intel Macs:    /usr/local/bin/displayplacer

PROFILE LIFECYCLE
  A saved profile contains displayplacer's command emitted while your screens
  are correctly arranged. It is configuration-as-code: inspect it, version it,
  and restore it rather than trying to drag display tiles back into place.

       $SCRIPT_NAME current
       $SCRIPT_NAME save desk-a-lid-open
       $SCRIPT_NAME show desk-a-lid-open
       $SCRIPT_NAME validate desk-a-lid-open
       $SCRIPT_NAME restore desk-a-lid-open

  Profiles are saved by default in:

       $LAYOUT_DIR_DEFAULT

  Files are named <name>.displayplacer, accompanied by <name>.meta metadata.
  Names may contain letters, digits, period, underscore, and hyphen.

  To keep profiles inside a dotfiles or scripts repository:

       $SCRIPT_NAME --dir ~/src/scripts/display-layouts save desk-a-lid-open

  Or set the location for a shell session:

       export DISPLAY_LAYOUT_DIR=~/src/scripts/display-layouts
       $SCRIPT_NAME list

DISPLAYPLACER DETAILS
  displayplacer is a macOS display-layout command-line tool. Its \`list\` output
  includes connected displays and a generated command for the current
  arrangement. The command normally captures display identifiers plus geometry
  and mode information such as resolution, scaling, origin, rotation, refresh
  rate, color depth, and mirroring where applicable.

  This script saves the generated command rather than inventing monitor IDs,
  coordinates, or resolutions. A display with origin (0,0) is ordinarily the
  primary display. Use System Settings > Displays to establish a correct
  baseline, then run \`save\`.

  Use complete generated commands. Do not reduce a saved command to only an ID
  or only a resolution: a fully described layout is more likely to restore the
  intended arrangement.

SAFETY AND VALIDATION
  Before a restore, the script extracts display IDs from the saved command and
  compares them to IDs currently reported by displayplacer:

       $SCRIPT_NAME validate desk-a-lid-open

  A successful validation means the saved IDs appear to be connected. It does
  not guarantee macOS, a dock, or a KVM will apply the arrangement perfectly.
  If IDs are missing, the script warns and requires an explicit second approval
  before attempting a restore. Inspect the current inventory before forcing it:

       $SCRIPT_NAME current
       $SCRIPT_NAME show desk-a-lid-open

  For unattended automation, set DISPLAY_LAYOUT_NO_CONFIRM=1 only after many
  successful manual tests. Do not use unattended recovery for a profile that
  sometimes overlaps with a travel, clamshell, or alternate-dock setup.

HARDWARE AND TOPOLOGY GUIDANCE
  The best automation cannot fully compensate for changing display identity.
  Make physical display detection boring and repeatable:

  - Keep each monitor connected to the same physical Mac and dock port.
  - Prefer direct Thunderbolt/USB-C or DisplayPort paths while diagnosing.
  - Test without a KVM, low-quality hub, HDMI adapter, or MST chain if
    rearrangements persist; they can change or hide EDID/display identity.
  - Keep display power/wake behavior consistent. A monitor that appears late
    after wake can be interpreted as a different configuration.
  - If two 4K monitors are identical, use stable wiring and, if practical,
    different ports/interfaces to reduce ambiguity.
  - Save distinct profiles for lid-open, clamshell, dock A, dock B, and
    internal-only/travel states. Do not force a three-screen profile when only
    two screens are present.
  - Avoid moving cables among ports after saving profiles. Re-save profiles if
    the physical topology intentionally changes.

UNIVERSAL CONTROL GUIDANCE
  Universal Control is not a local monitor arrangement tool. It is a separate
  spatial relationship among Macs and iPads. A correct local displayplacer
  restore will not set the edge relationship between Macs or iPad.

  During diagnosis in a desk with several Macs and an iPad in proximity:

  1. On each Mac, open System Settings > Displays > Advanced.
  2. Keep pointer/keyboard sharing enabled only when desired.
  3. Turn OFF automatic reconnection to nearby Macs/iPads temporarily.
  4. Explicitly connect only the two or three devices you intend to use.
  5. Arrange those devices in Displays settings so the crossing edge matches
     the physical desk arrangement.

  This reduces opportunistic re-linking when another Mac or iPad wakes nearby.
  Re-enable automatic reconnect only if it proves stable and worth the
  convenience in your specific workspace.

BETTERDISPLAY, SWITCHRESX, AND STAY
  This script is intended as the deterministic recovery layer whether or not
  you use a GUI utility:

  - BetterDisplay Pro can provide layout protection/anchor points and display
    configuration controls. Trial it first: macOS sleep/wake and dock/EDID
    behavior can still defeat passive protection in some setups. Treat this
    script's saved displayplacer profile as the reproducible fallback.
  - SwitchResX is another candidate for saved display sets. Verify current
    behavior and macOS compatibility before purchasing, and avoid allowing
    multiple GUI utilities to enforce conflicting layout policies at once.
  - Stay by Cordless Dog restores APPLICATION WINDOW placement per display
    configuration. It may be the tool you remember if Xcode, Cursor, VS Code,
    iTerm2, browsers, and other windows scatter after monitor changes. Stay
    does not replace displayplacer for physical monitor coordinates or
    Universal Control adjacency.

RESETTING CORRUPTED DISPLAY PREFERENCES
  Resetting WindowServer preferences is a last resort, not normal maintenance.
  First eliminate cable/dock/KVM identity problems and validate a saved
  displayplacer layout. If macOS never retains a configuration even with fixed
  direct connections, back up relevant user-level WindowServer preferences
  before moving any file, then restart and rebuild the layout.

  Inspect candidate files first:

       find ~/Library/Preferences/ByHost -maxdepth 1 \\
         \\( -iname '*windowserver*.plist' -o -iname '*WindowServer*.plist' \\) \\
         -print

  Create a backup directory:

       mkdir -p ~/Desktop/display-pref-backup

  Move only a specific file you inspected; do not blindly delete files or use
  sudo:

       mv ~/Library/Preferences/ByHost/<exact-file>.plist \\
         ~/Desktop/display-pref-backup/

  Restart, reconnect the stable intended monitor topology, arrange displays in
  System Settings > Displays, sleep/wake-test it, then re-save profiles.

AUTOMATION EXAMPLES
  Raycast Script Command, Keyboard Maestro, Hammerspoon, BetterTouchTool, or a
  shell hotkey can invoke a known profile:

       /absolute/path/to/display-layout.sh restore desk-a-lid-open

  For a tested noninteractive action:

       #!/usr/bin/env bash
       export DISPLAY_LAYOUT_NO_CONFIRM=1
       /absolute/path/to/display-layout.sh restore desk-a-lid-open

  A launchd job can invoke a profile after wake/unlock, but add it only after
  testing all expected states. A naive wake trigger can fight clamshell mode,
  travel mode, another dock, or displays that are still negotiating after wake.
  Prefer a manual hotkey first. If you automate, delay execution and guard it
  with \`validate\` or a physical-context check.

TROUBLESHOOTING
  "displayplacer is required"
      Run: brew install displayplacer
      Confirm: command -v displayplacer

  "Saved display IDs are missing"
      Run: $SCRIPT_NAME current
      Compare with: $SCRIPT_NAME show <name>
      Confirm wiring, dock/KVM state, monitor power, and active input. If the
      changed topology is intentional, arrange screens correctly and re-save.

  "Restore succeeds but macOS rearranges screens later"
      Check monitor wake timing and display identity/EDID through the dock/KVM.
      Test direct cabling. Use the profile as an immediate recovery action;
      consider BetterDisplay Pro only after confirming it helps with your setup.

  "Pointer will not cross into another Mac or iPad"
      This is usually Universal Control topology, not displayplacer. Explicitly
      connect the intended devices and turn off Universal Control auto-reconnect
      while isolating the issue.

  "Windows are in the wrong places but monitors are correct"
      Use a window-layout utility such as Stay; this script controls monitors,
      not individual application windows.

EOF
}
