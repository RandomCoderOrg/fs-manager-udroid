package main

import (
	"fmt"
	"log/slog"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/config"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/logging"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/termux"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/ui"
)

// app gathers the singletons every subcommand needs. Built once in
// PersistentPreRun and reachable via the command context.
type app struct {
	cfg    *config.Config
	paths  termux.Paths
	arch   termux.Arch
	ui     ui.UI
	logger *slog.Logger
	close  func() error
}

func newRootCmd() *cobra.Command {
	var (
		configFile string
		verbose    bool
		logLevel   string
		logFile    string
		logFormat  string
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
			logOpts := logging.Options{
				Level:   pickStr(logLevel, cfg.Log.Level),
				File:    pickStr(logFile, cfg.Log.File),
				Format:  logging.Format(pickStr(logFormat, cfg.Log.Format)),
				Verbose: verbose,
			}
			logger, closer, err := logging.Setup(logOpts)
			if err != nil {
				return err
			}
			state.logger = logger
			state.close = closer

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
			logger.Debug("startup",
				slog.String("arch", string(arch)),
				slog.String("prefix", paths.Prefix),
				slog.String("installed_fs_dir", paths.InstalledFsDir),
			)
			return nil
		},
		PersistentPostRunE: func(cmd *cobra.Command, args []string) error {
			if state.close != nil {
				return state.close()
			}
			return nil
		},
	}
	pf := root.PersistentFlags()
	pf.StringVar(&configFile, "config", "", "path to config.yaml")
	pf.BoolVarP(&verbose, "verbose", "v", false, "mirror log output to stderr")
	pf.StringVar(&logLevel, "log-level", "", "log level: debug|info|warn|error (default info)")
	pf.StringVar(&logFile, "log-file", "", "log file path (default $TMPDIR/udroid.log)")
	pf.StringVar(&logFormat, "log-format", "", "log format: text|json (default text)")

	root.AddCommand(
		newInstallCmd(state),
		newLoginCmd(state),
		newRemoveCmd(state),
		newResetCmd(state),
		newListCmd(state),
		newCacheCmd(state),
		newPullCmd(state),
		newRmiCmd(state),
		newExecCmd(state),
		newInspectCmd(state),
		newInfoCmd(state),
		newSearchCmd(state),
	)
	return root
}

// pickStr returns the first non-empty value — CLI flag wins over config.
func pickStr(flag, fromConfig string) string {
	if flag != "" {
		return flag
	}
	return fromConfig
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
