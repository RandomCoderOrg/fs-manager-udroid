package main

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/olekukonko/tablewriter"
	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
)

// newSearchCmd does a case-insensitive substring match across the manifest:
// suite names, variant names, and the upstream "FriendlyName" field. Output
// is the same shape as `list` so the two commands feel related.
func newSearchCmd(a *app) *cobra.Command {
	return &cobra.Command{
		Use:   "search <term>",
		Short: "search the distro manifest by suite/variant/friendly name",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				return fmt.Errorf("search: <term> required")
			}
			term := strings.ToLower(args[0])
			mf, err := loadManifest(cmd.Context(), a, manifest.ModeOffline, false)
			if err != nil {
				return err
			}
			renderSearchTable(a, mf, term)
			return nil
		},
	}
}

// renderSearchTable walks every suite:variant pair and prints the ones
// whose suite/variant/friendly-name contains term. Reuses the same column
// shape as `list` so users can read either output without re-learning.
func renderSearchTable(a *app, mf *manifest.Manifest, term string) {
	t := tablewriter.NewWriter(a.ui.Out())
	t.SetHeader([]string{"suite:variant", "friendly name", "arch supported", "status"})
	t.SetAutoWrapText(false)

	hits := 0
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
			if !searchMatches(term, suiteName, vName, v.FriendlyName) {
				continue
			}
			installPath := filepath.Join(a.paths.InstalledFsDir, v.Name)
			t.Append([]string{
				suiteName + ":" + vName,
				v.FriendlyName,
				archSupportedLabel(v.SupportedArchs, string(a.arch)),
				installedLabel(pathExists(installPath)),
			})
			hits++
		}
	}
	if hits == 0 {
		a.ui.Warn("no matches")
		return
	}
	t.Render()
}

// searchMatches returns true when any of the candidate strings contains the
// (already lower-cased) term. Substring match — same UX as docker search.
func searchMatches(term string, candidates ...string) bool {
	for _, c := range candidates {
		if strings.Contains(strings.ToLower(c), term) {
			return true
		}
	}
	return false
}
