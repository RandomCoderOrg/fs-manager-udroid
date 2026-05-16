package main

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/config"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/proot"
	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/rootfs"
)

func newLoginCmd(a *app) *cobra.Command {
	var (
		profile         string
		loginUser       string
		bindList        []string
		customDistro    string
		nameOverride    string
		isolated        bool
		fixLowPorts     bool
		ashmemMemfd     bool
		noSharedTmp     bool
		noLink2Symlink  bool
		noSysVIPC       bool
		noKillOnExit    bool
		noFakeRootID    bool
		noCapLastCap    bool
		reinstallFixes  bool
		noPulseServer   bool
		runScript       string
	)
	cmd := &cobra.Command{
		Use:     "login [flags] <suite>:<variant> [-- cmd ...]",
		Aliases: []string{"l"},
		Short:   "log in to an installed rootfs",
		Long:    "Spawn a proot session inside an installed rootfs. Pass '--' to run a one-shot command instead of dropping into a shell.",
		RunE: func(cmd *cobra.Command, args []string) error {
			// args after `--` are the command to run inside the rootfs.
			dashIdx := cmd.ArgsLenAtDash()
			var passthrough []string
			if dashIdx >= 0 {
				passthrough = args[dashIdx:]
				args = args[:dashIdx]
			}

			distroName, err := resolveLoginTarget(a, args, customDistro, nameOverride)
			if err != nil {
				return err
			}
			rootFS := filepath.Join(a.paths.InstalledFsDir, distroName)
			if _, err := os.Stat(rootFS); err != nil {
				return fmt.Errorf("rootfs %q not installed", distroName)
			}
			if reinstallFixes {
				groups, _ := rootfs.HostAndroidGroups()
				if err := rootfs.ApplyFixes(rootFS, rootfs.FixesOptions{
					TermuxPrefix:  a.paths.Prefix,
					AndroidGroups: groups,
					LoginUser:     loginUser,
				}); err != nil {
					return err
				}
			}

			opts := proot.DefaultOptions(rootFS)
			opts.HostPrefix = a.paths.Prefix
			opts.HostHome = a.paths.Home
			opts.AndroidPackage = a.paths.Package

			// merge profile from config
			if profile != "" {
				prof, ok := a.cfg.Profile(profile)
				if !ok {
					return fmt.Errorf("profile %q not found in config", profile)
				}
				applyProfile(&opts, prof)
			} else if a.cfg != nil {
				applyProfile(&opts, a.cfg.Defaults)
			}

			// CLI flags override profile
			if loginUser != "" {
				opts.LoginUser = loginUser
			}
			for _, b := range bindList {
				opts.Binds = append(opts.Binds, parseBindFlag(b))
			}
			if isolated {
				opts.Isolated = true
			}
			if fixLowPorts {
				opts.FixLowPorts = true
			}
			if ashmemMemfd {
				opts.AshmemMemfd = true
			}
			if noSharedTmp {
				opts.SharedTmp = false
			}
			if noLink2Symlink {
				opts.Link2Symlink = false
			}
			if noSysVIPC {
				opts.SysVIPC = false
			}
			if noKillOnExit {
				opts.KillOnExit = false
			}
			if noFakeRootID {
				opts.FakeRootID = false
			}
			if noCapLastCap {
				opts.CapLastCapFix = false
			}
			if noPulseServer {
				opts.PulseServer = false
			}
			if runScript != "" {
				opts.RunScript = runScript
			}

			// Pick CWD: explicit isolated => /root, otherwise host PWD.
			if isolated {
				opts.CWD = "/root"
			}

			// per-fs udroid_proot_mounts file
			opts.Binds = append(opts.Binds, readPerFSMounts(rootFS)...)

			if len(passthrough) > 0 {
				opts.Command = passthrough
			}

			a.ui.Title("> LOGIN " + distroName)
			return proot.Login(opts)
		},
	}
	f := cmd.Flags()
	f.StringVar(&profile, "profile", "", "named login profile from config.yaml")
	f.StringVar(&loginUser, "user", "", "login user inside the rootfs (default root)")
	f.StringArrayVarP(&bindList, "bind", "b", nil, "extra bind, e.g. /host:/guest")
	f.StringVar(&customDistro, "custom", "", "log into a custom (locally-installed) rootfs by name")
	f.StringVar(&nameOverride, "name", "", "explicit installed name (skip manifest lookup)")
	f.BoolVar(&isolated, "isolated", false, "skip termux/storage mounts and cwd inheritance")
	f.BoolVar(&fixLowPorts, "fix-low-ports", false, "allow binding to ports below 1024")
	f.BoolVar(&ashmemMemfd, "ashmem-memfd", false, "experimental memfd via ashmem")
	f.BoolVar(&noSharedTmp, "no-shared-tmp", false, "use rootfs /tmp instead of termux $PREFIX/tmp")
	f.BoolVar(&noLink2Symlink, "no-link2symlink", false, "disable proot link2symlink")
	f.BoolVar(&noSysVIPC, "no-sysvipc", false, "disable sysvipc emulation")
	f.BoolVar(&noKillOnExit, "no-kill-on-exit", false, "disable kill-on-exit")
	f.BoolVar(&noFakeRootID, "no-fake-root-id", false, "disable --root-id")
	f.BoolVar(&noCapLastCap, "no-cap-last-cap", false, "disable cap_last_cap fix mount")
	f.BoolVar(&reinstallFixes, "reinstall-fixes", false, "re-apply proot-fixes before login")
	f.BoolVar(&noPulseServer, "no-pulseserver", false, "skip starting host pulseaudio")
	f.StringVar(&runScript, "run-script", "", "host-side script to run inside the rootfs")
	return cmd
}

func resolveLoginTarget(a *app, args []string, custom, nameOverride string) (string, error) {
	if nameOverride != "" {
		return nameOverride, nil
	}
	if custom != "" {
		return "custom-" + custom, nil
	}
	if len(args) == 0 {
		return "", fmt.Errorf("login: <suite>:<variant> required")
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
	if v.Name == "" {
		return "", fmt.Errorf("variant %s has no Name field in manifest", ref)
	}
	return v.Name, nil
}

func parseBindFlag(s string) proot.Bind {
	parts := strings.SplitN(s, ":", 2)
	if len(parts) == 1 {
		return proot.Bind{Source: parts[0]}
	}
	return proot.Bind{Source: parts[0], Target: parts[1]}
}

func applyProfile(o *proot.Options, p config.LoginProfile) {
	if p.User != "" {
		o.LoginUser = p.User
	}
	if p.RunScript != "" {
		o.RunScript = p.RunScript
	}
	for _, b := range p.Binds {
		o.Binds = append(o.Binds, parseBindFlag(b))
	}
	if len(p.Command) > 0 {
		o.Command = p.Command
	}
	o.Isolated = config.BoolDeref(p.Isolated, o.Isolated)
	o.Link2Symlink = config.BoolDeref(p.Link2Symlink, o.Link2Symlink)
	o.SysVIPC = config.BoolDeref(p.SysVIPC, o.SysVIPC)
	o.KillOnExit = config.BoolDeref(p.KillOnExit, o.KillOnExit)
	o.FakeRootID = config.BoolDeref(p.FakeRootID, o.FakeRootID)
	o.CapLastCapFix = config.BoolDeref(p.CapLastCapFix, o.CapLastCapFix)
	o.SharedTmp = config.BoolDeref(p.SharedTmp, o.SharedTmp)
	o.FixLowPorts = config.BoolDeref(p.FixLowPorts, o.FixLowPorts)
	o.AshmemMemfd = config.BoolDeref(p.AshmemMemfd, o.AshmemMemfd)
	o.PulseServer = config.BoolDeref(p.PulseServer, o.PulseServer)
}

// readPerFSMounts parses the optional <rootfs>/udroid_proot_mounts file —
// blank lines and `#` comments are ignored.
func readPerFSMounts(rootFS string) []proot.Bind {
	f, err := os.Open(filepath.Join(rootFS, "udroid_proot_mounts"))
	if err != nil {
		return nil
	}
	defer f.Close()
	var binds []proot.Bind
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		binds = append(binds, parseBindFlag(line))
	}
	return binds
}
