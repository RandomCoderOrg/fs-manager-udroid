// Package proot is the typed boundary around the proot(1) binary.
//
// Design: Options is a plain struct describing every flag and mount point
// the bash version supports. BuildArgs is a pure function that turns
// Options into an argv slice. No I/O, no exec, no globals. Anything that
// wants to inspect, log, modify, or test the args (the CLI today, a TUI
// tomorrow) calls BuildArgs and works with the slice.
//
// Side-effecting wrappers (Extract, Login) live in sibling files.
package proot

import (
	"fmt"
	"os"
)

// Bind expresses a single proot bind. Source is required; Target may be
// empty to bind onto the same path inside the rootfs.
type Bind struct {
	Source string
	Target string
}

// String renders the proot "--bind=src:dst" or "--bind=src" form.
func (b Bind) String() string {
	if b.Target == "" {
		return "--bind=" + b.Source
	}
	return "--bind=" + b.Source + ":" + b.Target
}

// Options is the full surface of a proot invocation for login. Every flag
// in the bash `login()` function has an equivalent field here. Field
// defaults are chosen so the zero value works for a typical login.
type Options struct {
	// RootFS is the directory passed to --rootfs. Required.
	RootFS string

	// KernelRelease is the value for --kernel-release. Defaults to the
	// bash version's "5.4.2-proot-facked" when empty.
	KernelRelease string

	// CWD is passed as --cwd. When empty, no --cwd is set. Set explicitly
	// to "/root" for an isolated session or to the host PWD to inherit it.
	CWD string

	// LoginUser is passed to `su -l` inside the container. Defaults to "root".
	LoginUser string

	// Command, when non-empty, is run via `su -l <user> -c <cmd>` rather
	// than dropping the user into an interactive shell.
	Command []string

	// RunScript is a host-side script that will be copied into the rootfs
	// and executed by su. Empty means no run-script.
	RunScript string

	// Binds is the user-supplied bind list (`-b ...`). Core mounts are
	// added by BuildArgs based on the toggle fields below.
	Binds []Bind

	// FeatureToggles. Names match the bash --no-* flags so callers don't
	// have to mentally negate. A true value means the feature is enabled;
	// the bash --no-foo flag sets the Go field to false.
	Link2Symlink   bool
	SysVIPC        bool
	KillOnExit     bool
	FakeRootID     bool
	CapLastCapFix  bool

	// Standard mount profiles.
	CoreMounts        bool // /dev /proc /sys
	TermuxMounts      bool // termux usr/home, storage, apex, system, vendor
	FakeProcFiles     bool // /proc/.stat etc fall-backs
	SharedTmp         bool // mount termux $PREFIX/tmp to /tmp
	FixLowPorts       bool // -p flag
	AshmemMemfd       bool // --ashmem-memfd
	Isolated          bool // skips termux/storage mounts
	FollowSymlinks    bool // -L flag
	PulseServer       bool // start pulseaudio with TCP module before exec

	// HostPrefix is the termux $PREFIX equivalent used to build mounts.
	HostPrefix string
	// HostHome is the termux home dir.
	HostHome string
	// AndroidPackage is "com.termux" or the Termux fork's id.
	AndroidPackage string
	// HostPWD is interpolated when CWD is empty and Isolated is false.
	HostPWD string
}

// DefaultOptions returns an Options seeded with the bash version's
// "everything on" defaults. Callers selectively flip flags off — this
// matches the user's mental model where `--no-X` removes a default.
func DefaultOptions(rootfs string) Options {
	pwd, _ := os.Getwd()
	return Options{
		RootFS:         rootfs,
		KernelRelease:  "5.4.2-proot-facked",
		LoginUser:      "root",
		Link2Symlink:   true,
		SysVIPC:        true,
		KillOnExit:     true,
		FakeRootID:     true,
		CapLastCapFix:  true,
		CoreMounts:     true,
		TermuxMounts:   true,
		FakeProcFiles:  true,
		SharedTmp:      true,
		FollowSymlinks: true,
		PulseServer:    true,
		HostPWD:        pwd,
	}
}

// Validate returns a descriptive error if Options is incomplete.
func (o Options) Validate() error {
	if o.RootFS == "" {
		return fmt.Errorf("proot.Options: RootFS is required")
	}
	if st, err := os.Stat(o.RootFS); err != nil || !st.IsDir() {
		return fmt.Errorf("proot.Options: rootfs %q is not a directory", o.RootFS)
	}
	return nil
}
