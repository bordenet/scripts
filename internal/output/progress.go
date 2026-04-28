package output

import (
	"fmt"
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

// repoStyle pads/truncates the repo name to exactly maxRepoLen display columns.
// Lipgloss delegates to go-runewidth so CJK double-width characters are handled
// correctly — no manual byte/rune accounting needed.
var repoStyle = lipgloss.NewStyle().Width(maxRepoLen).MaxWidth(maxRepoLen)

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

// ProgressModel is a Bubble Tea model that renders the live compact progress display.
// Compact mode: animated spinner on line 1, gradient progress bar on line 2.
// Verbose mode: View() is empty; caller prints lines directly.
// When done is true, View() returns "" so Bubble Tea erases the display before exit.
type ProgressModel struct {
	spinner     spinner.Model
	bar         progress.Model
	currentRepo string
	completed   int
	total       int
	start       time.Time
	verbose     bool
	done        bool
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
		spinner: s,
		bar:     bar,
		total:   total,
		start:   time.Now(),
		verbose: verbose,
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
		if msg.Formatted != "" {
			// tea.Println inserts the line above the progress display without
			// disturbing the spinner — no manual \r\033[2K needed.
			return m, tea.Println(msg.Formatted)
		}
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

// View renders the two-line compact progress display:
//
//	⣾ myrepo                                  [34/89]  0:42
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
	return line1 + "\n" + m.bar.ViewAs(m.percent()) + "\n"
}
