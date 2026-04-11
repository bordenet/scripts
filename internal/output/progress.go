package output

import (
	"fmt"
	"io"
	"time"
)

// ProgressWriter manages the live progress line and per-repo output.
// It is the ONLY writer to stdout — all other code sends results to the main loop.
type ProgressWriter struct {
	out   io.Writer
	total int
}

// NewProgressWriter creates a ProgressWriter targeting w for total repos.
func NewProgressWriter(out io.Writer, total int) *ProgressWriter {
	return &ProgressWriter{out: out, total: total}
}

// PrintResult erases the progress line, prints a result line.
func (p *ProgressWriter) PrintResult(line string) {
	fmt.Fprintf(p.out, "\r\033[2K%s\n", line)
}

// UpdateProgress reprints the progress line in-place.
func (p *ProgressWriter) UpdateProgress(completed, total int, elapsed time.Duration) {
	mins := int(elapsed.Minutes())
	secs := int(elapsed.Seconds()) % 60
	fmt.Fprintf(p.out, "\rSyncing %d repos...  [%d/%d]  %02d:%02d",
		total, completed, total, mins, secs)
}
