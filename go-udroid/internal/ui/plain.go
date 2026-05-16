package ui

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/schollz/progressbar/v3"
)

// Plain is the default UI: ANSI colour for headers, line-based prompts,
// stdlib spinner via goroutine, schollz/progressbar for downloads.
type Plain struct {
	in  io.Reader
	out io.Writer
	err io.Writer
}

// NewPlain wires the default plain UI against os.Stdin/Stdout/Stderr.
func NewPlain() *Plain {
	return &Plain{in: os.Stdin, out: os.Stdout, err: os.Stderr}
}

const (
	cReset  = "\x1b[0m"
	cGrey   = "\x1b[90m"
	cGreen  = "\x1b[32m"
	cRed    = "\x1b[31m"
	cYellow = "\x1b[33m"
	cBold   = "\x1b[1m"
	cBg     = "\x1b[100m"
)

func (p *Plain) Info(msg string)  { fmt.Fprintln(p.out, cGreen+msg+cReset) }
func (p *Plain) Warn(msg string)  { fmt.Fprintln(p.err, cYellow+"[WARN] "+msg+cReset) }
func (p *Plain) Error(msg string) { fmt.Fprintln(p.err, cRed+cBold+msg+cReset) }
func (p *Plain) Title(msg string) { fmt.Fprintln(p.out, cBg+msg+cReset) }

func (p *Plain) Out() io.Writer { return p.out }
func (p *Plain) Err() io.Writer { return p.err }

func (p *Plain) Confirm(prompt string, def bool) (bool, error) {
	suffix := "[Y/n]"
	if !def {
		suffix = "[y/N]"
	}
	fmt.Fprintf(p.out, "%s %s ", prompt, suffix)
	r := bufio.NewReader(p.in)
	line, err := r.ReadString('\n')
	if err != nil {
		return def, err
	}
	switch strings.ToLower(strings.TrimSpace(line)) {
	case "":
		return def, nil
	case "y", "yes":
		return true, nil
	case "n", "no":
		return false, nil
	}
	return false, fmt.Errorf("invalid response %q", strings.TrimSpace(line))
}

func (p *Plain) Choose(prompt string, opts []string) (string, error) {
	if len(opts) == 0 {
		return "", fmt.Errorf("no options to choose from")
	}
	fmt.Fprintln(p.out, prompt)
	for i, o := range opts {
		fmt.Fprintf(p.out, "  %d) %s\n", i+1, o)
	}
	fmt.Fprint(p.out, "select [1]: ")
	line, err := bufio.NewReader(p.in).ReadString('\n')
	if err != nil {
		return "", err
	}
	line = strings.TrimSpace(line)
	if line == "" {
		return opts[0], nil
	}
	idx, err := strconv.Atoi(line)
	if err != nil || idx < 1 || idx > len(opts) {
		return "", fmt.Errorf("invalid selection %q", line)
	}
	return opts[idx-1], nil
}

func (p *Plain) Progress(title string) ProgressBar {
	return &plainBar{title: title, out: p.out}
}

type plainBar struct {
	title string
	out   io.Writer
	bar   *progressbar.ProgressBar
}

func (b *plainBar) Start(total int64) {
	b.bar = progressbar.NewOptions64(total,
		progressbar.OptionSetDescription(b.title),
		progressbar.OptionShowBytes(true),
		progressbar.OptionSetWriter(b.out),
		progressbar.OptionThrottle(100*time.Millisecond),
		progressbar.OptionShowCount(),
	)
}
func (b *plainBar) Add(n int64) {
	if b.bar != nil {
		_ = b.bar.Add64(n)
	}
}
func (b *plainBar) Finish() {
	if b.bar != nil {
		_ = b.bar.Finish()
		fmt.Fprintln(b.out)
	}
}

// Spinner runs fn in the foreground and animates a single-line spinner
// from a goroutine until fn returns. Keeps the implementation in-package
// so we don't pull in another dep.
func (p *Plain) Spinner(title string, fn func() error) error {
	frames := []rune{'⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'}
	done := make(chan struct{})
	var stopped atomic.Bool
	go func() {
		i := 0
		for !stopped.Load() {
			fmt.Fprintf(p.out, "\r%c %s ", frames[i%len(frames)], title)
			i++
			time.Sleep(80 * time.Millisecond)
		}
		fmt.Fprintf(p.out, "\r✔ %s\n", title)
		close(done)
	}()
	err := fn()
	stopped.Store(true)
	<-done
	return err
}
