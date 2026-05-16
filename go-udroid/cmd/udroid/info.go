package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/rootfs"
)

// Version is the udroid binary version. Set at build time via
//   go build -ldflags "-X main.Version=v0.1.0"
// Leaving it as "dev" when unset surfaces the dev build clearly.
var Version = "dev"

// infoReport is the structured form of `info`. Same shape JSON and text
// reads from, so adding a field updates both views.
type infoReport struct {
	Version    string         `json:"version"`
	Runtime    runtimeInfo    `json:"runtime"`
	Arch       string         `json:"arch"`
	Package    string         `json:"android_package"`
	Paths      pathsInfo      `json:"paths"`
	Manifest   manifestInfo   `json:"manifest"`
	Log        logInfo        `json:"log"`
	Installs   countSize      `json:"installs"`
	Cache      countSize      `json:"cache"`
}

type runtimeInfo struct {
	GoVersion string `json:"go_version"`
	OS        string `json:"os"`
	GoArch    string `json:"go_arch"`
}

type pathsInfo struct {
	Prefix         string `json:"prefix"`
	Home           string `json:"home"`
	InstalledFsDir string `json:"installed_fs_dir"`
	DownloadCache  string `json:"download_cache"`
	RuntimeCache   string `json:"runtime_cache"`
}

type manifestInfo struct {
	URL       string `json:"url"`
	CachePath string `json:"cache_path"`
	Cached    bool   `json:"cached"`
}

type logInfo struct {
	Level  string `json:"level"`
	File   string `json:"file"`
	Format string `json:"format"`
}

type countSize struct {
	Count     int    `json:"count"`
	SizeBytes int64  `json:"size_bytes"`
	SizeHuman string `json:"size_human"`
}

// newInfoCmd dumps the runtime state. Default output is human-readable; `--json`
// emits the same data as JSON for scripting.
func newInfoCmd(a *app) *cobra.Command {
	var asJSON bool
	cmd := &cobra.Command{
		Use:   "info",
		Short: "show runtime configuration and disk usage",
		RunE: func(cmd *cobra.Command, args []string) error {
			r := gatherInfo(a)
			if asJSON {
				b, err := json.MarshalIndent(r, "", "  ")
				if err != nil {
					return err
				}
				fmt.Fprintln(a.ui.Out(), string(b))
				return nil
			}
			printInfo(a, r)
			return nil
		},
	}
	cmd.Flags().BoolVar(&asJSON, "json", false, "emit info as JSON")
	return cmd
}

// gatherInfo populates an infoReport from the app singletons + disk probes.
func gatherInfo(a *app) infoReport {
	mfCache := filepath.Join(a.paths.RuntimeCache, "distro-data.json.cache")
	_, mfErr := os.Stat(mfCache)
	manifestURL := manifest.DefaultURL
	if a.cfg != nil && a.cfg.ManifestURL != "" {
		manifestURL = a.cfg.ManifestURL
	}
	return infoReport{
		Version: Version,
		Runtime: runtimeInfo{
			GoVersion: runtime.Version(),
			OS:        runtime.GOOS,
			GoArch:    runtime.GOARCH,
		},
		Arch:    string(a.arch),
		Package: a.paths.Package,
		Paths: pathsInfo{
			Prefix:         a.paths.Prefix,
			Home:           a.paths.Home,
			InstalledFsDir: a.paths.InstalledFsDir,
			DownloadCache:  a.paths.DownloadCache,
			RuntimeCache:   a.paths.RuntimeCache,
		},
		Manifest: manifestInfo{
			URL:       manifestURL,
			CachePath: mfCache,
			Cached:    mfErr == nil,
		},
		Log:      gatherLogInfo(a),
		Installs: dirCountSize(a.paths.InstalledFsDir, func(name string) bool { return true }),
		Cache:    dirCountSize(a.paths.DownloadCache, func(name string) bool { return strings.Contains(name, ".tar") }),
	}
}

// gatherLogInfo reads the effective log knobs from the config. CLI overrides
// aren't visible here because PersistentPreRunE collapses them into the
// logger directly without storing — we report the config-resolved values.
func gatherLogInfo(a *app) logInfo {
	li := logInfo{Level: "info", Format: "text"}
	if a.cfg != nil {
		if a.cfg.Log.Level != "" {
			li.Level = a.cfg.Log.Level
		}
		if a.cfg.Log.File != "" {
			li.File = a.cfg.Log.File
		}
		if a.cfg.Log.Format != "" {
			li.Format = a.cfg.Log.Format
		}
	}
	if li.File == "" {
		dir := os.Getenv("TMPDIR")
		if dir == "" {
			dir = "/tmp"
		}
		li.File = filepath.Join(dir, "udroid.log")
	}
	return li
}

// dirCountSize counts entries in dir matching keep() and adds up their sizes.
// Empty/missing dirs return a zero report rather than an error so info stays
// useful on first-run installs.
func dirCountSize(dir string, keep func(name string) bool) countSize {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return countSize{}
	}
	var (
		count int
		total int64
	)
	for _, e := range entries {
		if !keep(e.Name()) {
			continue
		}
		count++
		full := filepath.Join(dir, e.Name())
		if size, err := rootfs.Size(full); err == nil {
			total += size
		}
	}
	return countSize{Count: count, SizeBytes: total, SizeHuman: humanBytes(total)}
}

// printInfo writes the human-friendly view. Two columns of "key: value"
// grouped by section; no fancy box-drawing so it stays grep-friendly.
func printInfo(a *app, r infoReport) {
	out := a.ui.Out()
	fmt.Fprintf(out, "udroid %s (%s, %s/%s)\n",
		r.Version, r.Runtime.GoVersion, r.Runtime.OS, r.Runtime.GoArch)
	fmt.Fprintln(out)
	fmt.Fprintln(out, "Host")
	fmt.Fprintf(out, "  arch:             %s\n", r.Arch)
	fmt.Fprintf(out, "  android package:  %s\n", r.Package)
	fmt.Fprintln(out)
	fmt.Fprintln(out, "Paths")
	fmt.Fprintf(out, "  prefix:           %s\n", r.Paths.Prefix)
	fmt.Fprintf(out, "  home:             %s\n", r.Paths.Home)
	fmt.Fprintf(out, "  installed fs:     %s\n", r.Paths.InstalledFsDir)
	fmt.Fprintf(out, "  download cache:   %s\n", r.Paths.DownloadCache)
	fmt.Fprintf(out, "  runtime cache:    %s\n", r.Paths.RuntimeCache)
	fmt.Fprintln(out)
	fmt.Fprintln(out, "Manifest")
	fmt.Fprintf(out, "  url:              %s\n", r.Manifest.URL)
	fmt.Fprintf(out, "  cache:            %s (cached=%t)\n", r.Manifest.CachePath, r.Manifest.Cached)
	fmt.Fprintln(out)
	fmt.Fprintln(out, "Logging")
	fmt.Fprintf(out, "  level:            %s\n", r.Log.Level)
	fmt.Fprintf(out, "  file:             %s\n", r.Log.File)
	fmt.Fprintf(out, "  format:           %s\n", r.Log.Format)
	fmt.Fprintln(out)
	fmt.Fprintln(out, "Storage")
	fmt.Fprintf(out, "  installs:         %d (%s)\n", r.Installs.Count, r.Installs.SizeHuman)
	fmt.Fprintf(out, "  cached tarballs:  %d (%s)\n", r.Cache.Count, r.Cache.SizeHuman)
}
