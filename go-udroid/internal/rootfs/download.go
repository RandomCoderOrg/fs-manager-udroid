package rootfs

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// ProgressReporter receives byte-count callbacks during a download. The
// rootfs package stays UI-agnostic; the CLI wires its progress bar through
// this interface.
type ProgressReporter interface {
	Start(total int64)
	Add(n int64)
	Finish()
}

// nopProgress is the default when the caller doesn't supply one.
type nopProgress struct{}

func (nopProgress) Start(int64) {}
func (nopProgress) Add(int64)   {}
func (nopProgress) Finish()     {}

// Download fetches url into dest. When dest already exists it is reused
// unchanged (the bash version's "already exists, continuing with existing
// file" behaviour) — call os.Remove() first if you need a fresh copy.
//
// retryForever toggles the --always-retry mode: on network errors the
// function will keep retrying until ctx is cancelled.
func Download(ctx context.Context, url, dest string, retryForever bool, pr ProgressReporter) error {
	if pr == nil {
		pr = nopProgress{}
	}
	if _, err := os.Stat(dest); err == nil {
		slog.Debug("download skipped; file already present",
			slog.String("dest", dest),
		)
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		return err
	}

	for attempt := 1; ; attempt++ {
		slog.Debug("download attempt",
			slog.Int("attempt", attempt),
			slog.String("url", url),
			slog.String("dest", dest),
		)
		err := downloadOnce(ctx, url, dest, pr)
		if err == nil {
			slog.Info("download complete", slog.String("dest", dest))
			return nil
		}
		if !retryForever {
			return fmt.Errorf("download attempt %d: %w", attempt, err)
		}
		slog.Warn("download failed; retrying",
			slog.Int("attempt", attempt),
			slog.Any("err", err),
		)
		if ctx.Err() != nil {
			return ctx.Err()
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(2 * time.Second):
		}
	}
}

func downloadOnce(ctx context.Context, url, dest string, pr ProgressReporter) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %s", resp.Status)
	}

	tmp := dest + ".part"
	f, err := os.Create(tmp)
	if err != nil {
		return err
	}
	defer f.Close()

	pr.Start(resp.ContentLength)
	defer pr.Finish()
	if _, err := io.Copy(io.MultiWriter(f, progressWriter{pr}), resp.Body); err != nil {
		os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	return os.Rename(tmp, dest)
}

type progressWriter struct{ pr ProgressReporter }

func (p progressWriter) Write(b []byte) (int, error) {
	p.pr.Add(int64(len(b)))
	return len(b), nil
}

// ErrNotFound is reported when a path that should exist doesn't.
var ErrNotFound = errors.New("not found")
