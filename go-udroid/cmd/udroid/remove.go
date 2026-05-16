package main

import (
	"context"
	"fmt"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/rootfs"
)

func newRemoveCmd(a *app) *cobra.Command {
	var (
		customDistro string
		nameOverride string
	)
	cmd := &cobra.Command{
		Use:     "remove <suite>:<variant>",
		Aliases: []string{"rm", "uninstall"},
		Short:   "remove an installed rootfs",
		RunE: func(cmd *cobra.Command, args []string) error {
			name, err := resolveRemoveTarget(a, args, customDistro, nameOverride)
			if err != nil {
				return err
			}
			path := filepath.Join(a.paths.InstalledFsDir, name)
			a.ui.Title("> REMOVE " + name)
			return a.ui.Spinner("removing "+name, func() error {
				return rootfs.Remove(path)
			})
		},
	}
	cmd.Flags().StringVar(&customDistro, "custom", "", "remove a custom rootfs by name")
	cmd.Flags().StringVar(&nameOverride, "name", "", "explicit installed name to remove")
	return cmd
}

func resolveRemoveTarget(a *app, args []string, custom, nameOverride string) (string, error) {
	if nameOverride != "" {
		return nameOverride, nil
	}
	if custom != "" {
		return "custom-" + custom, nil
	}
	if len(args) == 0 {
		return "", fmt.Errorf("remove: <suite>:<variant> required")
	}
	ref, err := manifest.ParseRef(args[0])
	if err != nil {
		return "", err
	}
	mf, err := loadManifest(context.Background(), a, manifest.ModeOffline, false)
	if err != nil {
		return "", err
	}
	ref, err = resolveRef(a, mf, ref)
	if err != nil {
		return "", err
	}
	v, err := mf.Variant(ref.Suite, ref.Variant, a.arch)
	if err != nil {
		return "", err
	}
	return v.Name, nil
}
