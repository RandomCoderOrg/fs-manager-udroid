package main

import (
	"fmt"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/rootfs"
)

func newResetCmd(a *app) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "reset <suite>:<variant>",
		Aliases: []string{"reinstall"},
		Short:   "remove and reinstall a rootfs",
		Args:    cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			ref, err := manifest.ParseRef(args[0])
			if err != nil {
				return err
			}
			mf, err := loadManifest(ctx, a, manifest.ModeOffline, false)
			if err != nil {
				return err
			}
			ref, err = resolveRef(a, mf, ref)
			if err != nil {
				return err
			}
			v, err := mf.Variant(ref.Suite, ref.Variant, a.arch)
			if err != nil {
				return err
			}
			path := filepath.Join(a.paths.InstalledFsDir, v.Name)
			a.ui.Title(fmt.Sprintf("> RESET %s", ref))
			if err := a.ui.Spinner("removing "+v.Name, func() error {
				return rootfs.Remove(path)
			}); err != nil {
				return err
			}
			return runInstall(ctx, a, ref, false, false)
		},
	}
	return cmd
}
