package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/rootfs"
)

// inspectReport is the JSON shape `inspect` emits, one entry per name.
type inspectReport struct {
	Name           string            `json:"name"`
	Path           string            `json:"path"`
	Installed      bool              `json:"installed"`
	SizeBytes      int64             `json:"size_bytes,omitempty"`
	SizeHuman      string            `json:"size_human,omitempty"`
	InstalledAt    string            `json:"installed_at,omitempty"`
	ManifestEntry  *manifestSummary  `json:"manifest_entry,omitempty"`
	AppliedFixes   map[string]bool   `json:"applied_fixes,omitempty"`
	PerFSMounts    []string          `json:"per_fs_mounts,omitempty"`
	Custom         bool              `json:"custom,omitempty"`
}

// manifestSummary is the manifest-side view embedded into inspectReport
// when we can match the install back to a known suite:variant pair.
type manifestSummary struct {
	Suite          string   `json:"suite"`
	Variant        string   `json:"variant"`
	FriendlyName   string   `json:"friendly_name,omitempty"`
	URL            string   `json:"url,omitempty"`
	SHASum         string   `json:"sha256,omitempty"`
	SupportedArchs []string `json:"supported_archs,omitempty"`
}

// newInspectCmd dumps a JSON object per name to stdout. Output is one JSON
// array so the result is pipeable into jq for filtering / formatting.
func newInspectCmd(a *app) *cobra.Command {
	return &cobra.Command{
		Use:   "inspect <name> [<name>...]",
		Short: "show low-level details about installed rootfs",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				return fmt.Errorf("inspect: at least one <name> required")
			}
			mf, _ := loadManifest(cmd.Context(), a, manifest.ModeOffline, false)
			reports := make([]inspectReport, 0, len(args))
			for _, raw := range args {
				reports = append(reports, buildInspectReport(a, mf, raw))
			}
			out, err := json.MarshalIndent(reports, "", "  ")
			if err != nil {
				return err
			}
			fmt.Fprintln(a.ui.Out(), string(out))
			return nil
		},
	}
}

// buildInspectReport gathers everything for one name. Missing installs
// produce a report with Installed=false so the caller still sees something
// rather than an error — matches docker inspect's behavior on unknown ids.
func buildInspectReport(a *app, mf *manifest.Manifest, raw string) inspectReport {
	name := normalizeInspectName(raw)
	path := filepath.Join(a.paths.InstalledFsDir, name)
	r := inspectReport{Name: name, Path: path, Custom: strings.HasPrefix(name, "custom-")}

	st, err := os.Stat(path)
	if err != nil {
		return r
	}
	r.Installed = true
	r.InstalledAt = st.ModTime().UTC().Format(time.RFC3339)
	if size, err := rootfs.Size(path); err == nil {
		r.SizeBytes = size
		r.SizeHuman = humanBytes(size)
	}
	r.AppliedFixes = detectAppliedFixes(path)
	r.PerFSMounts = readPerFSMountsRaw(path)
	if mf != nil && !r.Custom {
		r.ManifestEntry = matchManifestEntry(a, mf, name)
	}
	return r
}

// normalizeInspectName accepts either an installed name or a suite:variant
// ref. When given a ref we don't go through the manifest (it may be
// missing); we just convert to the "<suite>-<variant>" naming convention
// the installer uses. Caller still has to stat the path.
func normalizeInspectName(raw string) string {
	if !strings.Contains(raw, ":") {
		return raw
	}
	parts := strings.SplitN(raw, ":", 2)
	return parts[0] + "-" + parts[1]
}

// detectAppliedFixes probes for the fake /proc files ApplyFixes drops.
// Their presence is the cheapest signal that the post-install fixups ran.
func detectAppliedFixes(rootFS string) map[string]bool {
	files := []string{"stat", "vmstat", "loadavg", "uptime", "version"}
	out := make(map[string]bool, len(files))
	for _, f := range files {
		_, err := os.Stat(filepath.Join(rootFS, "proc", "."+f))
		out["proc/."+f] = err == nil
	}
	return out
}

// readPerFSMountsRaw returns the literal lines of <rootfs>/udroid_proot_mounts
// (comments and blanks stripped) so users can see the per-install binds
// exactly as written.
func readPerFSMountsRaw(rootFS string) []string {
	b, err := os.ReadFile(filepath.Join(rootFS, "udroid_proot_mounts"))
	if err != nil {
		return nil
	}
	var out []string
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		out = append(out, line)
	}
	return out
}

// matchManifestEntry walks every suite:variant pair looking for a variant
// whose installer-side Name matches. We can't reverse-derive suite:variant
// from the name alone (the upstream "Name" field is opaque), so a linear
// scan is the honest approach. Returns nil when there's no match.
func matchManifestEntry(a *app, mf *manifest.Manifest, name string) *manifestSummary {
	for _, suiteName := range mf.Suites {
		s, err := mf.Suite(suiteName)
		if err != nil {
			continue
		}
		for _, vName := range s.Variants {
			v, err := mf.Variant(suiteName, vName, a.arch)
			if err != nil {
				continue
			}
			if v.Name == name {
				return &manifestSummary{
					Suite:          suiteName,
					Variant:        vName,
					FriendlyName:   v.FriendlyName,
					URL:            v.URL,
					SHASum:         v.SHASum,
					SupportedArchs: v.SupportedArchs,
				}
			}
		}
	}
	return nil
}
