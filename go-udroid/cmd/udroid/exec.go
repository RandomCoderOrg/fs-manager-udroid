package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/proot"
)

// newExecCmd runs a one-shot command inside an installed rootfs. It is
// the docker-shaped form of `login <name> -- <cmd>` — same machinery, no
// flag surface, fewer keystrokes.
//
// Flag handling: SetInterspersed(false) stops flag parsing as soon as the
// first positional (<name>) is seen, so anything after that — including
// dash-prefixed tokens like `-la` or `--foo` — is forwarded verbatim to
// the inner command. Matches `docker exec` UX; `udroid exec -u user name
// ls -la /tmp` works without a `--` separator.
func newExecCmd(a *app) *cobra.Command {
	var loginUser string
	cmd := &cobra.Command{
		Use:   "exec [flags] <name> <cmd> [args...]",
		Short: "run a command inside an installed rootfs",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) < 2 {
				return fmt.Errorf("exec: <name> and <cmd> are required")
			}
			name, command := args[0], args[1:]
			distroName, err := resolveExecTarget(a, name)
			if err != nil {
				return err
			}
			rootFS := filepath.Join(a.paths.InstalledFsDir, distroName)
			if _, err := os.Stat(rootFS); err != nil {
				return fmt.Errorf("rootfs %q not installed", distroName)
			}
			opts := buildExecOptions(a, rootFS, command, loginUser)
			return proot.Login(opts)
		},
	}
	cmd.Flags().StringVarP(&loginUser, "user", "u", "", "user inside the rootfs (default root)")
	cmd.Flags().SetInterspersed(false)
	return cmd
}

// resolveExecTarget accepts either an installed name (e.g. "ubuntu-jammy")
// or a manifest ref ("ubuntu:jammy"). Refs are looked up against the
// offline manifest so exec stays usable without network.
func resolveExecTarget(a *app, raw string) (string, error) {
	if !strings.Contains(raw, ":") {
		return raw, nil
	}
	ref, err := manifest.ParseRef(raw)
	if err != nil {
		return "", err
	}
	mf, err := loadManifest(context.Background(), a, manifest.ModeOffline, false)
	if err != nil {
		return "", err
	}
	v, err := mf.Variant(ref.Suite, ref.Variant, a.arch)
	if err != nil {
		return "", err
	}
	if v.Name == "" {
		return "", fmt.Errorf("variant %s has no Name in manifest", ref)
	}
	return v.Name, nil
}

// buildExecOptions wires the same defaults+config layering login uses,
// then pre-fills Command so proot runs a one-shot and exits.
func buildExecOptions(a *app, rootFS string, command []string, loginUser string) proot.Options {
	opts := proot.DefaultOptions(rootFS)
	opts.HostPrefix = a.paths.Prefix
	opts.HostHome = a.paths.Home
	opts.AndroidPackage = a.paths.Package
	if a.cfg != nil {
		applyProfile(&opts, a.cfg.Defaults)
	}
	opts.Binds = append(opts.Binds, readPerFSMounts(rootFS)...)
	if loginUser != "" {
		opts.LoginUser = loginUser
	}
	opts.Command = command
	return opts
}
