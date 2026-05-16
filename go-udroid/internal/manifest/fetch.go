package manifest

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// DefaultURL is the upstream distro catalogue maintained by RandomCoderOrg.
const DefaultURL = "https://raw.githubusercontent.com/RandomCoderOrg/udroid-download/main/distro-data.json"

// Fetcher caches the catalogue at CachePath and refreshes it from URL when
// asked. Strict mode treats a network failure as fatal; non-strict mode
// silently falls back to the previously cached copy.
type Fetcher struct {
	URL       string
	CachePath string
	Client    *http.Client
}

// NewFetcher returns a fetcher rooted at the runtime cache dir.
func NewFetcher(runtimeCacheDir string) *Fetcher {
	return &Fetcher{
		URL:       DefaultURL,
		CachePath: filepath.Join(runtimeCacheDir, "distro-data.json.cache"),
		Client:    &http.Client{Timeout: 30 * time.Second},
	}
}

// Mode picks between fetching afresh and trusting the on-disk copy.
type Mode int

const (
	ModeOnline  Mode = iota // refresh from remote; fall back to cache on failure unless strict
	ModeOffline             // never touch the network
)

// Load returns a parsed manifest, refreshing the cache file according to mode.
//
// Special case: if mode is ModeOffline but no cache exists, we still hit
// the network for a one-shot fetch — bash behaviour. Otherwise commands
// like `login` and `remove` would fail on a fresh install before the user
// ever ran `install` or `cache update`.
func (f *Fetcher) Load(ctx context.Context, mode Mode, strict bool) (*Manifest, error) {
	if err := os.MkdirAll(filepath.Dir(f.CachePath), 0o755); err != nil {
		return nil, err
	}
	_, statErr := os.Stat(f.CachePath)
	cached := statErr == nil

	switch {
	case mode == ModeOnline:
		if err := f.refresh(ctx); err != nil {
			if strict || !cached {
				return nil, err
			}
			slog.Warn("manifest fetch failed; using cached copy",
				slog.String("url", f.URL),
				slog.Any("err", err),
			)
		}
	case !cached:
		// offline + no cache — fall through to a single fetch.
		slog.Info("offline mode but no manifest cached; fetching anyway",
			slog.String("cache", f.CachePath),
		)
		if err := f.refresh(ctx); err != nil {
			return nil, fmt.Errorf("no cached manifest and fetch failed: %w", err)
		}
	}
	return Load(f.CachePath)
}

// refresh downloads into a temp file then renames atomically so a failed
// download never replaces a working cache.
func (f *Fetcher) refresh(ctx context.Context) error {
	slog.Debug("manifest refresh begin", slog.String("url", f.URL))
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, f.URL, nil)
	if err != nil {
		return err
	}
	resp, err := f.Client.Do(req)
	if err != nil {
		return fmt.Errorf("fetch manifest: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("fetch manifest: HTTP %s", resp.Status)
	}
	tmp, err := os.CreateTemp(filepath.Dir(f.CachePath), "manifest-*.json.tmp")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	if _, err := io.Copy(tmp, resp.Body); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return err
	}
	if err := os.Rename(tmpName, f.CachePath); err != nil {
		return err
	}
	slog.Debug("manifest refresh ok", slog.String("path", f.CachePath))
	return nil
}
