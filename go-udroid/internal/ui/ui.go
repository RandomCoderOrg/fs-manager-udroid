// Package ui hides whether output goes to a plain terminal, a TUI, or a
// log file. The CLI and core packages take a UI value and call methods
// on it; swap implementations to change presentation without touching
// the callers.
package ui

import "io"

// UI is the surface every interactive path goes through.
type UI interface {
	// Status messages — equivalent to bash INFO/WARN/EDIE.
	Info(msg string)
	Warn(msg string)
	Error(msg string)
	Title(msg string)

	// Confirm asks a yes/no question. Default is the value returned if
	// the user hits enter with no input.
	Confirm(prompt string, def bool) (bool, error)

	// Choose returns the chosen option from opts. An empty selection
	// (user aborted) is an error.
	Choose(prompt string, opts []string) (string, error)

	// Progress builds a progress reporter for a known-total transfer.
	// Title is shown beside the bar.
	Progress(title string) ProgressBar

	// Spinner runs fn while showing a spinner with title. The returned
	// error is whatever fn returned.
	Spinner(title string, fn func() error) error

	// Out / Err are the raw streams for tools that need to write directly
	// (e.g. proot's stdio after exec, table output).
	Out() io.Writer
	Err() io.Writer
}

// ProgressBar matches rootfs.ProgressReporter so the same value can be
// passed straight to rootfs.Download.
type ProgressBar interface {
	Start(total int64)
	Add(n int64)
	Finish()
}
