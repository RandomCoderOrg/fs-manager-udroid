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

// loginFlags groups every CLI flag the `login` subcommand exposes. Pulling
// them into one value keeps newLoginCmd a thin wire-up and lets the run
// path read the whole user intent at a glance.
type loginFlags struct {
	profile        string
	loginUser      string
	binds          []string
	customDistro   string
	nameOverride   string
	isolated       bool
	fixLowPorts    bool
	ashmemMemfd    bool
	noSharedTmp    bool
	noLink2Symlink bool
	noSysVIPC      bool
	noKillOnExit  bool
	noFakeRootID   bool
	noCapLastCap   bool
	reinstallFixes bool
	noPulseServer  bool
	dryRun         bool
	runScript      string
}

func newLoginCmd(a *app) *cobra.Command {
	f := &loginFlags{}
	cmd := &cobra.Command{
		Use:     "login [flags] <suite>:<variant> [-- cmd ...]",
		Aliases: []string{"l"},
		Short:   "log in to an installed rootfs",
		Long:    "Spawn a proot session inside an installed rootfs. Pass '--' to run a one-shot command instead of dropping into a shell.",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runLogin(a, f, cmd, args)
		},
	}
	bindLoginFlags(cmd, f)
	return cmd
}

// bindLoginFlags registers every flag against the shared struct. Lives
// next to loginFlags so adding a flag is a single-place change.
func bindLoginFlags(cmd *cobra.Command, f *loginFlags) {
	pf := cmd.Flags()
	pf.StringVar(&f.profile, "profile", "", "named login profile from config.yaml")
	pf.StringVar(&f.loginUser, "user", "", "login user inside the rootfs (default root)")
	pf.StringArrayVarP(&f.binds, "bind", "b", nil, "extra bind, e.g. /host:/guest")
	pf.StringVar(&f.customDistro, "custom", "", "log into a custom (locally-installed) rootfs by name")
	pf.StringVar(&f.nameOverride, "name", "", "explicit installed name (skip manifest lookup)")
	pf.BoolVar(&f.isolated, "isolated", false, "skip termux/storage mounts and cwd inheritance")
	pf.BoolVar(&f.fixLowPorts, "fix-low-ports", false, "allow binding to ports below 1024")
	pf.BoolVar(&f.ashmemMemfd, "ashmem-memfd", false, "experimental memfd via ashmem")
	pf.BoolVar(&f.noSharedTmp, "no-shared-tmp", false, "use rootfs /tmp instead of termux $PREFIX/tmp")
	pf.BoolVar(&f.noLink2Symlink, "no-link2symlink", false, "disable proot link2symlink")
	pf.BoolVar(&f.noSysVIPC, "no-sysvipc", false, "disable sysvipc emulation")
	pf.BoolVar(&f.noKillOnExit, "no-kill-on-exit", false, "disable kill-on-exit")
	pf.BoolVar(&f.noFakeRootID, "no-fake-root-id", false, "disable --root-id")
	pf.BoolVar(&f.noCapLastCap, "no-cap-last-cap", false, "disable cap_last_cap fix mount")
	pf.BoolVar(&f.reinstallFixes, "reinstall-fixes", false, "re-apply proot-fixes before login")
	pf.BoolVar(&f.noPulseServer, "no-pulseserver", false, "skip starting host pulseaudio")
	pf.BoolVar(&f.dryRun, "dry-run", false, "print the proot argv (one per line) and exit without executing")
	pf.StringVar(&f.runScript, "run-script", "", "host-side script to run inside the rootfs")
}

// runLogin is the full login flow: resolve target rootfs, optionally
// re-apply proot fixes, build proot.Options, then either dry-run-print or
// exec proot. The function reads in three named stages.
func runLogin(a *app, f *loginFlags, cmd *cobra.Command, args []string) error {
	cmdArgs, passthrough := splitAtDash(cmd, args)

	distroName, err := resolveLoginTarget(a, cmdArgs, f.customDistro, f.nameOverride)
	if err != nil {
		return err
	}
	rootFS := filepath.Join(a.paths.InstalledFsDir, distroName)
	if _, err := os.Stat(rootFS); err != nil {
		return fmt.Errorf("rootfs %q not installed", distroName)
	}
	if f.reinstallFixes {
		if err := reapplyFixes(a, rootFS, f.loginUser); err != nil {
			return err
		}
	}

	opts, err := buildLoginOptions(a, f, rootFS, passthrough)
	if err != nil {
		return err
	}

	a.ui.Title("> LOGIN " + distroName)
	if f.dryRun {
		printArgv(a, opts)
		return nil
	}
	return proot.Login(opts)
}

// splitAtDash splits cobra's positional args at `--` so anything after is
// treated as the command to run inside the rootfs.
func splitAtDash(cmd *cobra.Command, args []string) (head, tail []string) {
	idx := cmd.ArgsLenAtDash()
	if idx < 0 {
		return args, nil
	}
	return args[:idx], args[idx:]
}

// reapplyFixes re-runs rootfs.ApplyFixes against an existing install —
// the --reinstall-fixes escape hatch users hit when an upgrade leaves the
// rootfs missing one of the fake /proc files or the profile snippet.
func reapplyFixes(a *app, rootFS, loginUser string) error {
	groups, _ := rootfs.HostAndroidGroups()
	return rootfs.ApplyFixes(rootFS, rootfs.FixesOptions{
		TermuxPrefix:  a.paths.Prefix,
		AndroidGroups: groups,
		LoginUser:     loginUser,
	})
}

// buildLoginOptions composes the proot.Options the user actually wants by
// layering: built-in defaults → config.defaults → named profile →
// CLI flags → per-fs mounts file. Each later layer overrides the earlier.
func buildLoginOptions(a *app, f *loginFlags, rootFS string, passthrough []string) (proot.Options, error) {
	opts := proot.DefaultOptions(rootFS)
	opts.HostPrefix = a.paths.Prefix
	opts.HostHome = a.paths.Home
	opts.AndroidPackage = a.paths.Package

	if f.profile != "" {
		prof, ok := a.cfg.Profile(f.profile)
		if !ok {
			return opts, fmt.Errorf("profile %q not found in config", f.profile)
		}
		applyProfile(&opts, prof)
	} else if a.cfg != nil {
		applyProfile(&opts, a.cfg.Defaults)
	}

	applyLoginFlags(&opts, f)
	opts.Binds = append(opts.Binds, readPerFSMounts(rootFS)...)
	if len(passthrough) > 0 {
		opts.Command = passthrough
	}
	return opts, nil
}

// applyLoginFlags overlays the user's CLI choices on top of the profile-
// merged Options. Boolean "no-FOO" flags flip features off; affirmative
// flags flip them on.
func applyLoginFlags(opts *proot.Options, f *loginFlags) {
	if f.loginUser != "" {
		opts.LoginUser = f.loginUser
	}
	for _, b := range f.binds {
		opts.Binds = append(opts.Binds, parseBindFlag(b))
	}
	if f.isolated {
		opts.Isolated = true
		opts.CWD = "/root"
	}
	if f.fixLowPorts {
		opts.FixLowPorts = true
	}
	if f.ashmemMemfd {
		opts.AshmemMemfd = true
	}
	if f.noSharedTmp {
		opts.SharedTmp = false
	}
	if f.noLink2Symlink {
		opts.Link2Symlink = false
	}
	if f.noSysVIPC {
		opts.SysVIPC = false
	}
	if f.noKillOnExit {
		opts.KillOnExit = false
	}
	if f.noFakeRootID {
		opts.FakeRootID = false
	}
	if f.noCapLastCap {
		opts.CapLastCapFix = false
	}
	if f.noPulseServer {
		opts.PulseServer = false
	}
	if f.runScript != "" {
		opts.RunScript = f.runScript
	}
}

// printArgv dumps the argv one entry per line. Useful for diagnosing what
// proot will see without actually launching it.
func printArgv(a *app, opts proot.Options) {
	argv := append([]string{"proot"}, proot.BuildArgs(opts)...)
	for _, s := range argv {
		fmt.Fprintln(a.ui.Out(), s)
	}
}

// resolveLoginTarget turns the user-supplied identifier into the on-disk
// rootfs directory name. Honors --name (explicit), --custom (custom-fs
// installs), or parses a normal "suite:variant" reference.
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

// parseBindFlag accepts "src" or "src:dst" forms.
func parseBindFlag(s string) proot.Bind {
	parts := strings.SplitN(s, ":", 2)
	if len(parts) == 1 {
		return proot.Bind{Source: parts[0]}
	}
	return proot.Bind{Source: parts[0], Target: parts[1]}
}

// applyProfile merges a config-defined LoginProfile into Options. Bool
// fields on the profile are pointers so we can tell "user explicitly set
// false" from "user said nothing"; nil falls back to whatever was on
// Options already.
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
// blank lines and `#` comments are ignored. Lets users persist extra
// binds per-install without editing the global config.
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
