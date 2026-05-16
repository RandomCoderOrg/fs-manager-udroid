package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
)

// newRmiCmd removes one or more cached variant tarballs. Targets the
// download cache only — installed rootfs are unaffected (use `remove`).
func newRmiCmd(a *app) *cobra.Command {
	return &cobra.Command{
		Use:   "rmi <suite>:<variant> [<suite>:<variant>...]",
		Short: "remove cached tarball(s) from the download cache",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				return fmt.Errorf("rmi: at least one <suite>:<variant> required")
			}
			mf, err := loadManifest(cmd.Context(), a, manifest.ModeOffline, false)
			if err != nil {
				return err
			}
			for _, raw := range args {
				if err := removeCachedTarball(a, mf, raw); err != nil {
					a.ui.Warn(fmt.Sprintf("%s: %v", raw, err))
				}
			}
			return nil
		},
	}
}

// removeCachedTarball resolves one suite:variant ref, finds the matching
// cache file(s), and unlinks them. Globs against <variant.Name>.tar* so we
// catch every supported compression ext without depending on variant.URL
// (which is empty on the host's arch when the variant isn't supported).
func removeCachedTarball(a *app, mf *manifest.Manifest, raw string) error {
	ref, err := manifest.ParseRef(raw)
	if err != nil {
		return err
	}
	if ref.Suite == "" || ref.Variant == "" {
		return fmt.Errorf("need explicit suite:variant")
	}
	v, err := mf.Variant(ref.Suite, ref.Variant, a.arch)
	if err != nil {
		return err
	}
	matches, _ := filepath.Glob(filepath.Join(a.paths.DownloadCache, v.Name+".tar*"))
	if len(matches) == 0 {
		return fmt.Errorf("no cached tarball")
	}
	for _, m := range matches {
		if err := os.Remove(m); err != nil {
			return err
		}
		a.ui.Info("removed " + filepath.Base(m))
	}
	return nil
}
