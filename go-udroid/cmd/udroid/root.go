package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/config"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/termux"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/ui"
)

// app gathers the singletons every subcommand needs. Built once in
// PersistentPreRun and reachable via the command context.
type app struct {
	cfg   *config.Config
	paths termux.Paths
	arch  termux.Arch
	ui    ui.UI
}

func newRootCmd() *cobra.Command {
	var (
		configFile string
		verbose    bool
	)
	state := &app{}
	root := &cobra.Command{
		Use:           "udroid",
		Short:         "proot-based linux rootfs manager for Termux on Android",
		Long:          "udroid manages Linux rootfs tarballs as proot containers on Termux/Android.",
		SilenceUsage:  true,
		SilenceErrors: true,
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := config.Load(configFile)
			if err != nil {
				return err
			}
			paths := applyPathOverrides(termux.DefaultPaths(), cfg.Paths)
			if err := paths.EnsureWritable(); err != nil {
				return fmt.Errorf("prepare directories: %w", err)
			}
			arch := termux.DetectArch()
			if arch == "" {
				return fmt.Errorf("unsupported architecture")
			}
			state.cfg = cfg
			state.paths = paths
			state.arch = arch
			state.ui = ui.NewPlain()
			if verbose {
				fmt.Fprintln(os.Stderr, "arch:", arch, "prefix:", paths.Prefix)
			}
			return nil
		},
	}
	root.PersistentFlags().StringVar(&configFile, "config", "", "path to config.yaml")
	root.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")

	root.AddCommand(
		newInstallCmd(state),
		newLoginCmd(state),
		newRemoveCmd(state),
		newResetCmd(state),
		newListCmd(state),
		newCacheCmd(state),
	)
	return root
}

func applyPathOverrides(p termux.Paths, o config.PathsOverride) termux.Paths {
	if o.Prefix != "" {
		p.Prefix = o.Prefix
	}
	if o.Home != "" {
		p.Home = o.Home
	}
	if o.Root != "" {
		p.Root = o.Root
	}
	if o.InstalledFsDir != "" {
		p.InstalledFsDir = o.InstalledFsDir
	}
	if o.DownloadCache != "" {
		p.DownloadCache = o.DownloadCache
	}
	if o.RuntimeCache != "" {
		p.RuntimeCache = o.RuntimeCache
	}
	return p
}
