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

func newListCmd(a *app) *cobra.Command {
	var (
		showSize       bool
		showCustomFs   bool
		installedOnly  bool
	)
	cmd := &cobra.Command{
		Use:     "list",
		Aliases: []string{"ls"},
		Short:   "list distros and their install status",
		RunE: func(cmd *cobra.Command, args []string) error {
			mf, err := loadManifest(cmd.Context(), a, manifest.ModeOffline, false)
			if err != nil {
				return err
			}
			return runList(a, mf, showSize, showCustomFs, installedOnly)
		},
	}
	cmd.Flags().BoolVar(&showSize, "size", false, "include installed size")
	cmd.Flags().BoolVar(&showCustomFs, "custom", false, "also list custom-installed rootfs")
	cmd.Flags().BoolVar(&installedOnly, "installed", false, "only show installed rootfs")
	return cmd
}

func runList(a *app, mf *manifest.Manifest, showSize, showCustomFs, installedOnly bool) error {
	t := tablewriter.NewWriter(a.ui.Out())
	hdr := []string{"suite:variant", "arch supported", "status"}
	if showSize {
		hdr = append(hdr, "size")
	}
	t.SetHeader(hdr)
	t.SetAutoWrapText(false)

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
			supported := "NO"
			for _, arch := range v.SupportedArchs {
				if arch == string(a.arch) {
					supported = "YES"
					break
				}
			}
			installed := ""
			path := filepath.Join(a.paths.InstalledFsDir, v.Name)
			if _, err := os.Stat(path); err == nil {
				installed = "[installed]"
			}
			if installedOnly && installed == "" {
				continue
			}
			row := []string{suiteName + ":" + vName, supported, installed}
			if showSize {
				row = append(row, sizeOrBlank(path))
			}
			t.Append(row)
		}
	}
	t.Render()

	if showCustomFs {
		fmt.Fprintln(a.ui.Out(), "\ncustom rootfs:")
		entries, _ := os.ReadDir(a.paths.InstalledFsDir)
		for _, e := range entries {
			if !e.IsDir() || !strings.HasPrefix(e.Name(), "custom-") {
				continue
			}
			line := "  " + strings.TrimPrefix(e.Name(), "custom-")
			if showSize {
				line += "\t" + sizeOrBlank(filepath.Join(a.paths.InstalledFsDir, e.Name()))
			}
			fmt.Fprintln(a.ui.Out(), line)
		}
	}
	return nil
}

func sizeOrBlank(path string) string {
	if _, err := os.Stat(path); err != nil {
		return ""
	}
	n, err := rootfs.Size(path)
	if err != nil {
		return ""
	}
	return humanBytes(n)
}

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
