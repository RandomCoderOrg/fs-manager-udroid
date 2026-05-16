package main

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
)

// newPullCmd downloads a variant tarball into the local cache without
// installing it. Useful for offline prep — afterwards `install` can run
// without a network round trip.
func newPullCmd(a *app) *cobra.Command {
	var (
		noVerify    bool
		alwaysRetry bool
	)
	cmd := &cobra.Command{
		Use:   "pull <suite>:<variant>",
		Short: "download a variant tarball to the cache (no install)",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				return fmt.Errorf("pull: <suite>:<variant> required")
			}
			ref, err := manifest.ParseRef(args[0])
			if err != nil {
				return err
			}
			ctx := cmd.Context()
			variant, err := resolveInstallVariant(ctx, a, ref)
			if err != nil {
				return err
			}
			a.ui.Title("> PULL " + variant.Name)
			path, err := fetchTarball(ctx, a, variant, noVerify, alwaysRetry)
			if err != nil {
				return err
			}
			a.ui.Info("✔ cached at " + path)
			return nil
		},
	}
	cmd.Flags().BoolVar(&noVerify, "no-verify-integrity", false, "skip sha256 verification")
	cmd.Flags().BoolVar(&alwaysRetry, "always-retry", false, "retry download until success or Ctrl-C")
	return cmd
}
