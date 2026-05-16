package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/rootfs"
)

func newCacheCmd(a *app) *cobra.Command {
	root := &cobra.Command{
		Use:   "cache",
		Short: "manage local caches",
	}
	root.AddCommand(
		&cobra.Command{
			Use:   "update",
			Short: "refresh distro manifest from remote",
			RunE: func(cmd *cobra.Command, args []string) error {
				_, err := loadManifest(cmd.Context(), a, manifest.ModeOnline, true)
				if err != nil {
					return err
				}
				a.ui.Info("manifest updated")
				return nil
			},
		},
		&cobra.Command{
			Use:   "clear",
			Short: "clear downloaded tarball cache",
			RunE: func(cmd *cobra.Command, args []string) error {
				size, _ := rootfs.Size(a.paths.DownloadCache)
				entries, err := os.ReadDir(a.paths.DownloadCache)
				if err != nil {
					return err
				}
				if len(entries) == 0 {
					a.ui.Warn("cache is empty")
					return nil
				}
				ok, err := a.ui.Confirm(fmt.Sprintf("clear %s of cache?", humanBytes(size)), true)
				if err != nil || !ok {
					return err
				}
				for _, e := range entries {
					_ = os.RemoveAll(filepath.Join(a.paths.DownloadCache, e.Name()))
				}
				a.ui.Info("cache cleared")
				return nil
			},
		},
	)
	return root
}
