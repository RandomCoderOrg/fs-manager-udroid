// Package logging builds a slog.Logger from user-controllable knobs
// (level, output file, format) and installs it as the slog default so
// every package can emit structured events without an extra parameter.
//
// Two output targets are supported in one logger:
//   - the log file (always written, defaults to $TMPDIR/udroid.log)
//   - the terminal (stderr; only enabled when verbose is set or when the
//     level is debug, so normal runs stay quiet)
package logging

import (
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

// Format selects the on-disk encoding.
type Format string

const (
	FormatText Format = "text"
	FormatJSON Format = "json"
)

// Options describes everything the factory needs.
type Options struct {
	Level   string // debug/info/warn/error (case-insensitive); empty defaults to "info"
	File    string // log file path; empty defaults to $TMPDIR/udroid.log
	Format  Format // text or json; empty defaults to text
	Verbose bool   // also mirror to stderr at the same level
}

// Setup builds the logger, installs it as the slog default, and returns a
// close function the caller should defer to flush the file.
func Setup(opts Options) (*slog.Logger, func() error, error) {
	level, err := parseLevel(opts.Level)
	if err != nil {
		return nil, nil, err
	}
	path := opts.File
	if path == "" {
		path = defaultLogPath()
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, nil, fmt.Errorf("prepare log dir: %w", err)
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, nil, fmt.Errorf("open log file: %w", err)
	}

	var out io.Writer = f
	if opts.Verbose || level <= slog.LevelDebug {
		out = io.MultiWriter(f, os.Stderr)
	}

	handlerOpts := &slog.HandlerOptions{Level: level}
	var handler slog.Handler
	switch opts.Format {
	case FormatJSON:
		handler = slog.NewJSONHandler(out, handlerOpts)
	default:
		handler = slog.NewTextHandler(out, handlerOpts)
	}
	logger := slog.New(handler)
	slog.SetDefault(logger)
	logger.Debug("logger initialised",
		slog.String("file", path),
		slog.String("level", level.String()),
		slog.Bool("verbose", opts.Verbose),
	)

	closer := closerOnce(f.Close)
	return logger, closer, nil
}

func parseLevel(s string) (slog.Level, error) {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "", "info":
		return slog.LevelInfo, nil
	case "debug":
		return slog.LevelDebug, nil
	case "warn", "warning":
		return slog.LevelWarn, nil
	case "error":
		return slog.LevelError, nil
	}
	return 0, fmt.Errorf("unknown log level %q (want debug|info|warn|error)", s)
}

func defaultLogPath() string {
	dir := os.Getenv("TMPDIR")
	if dir == "" {
		dir = "/tmp"
	}
	return filepath.Join(dir, "udroid.log")
}

// closerOnce returns a func that runs f at most once, returning the same
// error on subsequent calls. Lets callers defer the close without worrying
// about double-frees.
func closerOnce(f func() error) func() error {
	var (
		once sync.Once
		err  error
		done bool
	)
	return func() error {
		once.Do(func() {
			err = f()
			done = true
		})
		if !done {
			return errors.New("logger already closed")
		}
		return err
	}
}
