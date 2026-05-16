package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/proot"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/rootfs"
)

func newInstallCmd(a *app) *cobra.Command {
	var (
		noVerify   bool
		alwaysRetry bool
		customFile string
		customName string
	)
	cmd := &cobra.Command{
		Use:     "install <suite>:<variant>",
		Aliases: []string{"i"},
		Short:   "install a distro",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			if customFile != "" || customName != "" {
				return runCustomInstall(ctx, a, customFile, customName)
			}
			if len(args) == 0 {
				return fmt.Errorf("install: <suite>:<variant> required")
			}
			ref, err := manifest.ParseRef(args[0])
			if err != nil {
				return err
			}
			return runInstall(ctx, a, ref, noVerify, alwaysRetry)
		},
	}
	cmd.Flags().BoolVar(&noVerify, "no-verify-integrity", false, "skip sha256 verification")
	cmd.Flags().BoolVar(&alwaysRetry, "always-retry", false, "retry download until success or Ctrl-C")
	cmd.Flags().StringVar(&customFile, "file", "", "(custom) path to local tarball")
	cmd.Flags().StringVar(&customName, "name", "", "(custom) name for the installed rootfs")
	return cmd
}

func runInstall(ctx context.Context, a *app, ref manifest.Ref, noVerify, alwaysRetry bool) error {
	a.ui.Title("> INSTALL " + ref.String())
	if alwaysRetry && noVerify {
		return fmt.Errorf("--always-retry is incompatible with --no-verify-integrity")
	}

	mf, err := loadManifest(ctx, a, manifest.ModeOnline, false)
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
	if v.URL == "" {
		return fmt.Errorf("no download URL for %s on %s — variant not supported", ref, a.arch)
	}
	destDir := filepath.Join(a.paths.InstalledFsDir, v.Name)
	if _, err := os.Stat(destDir); err == nil {
		return fmt.Errorf("filesystem %q already installed at %s", v.Name, destDir)
	}

	ext := filepath.Ext(v.URL)
	tarPath := filepath.Join(a.paths.DownloadCache, v.Name+".tar"+ext)

	a.ui.Info(fmt.Sprintf("downloading %s ...", v.Name))
	bar := a.ui.Progress("download " + v.Name)
	if err := rootfs.Download(ctx, v.URL, tarPath, alwaysRetry, bar); err != nil {
		return err
	}

	if !noVerify {
		if err := a.ui.Spinner("verifying sha256", func() error {
			return rootfs.VerifySHA256(tarPath, v.SHASum)
		}); err != nil {
			ok, _ := a.ui.Confirm("integrity check failed. re-download?", true)
			if !ok {
				return err
			}
			_ = os.Remove(tarPath)
			if err := rootfs.Download(ctx, v.URL, tarPath, alwaysRetry, a.ui.Progress("re-download "+v.Name)); err != nil {
				return err
			}
			if err := rootfs.VerifySHA256(tarPath, v.SHASum); err != nil {
				return err
			}
		}
	}

	if err := os.MkdirAll(destDir, 0o755); err != nil {
		return err
	}
	a.ui.Info("extracting to " + destDir)
	if err := proot.ExtractTarball(ctx, tarPath, destDir); err != nil {
		return err
	}

	a.ui.Info("applying proot fixes")
	groups, _ := rootfs.HostAndroidGroups()
	if err := rootfs.ApplyFixes(destDir, rootfs.FixesOptions{
		TermuxPrefix:  a.paths.Prefix,
		AndroidGroups: groups,
	}); err != nil {
		return err
	}
	a.ui.Info("✔ " + v.Name + " installed")
	return nil
}

func runCustomInstall(ctx context.Context, a *app, file, name string) error {
	if file == "" || name == "" {
		return fmt.Errorf("custom install requires both --file and --name")
	}
	if _, err := os.Stat(file); err != nil {
		return fmt.Errorf("tarball %q: %w", file, err)
	}
	dest := filepath.Join(a.paths.InstalledFsDir, "custom-"+name)
	if _, err := os.Stat(dest); err == nil {
		return fmt.Errorf("custom filesystem %q already installed", name)
	}
	if err := os.MkdirAll(dest, 0o755); err != nil {
		return err
	}
	a.ui.Title("> INSTALL custom-" + name)
	a.ui.Info("extracting " + file + " -> " + dest)
	if err := proot.ExtractTarball(ctx, file, dest); err != nil {
		return err
	}
	groups, _ := rootfs.HostAndroidGroups()
	if err := rootfs.ApplyFixes(dest, rootfs.FixesOptions{
		TermuxPrefix:  a.paths.Prefix,
		AndroidGroups: groups,
	}); err != nil {
		return err
	}
	a.ui.Info("✔ custom-" + name + " installed")
	return nil
}
