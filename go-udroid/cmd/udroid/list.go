package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/olekukonko/tablewriter"
	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/rootfs"
)

// listFlags is the small bag of toggles the `list` command exposes.
type listFlags struct {
	showSize      bool
	showCustomFs  bool
	installedOnly bool
}

func newListCmd(a *app) *cobra.Command {
	f := &listFlags{}
	cmd := &cobra.Command{
		Use:     "list",
		Aliases: []string{"ls"},
		Short:   "list distros and their install status",
		RunE: func(cmd *cobra.Command, args []string) error {
			mf, err := loadManifest(cmd.Context(), a, manifest.ModeOffline, false)
			if err != nil {
				return err
			}
			return runList(a, mf, f)
		},
	}
	cmd.Flags().BoolVar(&f.showSize, "size", false, "include installed size")
	cmd.Flags().BoolVar(&f.showCustomFs, "custom", false, "also list custom-installed rootfs")
	cmd.Flags().BoolVar(&f.installedOnly, "installed", false, "only show installed rootfs")
	return cmd
}

// runList prints the variants table and (optionally) the custom-fs list.
// The body reads as the two-section structure the user sees.
func runList(a *app, mf *manifest.Manifest, f *listFlags) error {
	renderVariantTable(a, mf, f)
	if f.showCustomFs {
		renderCustomFsList(a, f)
	}
	return nil
}

// renderVariantTable builds the suite:variant / arch / status [/ size]
// table. Iterates each suite-variant pair, drops the row when --installed
// is on and the row isn't installed.
func renderVariantTable(a *app, mf *manifest.Manifest, f *listFlags) {
	t := tablewriter.NewWriter(a.ui.Out())
	t.SetHeader(tableHeader(f.showSize))
	t.SetAutoWrapText(false)

	for _, suiteName := range mf.Suites {
		s, err := mf.Suite(suiteName)
		if err != nil {
			continue
		}
		for _, vName := range s.Variants {
			row, ok := variantRow(a, suiteName, vName, mf, f)
			if !ok {
				continue
			}
			t.Append(row)
		}
	}
	t.Render()
}

// tableHeader returns the column names; "size" is appended only when the
// user asked for it.
func tableHeader(includeSize bool) []string {
	h := []string{"suite:variant", "arch supported", "status"}
	if includeSize {
		h = append(h, "size")
	}
	return h
}

// variantRow assembles one table row. Returns (_, false) when the user
// passed --installed and this variant isn't installed, so the caller
// knows to skip the append.
func variantRow(a *app, suiteName, vName string, mf *manifest.Manifest, f *listFlags) ([]string, bool) {
	v, err := mf.Variant(suiteName, vName, a.arch)
	if err != nil {
		return nil, false
	}
	installPath := filepath.Join(a.paths.InstalledFsDir, v.Name)
	installed := pathExists(installPath)
	if f.installedOnly && !installed {
		return nil, false
	}

	row := []string{
		suiteName + ":" + vName,
		archSupportedLabel(v.SupportedArchs, string(a.arch)),
		installedLabel(installed),
	}
	if f.showSize {
		row = append(row, sizeOrBlank(installPath))
	}
	return row, true
}

// archSupportedLabel turns the list of arches a variant supports into a
// simple YES/NO based on the running arch.
func archSupportedLabel(supported []string, arch string) string {
	for _, s := range supported {
		if s == arch {
			return "YES"
		}
	}
	return "NO"
}

// installedLabel returns the visible "[installed]" marker when present.
func installedLabel(installed bool) string {
	if installed {
		return "[installed]"
	}
	return ""
}

// renderCustomFsList walks the install dir for "custom-*" entries and
// prints them as a separate section. These aren't in the manifest so they
// don't fit the main table.
func renderCustomFsList(a *app, f *listFlags) {
	fmt.Fprintln(a.ui.Out(), "\ncustom rootfs:")
	entries, _ := os.ReadDir(a.paths.InstalledFsDir)
	for _, e := range entries {
		if !e.IsDir() || !strings.HasPrefix(e.Name(), "custom-") {
			continue
		}
		line := "  " + strings.TrimPrefix(e.Name(), "custom-")
		if f.showSize {
			line += "\t" + sizeOrBlank(filepath.Join(a.paths.InstalledFsDir, e.Name()))
		}
		fmt.Fprintln(a.ui.Out(), line)
	}
}

func pathExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

func sizeOrBlank(path string) string {
	if !pathExists(path) {
		return ""
	}
	n, err := rootfs.Size(path)
	if err != nil {
		return ""
	}
	return humanBytes(n)
}

// humanBytes formats a byte count with binary-IEC suffixes (KiB/MiB/...).
func humanBytes(n int64) string {
	const u = 1024
	if n < u {
		return fmt.Sprintf("%dB", n)
	}
	div, exp := int64(u), 0
	for x := n / u; x >= u; x /= u {
		div *= u
		exp++
	}
	return fmt.Sprintf("%.1f%ciB", float64(n)/float64(div), "KMGTPE"[exp])
}
