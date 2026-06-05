package output

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	gosync "gitsync/internal/sync"
)

// maxRepoLen is the display-column width reserved for the repo name in the
// compact progress line. 48 cols fits comfortably in an 80-col terminal alongside
// the spinner (2), counter (~12), and timer (~6).
const maxRepoLen = 48

// defaultBarWidth is used until a tea.WindowSizeMsg arrives with the real width.
const defaultBarWidth = 80

// SlowSyncThreshold is the minimum in-flight duration before a repo sync is
// labelled slow in the TUI. Exported so the per-goroutine timer in main uses
// the same value without duplication.
const SlowSyncThreshold = 5 * time.Second

// repoStyle pads/truncates the repo name to exactly maxRepoLen display columns.
// Lipgloss delegates to go-runewidth so CJK double-width characters are handled
// correctly — no manual byte/rune accounting needed.
var repoStyle = lipgloss.NewStyle().Width(maxRepoLen).MaxWidth(maxRepoLen)

// slowStyle renders the "slow sync" indicator line in amber so it stands out
// without being alarming.
var slowStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("3"))

// MsgResult carries a completed repo result to the Bubble Tea event loop.
type MsgResult struct {
	Result    gosync.RepoResult
	Formatted string // pre-rendered line from Formatter; empty when not noteworthy
}

// MsgDone signals that all repos have been processed and the program should quit.
type MsgDone struct{}

// MsgPrint injects a plain line above the viewport (e.g. a stash warning from the
// SIGINT handler) without touching the progress counter.
type MsgPrint struct{ Line string }

// MsgSlowRepo is sent by a repo goroutine after SlowSyncThreshold has elapsed
// without a result. The TUI adds an amber indicator line so the user can see
// which repo is holding up the run. SyncStart is the time the goroutine
// acquired the semaphore and began syncing, used to display elapsed time.
type MsgSlowRepo struct {
	Name      string
	SyncStart time.Time
}

// ProgressModel is a Bubble Tea model that renders the live compact progress display.
// Compact mode: animated spinner on line 1, optional slow-sync line, gradient
// progress bar on the last line. Verbose mode: View() is empty; caller prints
// lines directly. When done is true, View() returns "" so Bubble Tea erases the
// display before exit.
type ProgressModel struct {
	spinner     spinner.Model
	bar         progress.Model
	currentRepo string
	completed   int
	total       int
	start       time.Time
	verbose     bool
	done        bool
	// slowRepos tracks repos that have been in-flight longer than SlowSyncThreshold.
	// Key is the display name; value is the time the goroutine acquired the semaphore.
	slowRepos map[string]time.Time
	// doneRepos guards against a race where MsgResult arrives before MsgSlowRepo:
	// if the repo is already done, the slow indicator is suppressed.
	doneRepos map[string]bool
}

// NewProgressModel builds the initial model. Pass it to tea.NewProgram.
func NewProgressModel(total int, verbose bool) ProgressModel {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("4")) // blue

	bar := progress.New(progress.WithDefaultGradient())
	bar.Width = defaultBarWidth
	// Hide the built-in "100%" text — we show [X/N] ourselves on line 1.
	bar.ShowPercentage = false

	return ProgressModel{
		spinner:   s,
		bar:       bar,
		total:     total,
		start:     time.Now(),
		verbose:   verbose,
		slowRepos: make(map[string]time.Time),
		doneRepos: make(map[string]bool),
	}
}

// percent returns the completion ratio clamped to [0, 1].
// Guards against total == 0 (no repos discovered) to avoid NaN.
func (m ProgressModel) percent() float64 {
	if m.total <= 0 {
		return 0
	}
	p := float64(m.completed) / float64(m.total)
	if p > 1 {
		return 1
	}
	return p
}

// Init starts the spinner ticker. The progress bar has no autonomous tick.
func (m ProgressModel) Init() tea.Cmd {
	if m.verbose {
		return nil
	}
	return m.spinner.Tick
}

// Update handles incoming messages and advances the model.
func (m ProgressModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		// Keep the bar at most as wide as the terminal, with a small margin.
		w := msg.Width - 2
		if w < 20 {
			w = 20
		}
		m.bar.Width = w
		return m, nil

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	case MsgResult:
		m.currentRepo = msg.Result.DisplayName
		m.completed++
		// Clear slow-sync indicator: this repo is done.
		delete(m.slowRepos, msg.Result.DisplayName)
		m.doneRepos[msg.Result.DisplayName] = true
		if msg.Formatted != "" {
			// tea.Println inserts the line above the progress display without
			// disturbing the spinner — no manual \r\033[2K needed.
			return m, tea.Println(msg.Formatted)
		}
		return m, nil

	case MsgSlowRepo:
		// Guard first: MsgResult and MsgSlowRepo are sent from different goroutines
		// and can arrive out of order. Suppress the notice if the repo is already done.
		if m.doneRepos[msg.Name] {
			return m, nil
		}
		if m.verbose {
			// In verbose mode there is no TUI bar — print a one-time notice instead.
			// Use %v so Duration.String() handles any threshold value precisely (no truncation).
			return m, tea.Println(fmt.Sprintf("  ~ slow sync: %s (>%v)", msg.Name, SlowSyncThreshold))
		}
		m.slowRepos[msg.Name] = msg.SyncStart
		return m, nil

	case MsgPrint:
		if msg.Line != "" {
			return m, tea.Println(msg.Line)
		}
		return m, nil

	case MsgDone:
		m.done = true
		return m, tea.Quit
	}
	// This is a headless batch runner — keyboard input is disabled via
	// tea.WithInput(nil) in main.go. No key handlers are needed.
	return m, nil
}

// View renders the compact progress display. Normally two lines:
//
//	⣾ myrepo                                  [34/89]  0:42
//	████████████████████░░░░░░░░░░░░░░░░░░░░░░
//
// When one or more repos have been in-flight longer than SlowSyncThreshold, a
// third line is inserted between the spinner line and the progress bar:
//
//	⣾ myrepo                                  [34/89]  0:42
//	  ~ slow: Personal/gitsync (15s)
//	████████████████████░░░░░░░░░░░░░░░░░░░░░░
//
// Bubble Tea calls this after every model update; it owns the cursor.
func (m ProgressModel) View() string {
	if m.verbose || m.done {
		return ""
	}
	elapsed := time.Since(m.start)
	mins := int(elapsed.Minutes())
	secs := int(elapsed.Seconds()) % 60
	repo := m.currentRepo
	if repo == "" {
		repo = "…"
	}
	line1 := fmt.Sprintf("%s %s  [%d/%d]  %d:%02d",
		m.spinner.View(),
		repoStyle.Render(repo),
		m.completed, m.total,
		mins, secs)

	slowLine := ""
	if len(m.slowRepos) > 0 {
		type slowEntry struct {
			name    string
			elapsed time.Duration
		}
		now := time.Now()
		entries := make([]slowEntry, 0, len(m.slowRepos))
		for name, syncStart := range m.slowRepos {
			entries = append(entries, slowEntry{name, now.Sub(syncStart)})
		}
		// Longest-running first so the most concerning repo appears at the left.
		sort.Slice(entries, func(i, j int) bool {
			return entries[i].elapsed > entries[j].elapsed
		})
		parts := make([]string, len(entries))
		for i, e := range entries {
			parts[i] = fmt.Sprintf("%s (%ds)", e.name, int(e.elapsed.Seconds()))
		}
		slowLine = slowStyle.Render("  ~ slow: "+strings.Join(parts, ", ")) + "\n"
	}

	return line1 + "\n" + slowLine + m.bar.ViewAs(m.percent()) + "\n"
}
